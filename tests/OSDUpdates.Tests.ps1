$modulePath = Join-Path $PSScriptRoot '..\OSDUpdates.psd1'
Describe 'OSDUpdates module structure' {
    BeforeAll { Import-Module $modulePath -Force }
    It 'exports target detection' { Get-Command Get-OSDUpdateTarget | Should -Not -BeNullOrEmpty }
    It 'exports cache checking' { Get-Command Test-OSDUpdateCache | Should -Not -BeNullOrEmpty }
    It 'exports installation' { Get-Command Install-OSDUpdate | Should -Not -BeNullOrEmpty }
    It 'rejects a missing update directory' {
        { Test-OSDUpdateCache -UpdatePath (Join-Path $TestDrive 'missing') } | Should -Throw
    }
}
