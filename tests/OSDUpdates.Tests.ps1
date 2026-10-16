$modulePath = Join-Path $PSScriptRoot '..\OSDUpdates.psd1'

Describe 'OSDUpdates module structure' {
    BeforeAll { Import-Module $modulePath -Force -ErrorAction Stop }

    It 'exports three public commands' {
        $names = @(Get-Command -Module OSDUpdates | Select-Object -ExpandProperty Name)
        $names | Should -Contain 'Get-OSDUpdateTarget'
        $names | Should -Contain 'Test-OSDUpdateCache'
        $names | Should -Contain 'Install-OSDUpdate'
    }

    It 'rejects a missing update directory' {
        { Test-OSDUpdateCache -UpdatePath (Join-Path $TestDrive 'missing') } | Should -Throw
    }

    It 'rejects a directory without MSU files' {
        $directory = Join-Path $TestDrive 'empty'
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
        { Test-OSDUpdateCache -UpdatePath $directory } | Should -Throw
    }

    It 'lists local MSU files with correct SHA-256' {
        $directory = Join-Path $TestDrive 'cached'
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
        $file = Join-Path $directory 'test.msu'
        [System.IO.File]::WriteAllText($file, 'test-content')
        $records = @(Test-OSDUpdateCache -UpdatePath $directory)
        $records.Count | Should -Be 1
        $records[0].Name | Should -Be 'test.msu'
        $records[0].SHA256 | Should -Be (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    }

}
