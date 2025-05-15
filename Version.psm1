function version ($cmd, [switch]$purge, $maxhistory = 10, [switch]$quiet, [switch]$help, [switch]$list) {# Keep a historical list of functions and aliases during development, but only if they change.
""

if ($help) {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
Write-Host -ForegroundColor Yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -ForegroundColor Yellow; Write-Host -ForegroundColor Yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -ForegroundColor Yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -ForegroundColor Cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -ForegroundColor Cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

if (-not $cmd) {Write-Host -f cyan "`nUsage: version `"command`" -purge -prune ## -help"; Write-Host -f white "Where -purge deletes all histories of a command and -prune ensures that the script keeps a maximum ## of copies (10 is the default).`n"; return}

$backupdirectory = Join-Path (Split-Path $profile) "Archive\Development History\$cmd"; $validatecommand = Get-Command $cmd -ErrorAction SilentlyContinue
if ($purge) {Remove-Item $backupdirectory -Recurse -Force -ErrorAction SilentlyContinue; Write-Host -f red "`nDirectory for $cmd has been purged.`n"; return}
if (-not $validatecommand -or $validatecommand.CommandType -notin 'Function','ExternalScript','Alias') {Write-Host -f red "`nInvalid command: $cmd`n"; return}
$cmddetails = (Get-Command $cmd).definition; $cmdsourceinfo = (Get-Command $cmd).source; $callcmd = (Get-Command $cmd).displayname; $cmd = $cmd.tolower()

# Append the alias command to the end of the parent function, if the command referenced is an alias.
if ($validatecommand.CommandType -in 'Alias') {$parentfunction = (Get-Command $cmddetails).definition; $truecommand = "$parentfunction`nsal -Name $cmd -Value $cmddetails"; $cmddetails = $truecommand}

# Add the script content to the end, if the command is simply a placeholder for an external script.
if ($cmddetails -match '(?i)\$script\w*\s*=\s*["'']?([^"]+\.ps1)[";&.\s]+\$script') {$ps1file = $matches[1]
if ($ps1file -match '(\$\w+)') {$varName = $matches[1].Substring(1); $varValue = (Get-Variable -Name $varName).Value; $ps1file = $ps1file -replace [regex]::Escape($matches[1]), $varValue}
if (Test-Path $ps1file) {$ps1Content = Get-Content $ps1file -Raw; $cmddetails += "`n" + ("-" * 100) + "`n" + $ps1Content}}

# Output to screen.
if (-not $quiet) {Write-Host -f cyan "Command: " -NoNewLine; Write-Host -f yellow $cmd; Write-Host -f cyan "Source: " -NoNewLine; Write-Host -f yellow $cmdsourceinfo; Write-Host -f yellow ("-"*100); Write-Host -f white $cmddetails"`n"; Write-Host -f yellow ("-"*100)}

# Write the file.
$filename = "$cmd - $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').backup"; $backup = Join-Path $backupdirectory $filename; New-Item -ItemType Directory $backupdirectory -Force | Out-Null; $cmddetails | Out-File $backup -Force 

# Keep only unique hashes.
$sha256 = [System.Security.Cryptography.SHA256]::Create(); $files = Get-ChildItem -Path $backupdirectory -File; $hashToFiles = @{}
foreach ($file in $files) {try {$fileBytes = [System.IO.File]::ReadAllBytes($file.FullName); $fileHashBytes = $sha256.ComputeHash($fileBytes); $fileHash = [System.BitConverter]::ToString($fileHashBytes) -replace '-', ''
if (-not $hashToFiles.ContainsKey($fileHash)) {$hashToFiles[$fileHash] = @()}; $hashToFiles[$fileHash] += $file}
catch {Write-Warning "Failed to hash file $($file.FullName): $_"}}
foreach ($group in $hashToFiles.Values) {$sortedGroup = $group | Sort-Object LastWriteTime
if ($sortedGroup.Count -gt 1) {$sortedGroup[1..($sortedGroup.Count - 1)] | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Display results of determination.
if (Test-Path $backup) {if (-not $quiet) {Write-Host -ForegroundColor Green "File $backup saved."; Write-Host -ForegroundColor Yellow ("-" * 100)}
elseif ($quiet) {Write-Host "$backup saved."}}
else {Write-Host -f red "Backup identical to an existing file, skipping creation.`n"}

# Group files by date and keep only the oldest and newest per day.
$files = Get-ChildItem -Path $backupdirectory -File | Sort-Object Name; $filesByDate = $files | Group-Object {if ($_ -match '(\d{4}-\d{2}-\d{2})_\d{2}-\d{2}-\d{2}') {$matches[1]}
else {'unknown'}}
foreach ($group in $filesByDate) {$sortedGroup = $group.Group | Sort-Object Name
if ($sortedGroup.Count -gt 2) {$sortedGroup[1..($sortedGroup.Count - 2)] | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Enforce maxhistory count globally by deleting oldest files beyond the set limit.
$files = Get-ChildItem -Path $backupdirectory -File | Sort-Object LastWriteTime; $excess = $files.Count - $maxhistory
if ($excess -gt 0) {$files | Select-Object -First $excess | ForEach-Object {Remove-Item $_.FullName -Force}}

# Enumeration
if ($list) {Write-Host -f yellow "Available versions:`n"
$headers = @("Size", "SHA256", "Last Modified"); $padding = 5; $files = Get-ChildItem -Path $backupdirectory -File
$rows = foreach ($file in $files) {$hash = Get-FileHash -Path $file.FullName -Algorithm SHA256; [PSCustomObject]@{Size = "$($file.Length) bytes"; SHA256 = $hash.Hash; 'Last Modified' = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")}}
$widths = @{}; foreach ($header in $headers) {$maxLen = ($rows | ForEach-Object {($_.PSObject.Properties[$header].Value.ToString()).Length;}) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum; $widths[$header] = [Math]::Max($maxLen, $header.Length)}
$spacer = ' ' * $padding
$headerLine = ($headers | ForEach-Object {$_.PadRight($widths[$_]);}) -join $spacer; Write-Host $headerLine -ForegroundColor Cyan
foreach ($row in $rows | Sort-Object 'Last Modified' -Descending) {$line = foreach ($header in $headers) {$value = $row.PSObject.Properties[$header].Value.ToString(); if ($header -eq "Size") {$value.PadLeft($widths[$header])} else {$value.PadRight($widths[$header])}}; Write-Host ($line -join $spacer) -ForegroundColor White}}; ""; Write-Host -f yellow ("-"*100); ""; return}

Export-ModuleMember -Function version

<#
## version

This script allows you to backup a command that you are currently modifying to the user's "PowerShell\Archive\Development History" directory.

This differs from scripts and modules in that it only keeps copies of the command logic.

If the user runs version against an alias, the script will backup the logic of the parent command and append the logic required to create the alias to the end of it.

Also, if the command, or parent command in the case of an alias, is simply a reference to an external script, this function will also append the logic of that script to the bottom of the file, separated by a hyphenated line.

There is also a -quiet option to reduce the screen output.

By default, the script is set to prune older copies after 10 revisions, but this can be modified and you can use the -purge or ## options on demand.

The prune by ## feature uses logical assumptions to determine development dates, by keeping the oldest and latest versions of a command for any single date, before it resorts to pruning the oldest files, thereby increasing the likelihood that major revisions are kept over minor ones.

It also uses intelligent archiving to ensure that new backups are only created if the SHA256 of the new file will be different than any older one, thereby eliminating duplicates and wasted disk space. This does of course, mean that it's possible to skip a version if the latest copy was an abandoned approach and the user eventually reverted to an older one.

The list function will enumerate a list of all versions of the command that are currently archived.
##>
