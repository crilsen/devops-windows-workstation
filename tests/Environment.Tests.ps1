BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'Repository structure' {
    It 'has the bootstrap entry point' {
        Join-Path $repoRoot 'bootstrap.ps1' | Should -Exist
    }

    It 'has all stage scripts' {
        $expected = @(
            'Common.ps1'
            'Install-Prerequisites.ps1'
            'Install-DevOpsTools.ps1'
            'Install-WSL.ps1'
            'Configure-PowerShell.ps1'
            'Configure-Terminal.ps1'
            'Configure-OhMyPosh.ps1'
            'Configure-Docker.ps1'
            'Test-Environment.ps1'
        )
        foreach ($name in $expected) {
            Join-Path $repoRoot "scripts/$name" | Should -Exist
        }
    }

    It 'has bundled configs' {
        Join-Path $repoRoot 'configs/oh-my-posh.json' | Should -Exist
        Join-Path $repoRoot 'configs/Microsoft.PowerShell_profile.ps1' | Should -Exist
        Join-Path $repoRoot 'configs/terminal-settings.example.json' | Should -Exist
        Join-Path $repoRoot 'configs/docker-settings.example.json' | Should -Exist
        Join-Path $repoRoot 'configs/.wslconfig' | Should -Exist
    }

    It 'ships a valid Docker settings example' {
        $example = Join-Path $repoRoot 'configs/docker-settings.example.json'
        { Get-Content $example -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'ships a valid Oh My Posh theme' {
        $theme = Join-Path $repoRoot 'configs/oh-my-posh.json'
        { Get-Content $theme -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'has no syntax errors in PowerShell files' {
        $files = Get-ChildItem -Path (Join-Path $repoRoot 'scripts'), (Join-Path $repoRoot 'bootstrap.ps1') -Filter *.ps1
        foreach ($f in $files) {
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
}
