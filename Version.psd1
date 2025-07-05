@{
RootModule = 'version.psm1'
ModuleVersion = '1.3'
GUID = 'd5f8e5b3-1a23-4a9f-8b7c-9e6c5b3a2f47'
Author = 'Schvenn'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '(c) Craig Plath. All rights reserved.'
Description = 'PowerShell command versioning and archiving module with comparison, history pruning, and intelligent duplicate detection.'
PowerShellVersion = '5.1'
FunctionsToExport = @('version')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('version.psm1','license.txt')
PrivateData = @{
PSData = @{
Tags = @('archive','backup','compare','development','devops','history','versioning')
LicenseUri = 'https://github.com/Schvenn/Version/blob/main/license.txt'
ProjectUri = 'https://github.com/Schvenn/Version'
ReleaseNotes = 'Initial PowerShell gallery release. Versioning and archiving system for PowerShell commands.'
}}}
