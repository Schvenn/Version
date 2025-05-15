# Version
Powershell module to create intelligent backups of functions and aliases during development

This script allows you to backup a command that you are currently modifying to the user's "PowerShell\Archive\Development History" directory.

This differs from scripts and modules in that it only keeps copies of the command logic.

If the user runs version against an alias, the script will backup the logic of the parent command and append the logic required to create the alias to the end of it.

Also, if the command, or parent command in the case of an alias, is simply a reference to an external script, this function will also append the logic of that script to the bottom of the file, separated by a hyphenated line.

There is also a -quiet option to reduce the screen output.

By default, the script is set to prune older copies after 10 revisions, but this can be modified and you can use the -purge or ## options, as required.

The prune by ## feature uses logical assumptions to determine development dates, by keeping the oldest and latest versions of a command for any single date, before it resorts to pruning the oldest files, thereby increasing the likelihood that major revisions are kept over minor ones.

It also uses intelligent archiving to ensure that new backups are only created if the SHA256 of the new file will be different than any older one, thereby eliminating duplicates and wasted disk space. This does of course, mean that it's possible to skip a version if the latest copy was an abandoned approach and the user eventually reverted to an older one.

The -all switch will enumerate a list of all functions and aliases available as a result of the current user's profile and run the command against all of them.
