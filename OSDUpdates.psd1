@{
RootModule = 'OSDUpdates.psm1'
ModuleVersion = '0.1.0'
GUID = '9182cf36-4e9d-47b7-9d29-a9cb387cd213'
Author = 'OSDUpdates contributors'
Description = 'Offline Windows cumulative update servicing for deployment environments.'
PowerShellVersion = '5.1'
FunctionsToExport = @('Get-OSDUpdateTarget','Test-OSDUpdateCache','Install-OSDUpdate')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
PrivateData = @{ PSData = @{ Tags = @('WinPE','Windows','DISM','OfflineServicing') } }
}
