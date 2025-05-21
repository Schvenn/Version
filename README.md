# Version
Usage: version "command" -purge #(maxhistory) -(dev/stable) -quiet -all -help

This script allows you to backup a command that you are currently modifying to your "PowerShell\Archive\Development History" directory.

This differs from backing up scripts and modules in that it only keeps copies of the command logic, making it much easier to keep track of the iterative development of individual components.

        • If executed against an alias, the script will backup the logic of the parent command and append the logic required to create the alias to the end of it.
        • If the command is simply a reference to an external script, the function will attempt to obtain the logic of that script and also append it to the end.

The -purge feature will delete all version copies of the command in question and the directory in which they reside.

The # (maxhistory) feature sets the maximum number of versions to keep of the command in question. The default is 10.

        • This feature uses logical assumptions to determine development dates, by keeping the first and last versions of a command for any single date, before it resorts to pruning the oldest files, thereby increasing the likelihood that the major and most relevant revisions are kept over minor and historically outdated versions.

The -dev feature disables all pruning by date or volume until the devflag is turned off. This overrides the # (maxhistory) feature.

The -stable flag disables the -dev mode, indicating that normal pruning and history retention can resume.

The -quiet option will reduce the screen output; reduce, not completely eliminate.

The -all switch will run the command against all of the commands available as a result of the current user's profile.

        • -force completes a backup, even if the "ranflag" is set, which prevents the backup from running more than once a month.
        • At the end of the process, the script will determine if any commands no longer exist and archive them in a ZIP file for future reference.

The -compare option will compare different version backups of the command specified with one another, in order to demonstrate differences.

        • The comparison uses a character match percentage to provide output. Lines that exist 100% identically in the other file will be white, 80-100% matches will be cyan, the rest will be yellow.
        • -differences will display only those lines that are different from one another.
                • -savedifferences will save the differences output to a file: command - yyyy-mm-dd_hh-mm-ss & yyyy-mm-dd_hh-mm-ss.differences.

The -list option will provide a table of all version directories available, the number of files contained therein and a summary.

        • Aliases and script backups will be marked, accordingly.
        • Functions with their development flag set will also be clearly identified.
 
This module also uses intelligent archiving to ensure that new backups are only created if the SHA256 of the new file will be different than any older one, thereby eliminating duplicates and wasted disk space. This does of course, mean that it's possible to skip a version if the latest copy was an abandoned approach and the user eventually reverted to an older version. So, keep that in mind.
