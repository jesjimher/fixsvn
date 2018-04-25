#!/bin/bash

# Fixes a subversion repository where files have been moved manually (without using "svn mv" and such)
# It needs 2 inputs:

# REPSVN: "Clean" SVN working copy, without 
# REPNOU: "Dirty" working copy, where files have been moved carelessly

# The script will analyze each file in REPNOU, try to find its original path in REPSVN, and perform a svn mv in REPSVN
# Searches are done by MD5 hash. If there's more than one candidate for a file (because duplicates), the most similar path will be chosen
#
# At the end, REPSVN should be identical as REPNOU, but with all files properly moved with svn tools, so history should be preserved

REPSVN="/path/to/pristine/copy/of/svn/repo/contents/just/before/wrecking/it"
REPNOU="/path/to/working/copy/where/all/bad/things/happened"


# Generate all MD5 hashes from REPSVN to a temp file
FTEMP=$(mktemp)
echo "* Analyzing reference SVN repository..."
#fichs=($(find $REPSVN -type f))
declare -A reposvn
while read f; do
	hash=$(md5sum "$f" | cut -d" " -f1)
	reposvn[$hash]="$f"
	echo $hash $f
done < <(find $REPSVN -type f) > $FTEMP
echo "  $(wc -l $FTEMP) files found and analyzed"
echo

# For each file in the "dirty" working copy, look for its original
echo "* Analyzing working copy, looking for correspondences..."
fichs=($(find $REPNOU -type f))
pushd $REPSVN
for f in ${fichs[@]}; do
	ndir=$(dirname "$f")
	fname=$(basename "$f")
	hash=$(md5sum "$f" | cut -d" " -f1)
	byhash="$(grep "^$hash " $FTEMP)"
	nresults="$(grep -c "^$hash " $FTEMP)"
	if [ "$byhash" != "" ]; then
		if [ $nresults -gt 1 ]; then
			echo "  Multiple correspondences found, choosing most similar path"
			orig=$(realpath --relative-to=$REPNOU $f)
			echo "    $orig"
			# Get list of candidates, and calculate levenshtein distance to $f
			candidates=($(grep "^$hash " $FTEMP | cut -d" " -f2))
			results=()
			for c in ${candidates[@]}; do
				# Assumes perl installed with Text::LevenshteinXS module
				results+=("$(perl -MList::Util=max -MText::LevenshteinXS -le '($x, $y) = @ARGV;print distance($x, $y)' -- "$f" "$c") $c")
			done
			printf "%s\n" "${results[@]}" | sed 's/^/    /g'
			# Choose the candidate with lower distance
			echo -n "    Using: "
			corresp=$(printf "%s\n" "${results[@]}" | sort -n | head -n1 | cut -d' ' -f2)
			corresp=$(realpath --relative-to=$REPSVN $corresp)
			echo "$corresp"
		else
			echo "  Single correspondence found:"
			orig=$(realpath --relative-to=$REPNOU $f)
			echo "    REPNOU/$orig"
			corresp=$(echo $byhash | cut -d' ' -f2)
			corresp=$(realpath --relative-to=$REPSVN $corresp)
			echo "    REPSVN/$corresp"
		fi
		# Here we should already have a proper correspondence
		# Check if path exists in SVN, create if it doesn't
		ndir=$(dirname $REPSVN/$orig)
		if ! test -d $ndir; then
			echo "  Directory $(dirname $orig) doesn't exist in REPSVN, creating"
			mkdir -p $ndir && svn add --parents $(dirname $orig)
		fi
		# Move file with svn mv
		if [ "$corresp" != "$orig" ]; then
			svn mv $corresp $orig
		else
			echo "  Nothing done, file already in place"
		fi
	else
		# File doesn't exist, copy and add
		echo "  No correspondence found for $f ($hash)"
		# Check if path exists in SVN, create if it doesn't
		ndir=$(dirname $f)
		ndir=$(realpath --relative-to=$REPNOU $ndir)
		if ! test -d $ndir; then
			echo "  Directory $ndir doesn't exist in REPSVN, creating"
			mkdir -p $ndir && svn add --parents $ndir
		fi
		dest=$(realpath --relative-to=$REPNOU $f)
		cp "$f" "$dest" && svn add "$dest"
	fi
done

popd

echo
echo "Finished, check $REPNOU status and commit changes it they're ok"
