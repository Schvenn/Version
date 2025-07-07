function version ($cmd, [int]$maxhistory = 5, [switch]$dev, [switch]$stable, [switch]$quiet, [switch]$hidden, [switch]$all, [switch]$force, [switch]$purge, [switch]$compare, [switch]$savedifferences, [switch]$differences, [switch]$list, [switch]$help) {# Keep a historical list of functions and aliases during development, but only if they change.

function readbackupfilecontent ([string]$path) {if ($path -like '*.gz') {$fs = [System.IO.File]::OpenRead($path); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gz); $content = $reader.ReadToEnd(); $reader.Close(); $gz.Close(); $fs.Close(); return $content -split "`r?`n"}
else {return Get-Content $path}}

# Ensure -dev is being called correctly for only single commands.
$backupdirectory = Join-Path (Split-Path $profile) "Archive\Development History\$cmd"; $devflag = Join-Path $backupdirectory ".development_flag"
if ($dev -and (-not $cmd)) {Write-Host -f red "`nYou must specify a single command with -cmd when using -dev.`n"; return}
if ($dev -and $stable) {Write-Host -f red "`nA command can only be under development or a stable release, not both.`n"; return}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field -or $field.Length -eq 0) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()

if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength) {if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}}

foreach ($line in $field -split "`n") {if ($line.Trim().Length -eq 0) {$wrapped += ''; continue}
$remaining = $line.Trim()
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1

foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakChar = $char; $breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1; $breakChar = ''}
$chunk = $segment.Substring(0, $breakIndex + 1).TrimEnd(); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1).TrimStart()}

if ($remaining.Length -gt 0) {$wrapped += $remaining}}
return ($wrapped -join "`n")}

