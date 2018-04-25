# fixsvn
Small script that tries to fix a SVN repository where files have been moved manually without SVN tools, and thus are shown as unknown (!) in `svn status`. It's not the end of the world and changes can be committed, but in this case all history of those files will be lost, since they will be new files for subversion, even if they already existed (in a different path) in previous revisions.

This script tries to detect each and every change in file path made outside SVN, undo it, and redo it properly with svn tools (`snv mv` for moving, `svn add` for directories). It works with two working copies of the same svn repository:

* "Dirty" working copy (REPONOU variable). Here's where all file moving was made, and where `svn status` shows unknown files
* Clean working copy (REPOSVN). A `svn checkout` of the last committed revision, prior to any irregular file movement.

What the script tries to achieve is getting the original path in SVN repo for each unknown file in the dirty working copy, so it can then redo the file movement, this time with a proper `svn mv`. The script is somewhat smart looking for file movements, and if it founds more than one candidate for a moved file (because of duplicates), it will choose the one with most similar path name.

As a disclaimer, I can't provide any warranty at all. I wrote this script for my personal use (I'm new to subversion and I wrecked up a project) and thought it might be useful to somebody else since I haven't found any tool that automates this task. But if the tool ends up not working for your case, destroying your files or eating your breakfast, I won't be responsible :-). Please don't trust a script a guy wrote on the Internet, and at least review if what the script does makes any sense to you.