if ($help) {# Inline help.
function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {wordwrap $lines[1] 100| Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

if ($cmd -and $hidden) {# Backup hidden function.

function gethiddenfunction ($module, $function) {$path = (Get-Module $module).Path; $lines = Get-Content $path; $start = ($lines | Select-String -Pattern "function\s+$function\b").LineNumber - 1; $braceCount = 0; $end = $start
if ((Get-Content $path -raw) -notmatch "(?i)function\s+$function") {Write-Host -f red "Function not found. Aborting.`n"; return $false}
do {$line = $lines[$end]; $braceCount += ($line -split '{').Count - 1; $braceCount -= ($line -split '}').Count - 1; $end++}
while ($braceCount -gt 0 -and $end -lt $lines.Count)
return ($lines[$start..($end - 1)] -join "`n")}

# Error-checking.
Write-Host -f yellow "`nWhat is the name of the parent module for function " -n; Write-Host -f white "$cmd" -n; Write-Host -f yellow "? " -n; $module = Read-Host; ""
if (-not $module) {Write-Host -f red "You must have the parent module name to continue. Aborting.`n"; return}
if (-not (Get-Command $module -ea SilentlyContinue)) {Write-Host -f red "Invalid module. Aborting.`n"; return}
$cmddetails = gethiddenfunction $module $cmd
if (-not $cmddetails) {return}

# Write the file.
$backupdirectory = Join-Path (Split-Path $profile) "Archive\Development History\.hidden\$cmd"; $filename = "$cmd - $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').backup"; $backup = Join-Path $backupdirectory $filename; New-Item -ItemType Directory $backupdirectory -Force | Out-Null; $cmddetails | Out-File $backup -Force 

# If file is larger than 1KB, compress it and delete the original
if ((Get-Item $backup).Length -gt 1KB) {$gzipFile = "$backup.gz"; $fs = [System.IO.File]::OpenRead($backup); $gzfs = [System.IO.File]::Create($gzipFile); $gz = New-Object System.IO.Compression.GZipStream($gzfs, [System.IO.Compression.CompressionMode]::Compress); $fs.CopyTo($gz); $gz.Close(); $fs.Close(); $gzfs.Close(); Remove-Item $backup -Force; $backup = $gzipFile}

# Keep only unique hashes. This will also delete the current file that was just created, if the hash for it is identical to a previous version.
$sha256 = [System.Security.Cryptography.SHA256]::Create(); $files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Name -match '\.backup(\.gz)?$'}; $hashToFiles = @{}
foreach ($file in $files) {try {if ($file.Extension -eq '.gz') {$fs = [System.IO.File]::OpenRead($file.FullName); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $ms = New-Object System.IO.MemoryStream; $gz.CopyTo($ms); $gz.Close(); $fs.Close(); $fileBytes = $ms.ToArray(); $ms.Close()}
else {$fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)}
$fileHashBytes = $sha256.ComputeHash($fileBytes); $fileHash = [System.BitConverter]::ToString($fileHashBytes) -replace '-', ''
if (-not $hashToFiles.ContainsKey($fileHash)) {$hashToFiles[$fileHash] = @()}; $hashToFiles[$fileHash] += $file}
catch {Write-Warning "Failed to hash file $($file.FullName): $_"}}
foreach ($group in $hashToFiles.Values) {$sortedGroup = $group | Sort-Object LastWriteTime
if ($sortedGroup.Count -gt 1) {$sortedGroup[1..($sortedGroup.Count - 1)] | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Display results of the hash comparison determination.
Write-Host -f yellow ("-" * 100); Write-Host -f white $cmddetails; Write-Host -f yellow ("-" * 100); wordwrap "`nPlease be aware that this is a best effort attempt. Hidden function backups do not follow the same rules as public functions. They are not included in -all backups, they are not archived when they are retired and an unlimited number of archival copies can be created.`n" 100 | Write-Host -f yellow
if (Test-Path $backup) {Write-Host -f white "File $backup saved."}
if (-not (Test-Path $backup)) {Write-Host -f white "$cmd`: " -n; wordwrap "The current backup would be identical to an existing file, therefore the latest version is not being retained." 80 | Write-Host -f red}

# Enumerate.
Write-Host -f yellow "`nAvailable versions:`n"
$headers = @("Size", "SHA256", "Last Modified"); $padding = 5; $files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Extension -in '.backup', '.gz' -or $_.Name -eq '.development_flag'}; $rows = foreach ($file in $files) {if ($file.Name -eq '.development_flag') {[PSCustomObject]@{Size = "0 bytes"; SHA256 = ".development_flag was set"; 'Last Modified' = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")}}
else {if ($file.Extension -eq '.gz') {$fs = [System.IO.File]::OpenRead($file.FullName); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $ms = New-Object System.IO.MemoryStream; $gz.CopyTo($ms); $gz.Close(); $fs.Close(); $rawBytes = $ms.ToArray(); $ms.Close(); $sha256 = [System.Security.Cryptography.SHA256]::Create(); $hashBytes = $sha256.ComputeHash($rawBytes); $hashValue = [BitConverter]::ToString($hashBytes) -replace '-', ''}
else {$hashValue = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash}
[PSCustomObject]@{Size = "$($file.Length) bytes"; SHA256 = $hashValue; 'Last Modified' = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")}}}
$widths = @{}; foreach ($header in $headers) {$maxLen = ($rows | ForEach-Object {($_.PSObject.Properties[$header].Value.ToString()).Length;}) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum; $widths[$header] = [Math]::Max($maxLen, $header.Length)}
$spacer = ' ' * $padding
$headerLine = ($headers | ForEach-Object {$_.PadRight($widths[$_]);}) -join $spacer; Write-Host $headerLine -f cyan
foreach ($row in $rows | Sort-Object 'Last Modified' -Descending) {$line = foreach ($header in $headers) {$value = $row.PSObject.Properties[$header].Value.ToString(); if ($header -eq "Size") {$value.PadLeft($widths[$header])} else {$value.PadRight($widths[$header])}}; Write-Host ($line -join $spacer) -f white}; ""; Write-Host -f yellow ("-"*100); ""; return}

# Call -list.
if ($list) {$root = "$powershell\archive\development history"

$totalDirs = 0
$results = Get-ChildItem -Path $root -Directory | ForEach-Object {$dir = $_.FullName; $backupFiles = Get-ChildItem -Path $dir -File | Where-Object {$_.Name -match '\.backup(\.gz)?$'}; $count = $backupFiles.Count
$oldest = if ($count) {($backupFiles | Sort-Object LastWriteTime)[0].LastWriteTime.ToString("yyyy-MM-dd")} else {"-"}
$newest = if ($count) {($backupFiles | Sort-Object LastWriteTime -Descending)[0].LastWriteTime.ToString("yyyy-MM-dd")} else {"-"}
$devflag = if (Test-Path "$dir\.development_flag") {"Yes"}

# Alias detection.
$hasAlias = $false
foreach ($file in $backupFiles) {if (Select-String -Path $file.FullName -Pattern '^(sal|set-alias)\s') {$hasAlias = $true; break}}

# Script marker detection.
$hasScriptHeader = $false
foreach ($file in Get-ChildItem -Path $dir -File) {$lines = Get-Content $file.FullName
for ($i = 0; $i -lt $lines.Count; $i++) {if ($lines[$i] -match 'script.*ps1.*script') {for ($j = $i + 1; $j -lt $lines.Count; $j++) {if ($lines[$j] -match '^[-]{100,}$') {$hasScriptHeader = $true; break}}}
if ($hasScriptHeader) {break}}
if ($hasScriptHeader) {break}}

# Set type string.
if ($hasScriptHeader) {$type = "script"} elseif ($hasAlias) {$type = "alias"} else {$type = ""}

# Output.
if ($count -gt 0) {$totalDirs++}
[PSCustomObject]@{Directory = $_.Name; Files = $count; Oldest = $oldest; Newest = $newest; Type = $type; Development = $devflag}}
Write-Host ("{0,-30} {1,6} {2,8} {3,12} {4,8} {5,17}" -f "`nDirectory", "Files", "Oldest", "Newest", "Type", "Development") -f white; Write-Host -f cyan ("-" * 100)
foreach ($row in $results) {switch ($row.Type) {"script" {$colour = "darkcyan"}; "alias" {$colour = "cyan"}; default {$colour = "white"}}
if ($row.Development -eq 'Yes') {$colour = 'yellow'}
Write-Host ("{0,-30} {1,5} {2,12} {3,12} {4,-10} {5,-12}" -f $row.Directory, $row.Files, $row.Oldest, $row.Newest, $row.Type, $row.Development) -f $colour}

# Summary.
$totalFiles = ($results | Measure-Object -Property Files -Sum).Sum
$allDates = $results | Where-Object {$_.Oldest -ne "-"} | ForEach-Object {[datetime]::ParseExact($_.Oldest, 'yyyy-MM-dd', $null); [datetime]::ParseExact($_.Newest, 'yyyy-MM-dd', $null)}
$oldestDate = if ($allDates) {($allDates | Sort-Object)[0].ToString('yyyy-MM-dd')}
$newestDate = if ($allDates) {($allDates | Sort-Object)[-1].ToString('yyyy-MM-dd')}
$typeCount = ($results | Where-Object {$_.Type -in @('alias','script')}).Count
$devCount = ($results | Where-Object {$_.Development -eq 'Yes'}).Count
$typeSummary = "Totals: $totalDirs"

# Total row.
$labelCol  = "{0,-30}" -f $typeSummary; $filesCol = "{0,5}" -f $totalFiles; $oldCol = "{0,12}" -f $oldestDate; $newCol = "{0,12}" -f $newestDate; $typeCol = "{0,4}" -f $typeCount; $devCol = "{0,8}" -f $devCount
Write-Host -f cyan ("-" * 100); Write-Host -f white $labelCol -n; Write-Host -f white " $filesCol" -n; Write-Host -f darkgray " $oldCol" -n; Write-Host -f green " $newCol" -n; Write-Host -f white " $typeCol" -n; Write-Host -f white " $devCol"; Write-Host -f cyan ("-" * 100); ""; return}

# Usage Error handling for no $cmd.
if (-not $cmd -and -not $all) {Write-Host -f cyan "`nUsage: version `"command`" -purge #(maxhistory) -(dev/stable) -quiet -hidden -all -force -(compare -savedifferences -differences) -list -help`n"
Write-Host -f yellow "-purge " -n; Write-Host -f white "deletes all histories of a command."
Write-Host -f yellow "# " -n; Write-Host -f white "sets the maximum number of copies to retain; 10 being the default."
Write-Host -f yellow "-dev " -n; Write-Host -f white "marks the command as being under development, which temporarily turns off pruning, but -stable turns it back on."
Write-Host -f yellow "-quiet " -n; Write-Host -f white "reduces screen output to a minimum."
Write-Host -f yellow "-hidden " -n; Write-Host -f white "attempts to find and backup private/hidden functions within a module."
Write-Host -f yellow "`n-all " -n; Write-Host -f white "backs up every function and alias available as a result of the current user profile."
Write-Host -f yellow "	-force " -n; Write-Host -f white "forces a refresh of the -all backup, even if not the first of the month."
Write-Host -f yellow "`n-compare " -n; Write-Host -f white "compares different versions of the backup file with each other."
Write-Host -f yellow "	-differences " -n; Write-Host -f white "shows only lines that are different." 
Write-Host -f yellow "	-savedifferences " -n; Write-Host -f white "saves the differences comparison to an output file: " -n; Write-Host -f green "command - yyyy-mm-dd_hh-mm-ss & yyyy-mm-dd_hh-mm-ss.differences." 
Write-Host -f yellow "`n-list " -n; Write-Host -f white "presents a detailed table of all backups available." 
; Write-Host -f yellow "`n-help " -n; Write-Host -f white "provides in depth instructions about this function.`n"; return}

# Ensure devflag is created or exists for single commands, but not -all.
if ($dev -and $cmd -and -not $all) {if (Test-Path $devflag) {$devstatus = "The command $cmd is already flagged as being under development. History pruning is therefore curtailed."}
else {New-Item -Path $devflag -ItemType File -Force | Out-Null; $devstatus = "The command $cmd is now flagged as being under development. History pruning is therefore curtailed."}}
if ($dev -and $all) {Write-Host -f red "`nYou can only set the -dev flag for one command at a time.`n"; return}

# -------------------------------- This is the beginning of the compare logic. ---------------------------------------- 

if ($cmd -and ($compare -or $differences -or $savedifferences)) {
# Error checking.
$powershell=Split-Path $profile; $backupFolder=Join-Path $powershell "Archive\Development History\$cmd"
if(-not(Test-Path $backupFolder)) {Write-Host "$cmd version files not found at: $backupFolder" -f red; return}
$backupFiles = Get-ChildItem -Path $backupFolder -File | Where-Object {$_.Name -match "$cmd.*\.backup(\.gz)?$"} | Sort-Object LastWriteTime -Descending
if($backupFiles.Count -lt 2) {Write-Host "Not enough previous versions found to compare (need at least 2)." -f yellow; return}

# Present and select versions to compare.
$newest = $null; $previous = $null; ""
if ($backupFiles.Count -eq 2) {$newest = $backupFiles[0]; $previous = $backupFiles[1]}
else {Write-Host -f cyan "Select the NEWER backup to compare:`n"
for ($i = 0; $i -lt $backupFiles.Count; $i++) {Write-Host "$($i + 1): $($backupFiles[$i].Name)"}
$newerChoice = Read-Host "`nEnter the number for the newer version"
if (-not ($newerChoice -match '^\d+$') -or [int]$newerChoice -lt 1 -or [int]$newerChoice -gt $backupFiles.Count) {Write-Host "Invalid selection." -f red; return}
$newestIndex = [int]$newerChoice - 1; $newest = $backupFiles[$newestIndex]; $olderOptions = @()
for ($i = $newestIndex + 1; $i -lt $backupFiles.Count; $i++) {$olderOptions += $i}
if ($olderOptions.Count -eq 1) {$previous = $backupFiles[$olderOptions[0]]}
else {Write-Host -f cyan "`nSelect the OLDER backup to compare:`n"
foreach ($i in $olderOptions) {Write-Host "$($i + 1): $($backupFiles[$i].Name)"}
$olderChoice = Read-Host "`nEnter the number for the older version"
if (-not ($olderChoice -match '^\d+$') -or -not $olderOptions.Contains([int]$olderChoice - 1)) {Write-Host "Invalid selection." -f red; return}
$previous = $backupFiles[[int]$olderChoice - 1]}}

# Obtain content.
$oldLines = readbackupfilecontent $previous.FullName; $newLines = readbackupfilecontent $newest.FullName; $maxLines = [Math]::Max($oldLines.Count, $newLines.Count)
""; Write-Host -f yellow ("-" * 100); Write-Host -f cyan "Comparing previous versions:"; Write-Host -f yellow "Recent: " -n; Write-Host -f white "$($newest.Name)"; Write-Host -f green "Older: " -n; Write-Host -f white "$($previous.Name)"

# Defined basic fuzzy match ratio.
function getmatchratio {param ($a, $b)
if (-not $a -or -not $b) {return 0}
$maxLen = [Math]::Max($a.Length, $b.Length); $same = 0
for ($i = 0; $i -lt $maxLen; $i++) {if ($i -lt $a.Length -and $i -lt $b.Length -and $a[$i] -eq $b[$i]) {$same++}}
return [Math]::Round($same / $maxLen, 2)}

# Compare with fuzzy matching and display.
$maxLines = [Math]::Max($oldLines.Count, $newLines.Count)
if (-not $differences) {Write-Host -f yellow ("-"*100); Write-Host -f white "Lines that exist in both files will appear in white. "; Write-Host -f cyan "Lines that have at least an 80% match between both files will appear in cyan. "; Write-Host -f yellow "Lines that have less than an 80% match or do not appear at all in the other file will appear in yellow."; Write-Host -f yellow ("-"*100); ""
for ($i = 0; $i -lt $maxLines; $i++) {$oldExists = $i -lt $oldLines.Count
$newExists = $i -lt $newLines.Count
$oldLine = if ($oldExists) {$oldLines[$i]} else {""}
$newLine = if ($newExists) {$newLines[$i]} else {""}
$ratio = getmatchratio $oldLine $newLine
if ($oldExists) {$oldColor = if ($ratio -eq 1 -or ($newExists -and $newLines -contains $oldLine)) {"White"} else {"Yellow"}
Write-Host ("{0}: Old: {1}" -f ($i+1), $oldLine) -f $oldColor}
if ($newExists) {$newColor = if ($ratio -eq 1 -or ($oldExists -and $oldLines -contains $newLine)) {"White"} else {"Yellow"}
Write-Host ("{0}: New: {1}" -f ($i+1), $newLine) -f $newColor}
if ($oldExists -and $newExists) {Write-Host ("-" * 100) -f yellow}}
Write-Host ""; Write-Host ("-" * 100) -f yellow; Write-Host ""}

if ($differences -or $savedifferences) {$differenceOutput = @(); $uniqueOld = [System.Collections.Generic.List[string]]::new(); $uniqueNew = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $oldLines.Count; $i++) {$oldLine = $oldLines[$i].Trim()
if ($oldLine -and (-not ($newLines -contains $oldLine))) {$lineNum = $i + 1; $uniqueOld.Add("$lineNum`: $oldLine")}}
for ($i = 0; $i -lt $newLines.Count; $i++) {$newLine = $newLines[$i].Trim()
if ($newLine -and (-not ($oldLines -contains $newLine))) {$lineNum = $i + 1; $uniqueNew.Add("$lineNum`: $newLine")}}
if ($uniqueOld.Count -eq 0 -and $uniqueNew.Count -eq 0) {Write-Host -f green "`nNo unique differences found.`n"; return}

# Helper function to print lines with gap detection
$script:differenceOutput = @()
function printwithgaps ($lines, $colour) {$prevNum = 0
foreach ($line in $lines) {if ($line -match '^(\d+):') {$currNum = [int]$matches[1]
if ($prevNum -ne 0 -and ($currNum -gt $prevNum + 1)) {Write-Host ("-" * 100) -f $colour; $script:differenceOutput += ("-" * 100)}
$prevNum = $currNum}
Write-Host $line -f $colour; $script:differenceOutput += $line}}

# Add header lines to output
Write-Host ""; Write-Host -f yellow ("-" * 100); Write-Host -f yellow "Unique Differences Between Files"; Write-Host -f yellow ("-" * 100); Write-Host ""
$script:differenceOutput += ""; $script:differenceOutput += ("-" * 100); $script:differenceOutput += "Unique Differences Between Files"; $script:differenceOutput += ("-" * 100); $script:differenceOutput += ""

printwithgaps $uniqueOld 'gray'
if ($uniqueOld.Count -gt 0 -and $uniqueNew.Count -gt 0) {Write-Host ""; Write-Host -f yellow ("-" * 100); Write-Host ""; $script:differenceOutput += ""; $script:differenceOutput += ("-" * 100); $script:differenceOutput += ""}
printwithgaps $uniqueNew 'white'
Write-Host ""; Write-Host ("-" * 100) -f yellow; Write-Host ""; $script:differenceOutput += ""; $script:differenceOutput += ("-" * 100); $script:differenceOutput += ""

# Save the differences to file if requested
if ($savedifferences) {$oldStamp = $previous.Name -replace "^$cmd - (\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})\.backup", '$1'; $newStamp = $newest.Name -replace "^$cmd - (\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})\.backup", '$1'; $diffFile = Join-Path $backupFolder "$cmd - $oldStamp & $newStamp.differences"; $script:differenceOutput | Out-File -FilePath $diffFile -Encoding UTF8; Write-Host -f cyan "Differences saved to: $diffFile`n"}}; return}

# -------------------------------- This is the end of the compare logic. ---------------------------------------------- 

# -------------------------------- This is the beginning of the primary version logic. -------------------------------- 

# Main version function.
function archive {param ([string]$cmd, [int]$maxhistory, [switch]$stable, [switch]$quiet, [switch]$purge)

$backupdirectory = Join-Path (Split-Path $profile) "Archive\Development History\$cmd"; $devflag = Join-Path $backupdirectory ".development_flag"; $validatecommand = Get-Command $cmd -ErrorAction SilentlyContinue

# Purge can be run against single commands or all commaands. This deletes the entire version directory of a command.
if ($purge) {Remove-Item $backupdirectory -Recurse -Force -ErrorAction SilentlyContinue; Write-Host -f red "`nDirectory for $cmd has been purged.`n"; return}
if (-not $validatecommand -or $validatecommand.CommandType -notin 'Function','ExternalScript','Alias') {Write-Host -f gray "$cmd`: " -n; Write-Host -f darkgray "is not an exported command. Skipping."; return}
$cmddetails = (Get-Command $cmd).definition; $cmdsourceinfo = (Get-Command $cmd).source; $callcmd = (Get-Command $cmd).displayname; $cmd = $cmd.tolower()

# -------------------------------- This is the beginning of the version file creation. --------------------------------

# Obtain the command details and artifically build and append the alias command to the end of the parent function, if the command referenced is an alias.
if ($validatecommand.CommandType -in 'Alias') {$parentfunction = (Get-Command $cmddetails).definition; $truecommand = "$parentfunction`nsal -Name $cmd -Value $cmddetails"; $cmddetails = $truecommand}

# Add any script content to the end of both the command and the alias, if the command is simply a placeholder for an external script. This uses Regex to determine logical calls to external scripts.
if ($cmddetails -match '(?i)\$script\w*\s*=\s*["'']?([^"]+\.ps1)[";&.\s]+\$script') {$ps1file = $matches[1]
if ($ps1file -match '(\$\w+)') {$varName = $matches[1].Substring(1); $varValue = (Get-Variable -Name $varName).Value; $ps1file = $ps1file -replace [regex]::Escape($matches[1]), $varValue}
if (Test-Path $ps1file) {$ps1file = Resolve-Path $ps1file -ErrorAction SilentlyContinue; $ps1Content = Get-Content $ps1file -Raw; $cmddetails += "`n" + ("-" * 100) + "`n" + $ps1Content}}

# Obtain the PSD1 file if it exists and append it to the end, as well.
$psd1path = [System.IO.Path]::ChangeExtension($(Get-Module $cmd).Path, '.psd1')
if (Test-Path $psd1path) {$psd1Content = Get-Content $psd1path -Raw; $cmddetails += "`n" + ("-" * 100) + "`n" + $psd1Content}

# Output the command details, with all additions, such as alias and script to the screen, if the -quiet flag is not set.
if (-not $quiet) {""; Write-Host -f cyan "Command: " -n; Write-Host -f yellow $cmd; Write-Host -f cyan "Source: " -n; Write-Host -f yellow $cmdsourceinfo; Write-Host -f yellow ("-"*100); Write-Host -f white $cmddetails"`n"; Write-Host -f yellow ("-"*100)}

# Ensure devflag is removed or not set. This can be run against single commands or all commands.
if ($devstatus.length -gt 1) {Write-Host -f cyan $devstatus}
if ($stable) {if (-not (Test-Path $devflag)) {Write-Host -f cyan "The command `"$cmd`" was not flagged as being under development. Therefore, no adjustment was necessary."}
elseif (Test-Path $devflag) {Remove-Item $devflag -Force; Write-Host -f cyan "The command `"$cmd`" is now flagged as being a stable release. Therefore, the development flag has been removed."}}

# Write the file.
$filename = "$cmd - $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').backup"; $backup = Join-Path $backupdirectory $filename; New-Item -ItemType Directory $backupdirectory -Force | Out-Null; $cmddetails | Out-File $backup -Force 

# If file is larger than 1KB, compress it and delete the original
if ((Get-Item $backup).Length -gt 1KB) {$gzipFile = "$backup.gz"; $fs = [System.IO.File]::OpenRead($backup); $gzfs = [System.IO.File]::Create($gzipFile); $gz = New-Object System.IO.Compression.GZipStream($gzfs, [System.IO.Compression.CompressionMode]::Compress); $fs.CopyTo($gz); $gz.Close(); $fs.Close(); $gzfs.Close(); Remove-Item $backup -Force; $backup = $gzipFile}

# -------------------------------- This is the end of the version file creation. -------------------------------------- 

# Keep only unique hashes. This will also delete the current file that was just created, if the hash for it is identical to a previous version.
$sha256 = [System.Security.Cryptography.SHA256]::Create(); $files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Name -match '\.backup(\.gz)?$'}; $hashToFiles = @{}
foreach ($file in $files) {try {if ($file.Extension -eq '.gz') {$fs = [System.IO.File]::OpenRead($file.FullName); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $ms = New-Object System.IO.MemoryStream; $gz.CopyTo($ms); $gz.Close(); $fs.Close(); $fileBytes = $ms.ToArray(); $ms.Close()}
else {$fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)}
$fileHashBytes = $sha256.ComputeHash($fileBytes); $fileHash = [System.BitConverter]::ToString($fileHashBytes) -replace '-', ''
if (-not $hashToFiles.ContainsKey($fileHash)) {$hashToFiles[$fileHash] = @()}; $hashToFiles[$fileHash] += $file}
catch {Write-Warning "Failed to hash file $($file.FullName): $_"}}
foreach ($group in $hashToFiles.Values) {$sortedGroup = $group | Sort-Object LastWriteTime
if ($sortedGroup.Count -gt 1) {$sortedGroup[1..($sortedGroup.Count - 1)] | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Display results of the hash comparison determination.
if (Test-Path $backup) {if ($quiet) {Write-Host -f white "$backup saved."}	
elseif (-not $quiet) {Write-Host -f green "File $backup saved."; Write-Host -f yellow ("-" * 100)}}
if (-not (Test-Path $backup)) {Write-Host -f white "$cmd`: " -n; Write-Host -f red "The current backup would be identical to an existing file, therefore the latest version is not being retained."}

# Group files by date and keep only the oldest and newest per day, except when the -dev flag is set, at which point all non-identical hashes will be kept.
if (-not $dev -and -not (Test-Path $devflag)) {$files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Name -match '\.backup(\.gz)?$'} | Sort-Object Name; $filesByDate = $files | Group-Object {if ($_ -match '(\d{4}-\d{2}-\d{2})_\d{2}-\d{2}-\d{2}') {$matches[1]}
else {'unknown'}}
foreach ($group in $filesByDate) {$sortedGroup = $group.Group | Sort-Object Name
if ($sortedGroup.Count -gt 2) {$sortedGroup[1..($sortedGroup.Count - 2)] | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Enforce maxhistory count globally by deleting oldest files beyond the set limit, but also only if the -dev flag is not set.
$files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Name -match '\.backup(\.gz)?$'} | Sort-Object LastWriteTime; $excess = $files.Count - $maxhistory
if ($excess -gt 0) {$files | Select-Object -First $excess | ForEach-Object {Remove-Item $_.FullName -Force}}}

# Enumerate the versions that exist within the command's version directory, but only if the -quiet flag is not set.
if (-not $quiet) {Write-Host -f yellow "`nAvailable versions:`n"
$headers = @("Size", "SHA256", "Last Modified"); $padding = 5; $files = Get-ChildItem -Path $backupdirectory -File | Where-Object {$_.Extension -in '.backup', '.gz' -or $_.Name -eq '.development_flag'}; $rows = foreach ($file in $files) {if ($file.Name -eq '.development_flag') {[PSCustomObject]@{Size = "0 bytes"; SHA256 = ".development_flag was set"; 'Last Modified' = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")}}
else {if ($file.Extension -eq '.gz') {$fs = [System.IO.File]::OpenRead($file.FullName); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $ms = New-Object System.IO.MemoryStream; $gz.CopyTo($ms); $gz.Close(); $fs.Close(); $rawBytes = $ms.ToArray(); $ms.Close(); $sha256 = [System.Security.Cryptography.SHA256]::Create(); $hashBytes = $sha256.ComputeHash($rawBytes); $hashValue = [BitConverter]::ToString($hashBytes) -replace '-', ''}
else {$hashValue = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash}
[PSCustomObject]@{Size = "$($file.Length) bytes"; SHA256 = $hashValue; 'Last Modified' = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")}}}
$widths = @{}; foreach ($header in $headers) {$maxLen = ($rows | ForEach-Object {($_.PSObject.Properties[$header].Value.ToString()).Length;}) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum; $widths[$header] = [Math]::Max($maxLen, $header.Length)}
$spacer = ' ' * $padding
$headerLine = ($headers | ForEach-Object {$_.PadRight($widths[$_]);}) -join $spacer; Write-Host $headerLine -f cyan
foreach ($row in $rows | Sort-Object 'Last Modified' -Descending) {$line = foreach ($header in $headers) {$value = $row.PSObject.Properties[$header].Value.ToString(); if ($header -eq "Size") {$value.PadLeft($widths[$header])} else {$value.PadRight($widths[$header])}}; Write-Host ($line -join $spacer) -f white}; ""; Write-Host -f yellow ("-"*100); ""}}

# -------------------------------- This is the end of the primary version logic. -------------------------------------- 

# Run version against a single command.
if (-not $all) {archive -cmd $cmd -maxhistory $maxhistory -stable:$stable -quiet:$quiet -purge:$purge; return}

# Alternately, run version against every command.
if ($all) {$today = [int](Get-Date).day; $ranflag = "$PowerShell\Archive\Development History\.backupallversions"; $devHistoryPath = "$PowerShell\Archive\Development History"; $zipFile = "$PowerShell\Archive\Retired Functions and Aliases.zip"
if ($force) {$today = 1; try {Remove-Item $ranflag -Force -ea SilentlyContinue| Out-Null} catch {""}}
if ($today -eq 1 -and !(Test-Path $ranflag)) {Get-ChildItem -Path (Split-Path -Parent $PROFILE) -Recurse -Include *.ps1, *.psm1 | ForEach-Object {Select-String -Path $_.FullName -Pattern '^\s*function\s+([\w\-]+)', '^\s*(sal|set-alias)\s+-name\s+(\w+)' | ForEach-Object {$_.Matches | ForEach-Object {$fn = if ($_.Groups.Count -gt 2) {$_.Groups[2].Value} else {$_.Groups[1].Value}; if (-not ($fn -eq 'archive' -and $scriptPath -eq $MyInvocation.MyCommand.Path)) {$fn}}}} | Sort-Object -Unique | ForEach-Object {archive -cmd $_ -maxhistory $maxhistory -stable:$stable -quiet:$quiet -purge:$purge}; New-Item -Path $ranflag -ItemType File -Force | Out-Null}
if ($today -ne 1 -and (Test-Path $ranflag)) {Remove-Item $ranflag -Force | Out-Null}

# When running version against all commands, enumerate and compare directories to current assets and archive retired ones at the end of the process.
$currentFunctionsAndAliases = Get-Command -Type Function, Alias | Select-Object -ExpandProperty Name

# Extract function and alias names from the profile file(s)
$profileFiles = Get-Item $PROFILE* -ErrorAction SilentlyContinue | Where-Object {$_ -and (Test-Path $_)}; $profileExtras = @()
foreach ($file in $profileFiles) {$matches = Select-String -Path $file.FullName -Pattern '^\s*function\s+([\w\-]+)', '^\s*(sal|set-alias)\s+-name\s+(\w+)' -AllMatches
foreach ($match in $matches) {foreach ($m in $match.Matches) {$name = if ($m.Groups.Count -gt 2) {$m.Groups[2].Value}
else {$m.Groups[1].Value}
if ($name -and $name -notin $profileExtras) {$profileExtras += $name}}}}
$currentFunctionsAndAliases += $profileExtras | Sort-Object -Unique; $existingDirs = Get-ChildItem -Path $devHistoryPath -Directory | Select-Object -ExpandProperty Name; $retiredDirs = $existingDirs |  Where-Object {$_ -notin $currentFunctionsAndAliases -and $_ -notlike '.hidden*'}
if ($retiredDirs.Count -gt 2) {Write-Host -f white "The following commands are not present in the current session: " -n; $retiredDirs -join ", " | Write-Host -f cyan; Write-Host -f white "This means that there are " -n; Write-Host -f green $retiredDirs.Count -n; Write-Host -f white " directories to archive. Are you sure you want to continue? " -n; [console]::foregroundcolor = "red"; $response = Read-Host "(Y/N)"; if ($response -notmatch "(?i)^Y") {[console]::foregroundcolor = "gray"; ""; return}}
[console]::foregroundcolor = "gray"; if ($retiredDirs.Count -gt 0) {$retiredDirs | ForEach-Object {$dirPath = Join-Path $devHistoryPath $_; 
if (-not (Test-Path $dirPath)) {Write-Host "Warning: Directory not found: $dirPath"}
else {if (Test-Path $zipFile) {Compress-Archive -Path $dirPath -DestinationPath $zipFile -Update}
elseif (-not (Test-Path $zipFile)){Compress-Archive -Path $dirPath -DestinationPath $zipFile}
Remove-Item -Path $dirPath -Recurse -Force}}
Write-Host -f yellow "Retired Functions and Aliases archive updated with the following directories: " -n; $retiredDirs -join ", " | Write-Host -f white}}}

Export-ModuleMember -Function version

# -------------------------------- Help screens -----------------------------------------------------------------------
<#
## Version

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
## Advanced Options
The -hidden option will attempt to find and backup private/hidden functions within a module.

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
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
