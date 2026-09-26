# devops-windows-workstation

Automated Windows DevOps workstation provisioning with PowerShell and WSL2, including cloud-native tooling and a fully preconfigured terminal experience.

![PowerShell terminal](docs/screenshots/powershell-terminal.png)
![Ubuntu WSL terminal](docs/screenshots/ubuntu-terminal.png)

## Why this project?

A clean Windows install takes hours of manual setup before it is usable for Cloud/DevOps work: installing tools one by one, configuring the terminal, enabling WSL2, aligning versions across machines. This project turns that into one reproducible command.

It is built as a real workstation automation and onboarding flow, not a loose collection of install commands:

- **Infrastructure automation**: every step is scripted and repeatable.
- **Reproducibility**: the same bootstrap converges to the same baseline.
- **Workstation standardization**: new machines match the same layout, fonts, prompt and toolset.
- **Developer experience**: prompt, aliases, completion and history work out of the box.
- **Configuration management**: existing user files are backed up, never destroyed.
- **Idempotency**: re-running the bootstrap only changes what drifted.

## Architecture

```text
bootstrap.ps1
├── scripts/Common.ps1              shared logging, backup, winget helpers
├── scripts/Install-Prerequisites.ps1  Windows version, admin, PS7, Terminal
├── scripts/Install-WSL.ps1           WSL2 + Ubuntu + .wslconfig
├── scripts/Install-DevOpsTools.ps1   winget-based tool installs
├── scripts/Configure-PowerShell.ps1  profile + PSReadLine + aliases
├── scripts/Configure-OhMyPosh.ps1    prompt theme + Nerd Font
├── scripts/Configure-Terminal.ps1    Windows Terminal install + safe settings patch
├── scripts/Configure-Docker.ps1      Docker Desktop WSL2 backend + Ubuntu integration
└── scripts/Test-Environment.ps1      final validation table
```

See [docs/architecture.md](docs/architecture.md) for details and [docs/customization.md](docs/customization.md) for tuning.

## Prerequisites

- Windows 10 build 19041+ or Windows 11
- Administrator rights (for WSL enablement and some installs)
- [App Installer / winget](https://learn.microsoft.com/windows/package-manager/winget/) for automatic tool installation
- Internet access

## Quick start

```powershell
git clone https://github.com/crilsen/devops-windows-workstation.git
cd devops-windows-workstation

.\bootstrap.ps1
```

Focused runs:

```powershell
.\bootstrap.ps1 -SkipDocker
.\bootstrap.ps1 -SkipWSL
.\bootstrap.ps1 -Minimal
.\bootstrap.ps1 -InstallTools
.\bootstrap.ps1 -ConfigureTerminal
.\bootstrap.ps1 -WhatIf
.\bootstrap.ps1 -Verbose
```

Expected ending:

```text
DevOps Workstation Bootstrap

[OK] PowerShell 7
[OK] Windows Terminal
[OK] WSL2
[OK] Ubuntu
[OK] Git
[OK] AWS CLI
[OK] kubectl
[OK] Helm
[OK] Terraform
[OK] OpenTofu
[OK] Docker
[OK] Oh My Posh
[OK] Nerd Font

Workstation ready.

Restart Windows Terminal to load the new configuration.
```

## Tools installed

| Tool | Provider | Notes |
| --- | --- | --- |
| Git | winget `Git.Git` | idempotent check via `git` |
| Visual Studio Code | winget `Microsoft.VisualStudioCode` | |
| Windows Terminal | winget `Microsoft.WindowsTerminal` | installed when missing; patched, never replaced |
| PowerShell 7 | winget `Microsoft.PowerShell` | set as default profile |
| Docker Desktop | winget `Docker.DockerDesktop` | skipped with `-SkipDocker` / `-Minimal`; WSL2 backend + Ubuntu integration configured |
| AWS CLI v2 | winget `Amazon.AWSCLI` | version + optional `sts get-caller-identity` |
| kubectl | winget `Kubernetes.kubectl` | |
| Helm | winget `Helm.Helm` | |
| Terraform | winget `HashiCorp.Terraform` | |
| OpenTofu | winget `OpenTofu.OpenTofu` | |
| GitHub CLI | winget `GitHub.cli` | |
| jq | winget `jqlang.jq` | |
| curl | winget `curl.curl` | |
| 7-Zip | winget `7zip.7zip` | |
| Oh My Posh | winget `JanDeDobbeleer.OhMyPosh` | bundled theme in `configs/` |
| Nerd Font (Cascadia) | winget `Microsoft.CascadiaCode` | applied to Terminal profiles |
| Azure CLI | optional | set `INSTALL_AZURE_CLI=1` to include |

Already-installed tools are detected and skipped: `[OK] Git already installed`.

## Bootstrap options

| Flag | Effect |
| --- | --- |
| `-SkipWSL` | skip WSL2/Ubuntu setup |
| `-SkipDocker` | skip Docker Desktop install and configuration |
| `-Minimal` | core tools only (Git, PS7, Terminal, VS Code, AWS CLI, kubectl) |
| `-InstallTools` | run the tools path only |
| `-ConfigureTerminal` | run the terminal path only |
| `-WhatIf` / `-Verbose` | dry run / detailed logging (via `SupportsShouldProcess`) |

## Project structure

```text
.
├── bootstrap.ps1
├── configs/
│   ├── Microsoft.PowerShell_profile.ps1
│   ├── oh-my-posh.json
│   ├── terminal-settings.example.json
│   ├── docker-settings.example.json
│   └── .wslconfig
├── scripts/
│   ├── Common.ps1
│   ├── Install-Prerequisites.ps1
│   ├── Install-DevOpsTools.ps1
│   ├── Install-WSL.ps1
│   ├── Configure-PowerShell.ps1
│   ├── Configure-Terminal.ps1
│   ├── Configure-OhMyPosh.ps1
│   ├── Configure-Docker.ps1
│   └── Test-Environment.ps1
├── docs/
│   ├── architecture.md
│   ├── customization.md
│   └── screenshots/
├── tests/
└── .github/workflows/ci.yml
```

## Terminal experience

Bundled Oh My Posh theme (`configs/oh-my-posh.json`) is local-first: no remote theme dependency after install. It shows shell/OS icon, user, path, Git branch/status, AWS profile/region, Kubernetes context/namespace, last-command status and long-command duration.

Conceptual prompt:

```text
 PS  Cristiano  ❯  C:\Projects  ❯  main  ❯  ☁ aws-lab  ❯  ☸ eks-dev
```

In WSL:

```text
 Ubuntu  ❯  ~/projects  ❯  main
```

Screenshots:

- `docs/screenshots/powershell-terminal.png` — PowerShell prompt (placeholder)
- `docs/screenshots/ubuntu-terminal.png` — Ubuntu/WSL prompt (placeholder)
- `docs/screenshots/bootstrap-run.png` — bootstrap output (placeholder)
- `docs/screenshots/validation.png` — `Test-Environment` table (placeholder)

## Docker Desktop

`scripts/Configure-Docker.ps1` patches `%APPDATA%\Docker\settings.json` with a timestamped backup: it enables the WSL2 engine (`wslEngineEnabled`) and ensures Ubuntu stays in `integratedWslDistros`, preserving every other setting. It never fabricates a full settings file — when Docker Desktop has never launched, it skips with a pointer to `configs/docker-settings.example.json`. Restart Docker Desktop to apply. `Test-Environment.ps1` adds a read-only `docker info` check on top of `docker --version`.

## Security

- Never stores AWS access keys or creates credentials.
- Only runs `aws --version`, plus read-only `aws sts get-caller-identity` when credentials already exist.
- No firewall changes, no Defender changes, no global `ExecutionPolicy` relaxation (only `CurrentUser` → `RemoteSigned` when currently `Restricted`/`AllSigned`).
- Every mutated user file (profile, `.wslconfig`, Terminal `settings.json`, Docker `settings.json`, prompt theme) gets a timestamped backup such as `settings.json.backup-20260926-143210`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `winget not found` | install App Installer from the Microsoft Store, then re-run |
| WSL install asks for reboot | reboot, then re-run `.\bootstrap.ps1` (idempotent) |
| Terminal `settings.json` missing | open Windows Terminal once, then re-run (the Terminal is installed automatically when missing) |
| Prompt glyphs look broken | verify the Nerd Font step ran and Terminal font is `CaskaydiaCove Nerd Font` |
| Docker engine not running | launch Docker Desktop; re-run to re-apply WSL2 backend + Ubuntu integration |
| Docker `settings.json` missing | launch Docker Desktop once so it generates the file, then re-run |
| AWS check skipped | expected when no credentials exist; configure via `aws configure sso` or `aws configure` |

## Customization

See [docs/customization.md](docs/customization.md): prompt segments, fonts, `.wslconfig` limits, aliases, Terminal opacity/cursor and Docker Desktop WSL integration.

## Roadmap

- Workstation profiles (minimal / standard / full)
- Chocolatey / Scoop as alternative providers
- Optional tooling inside WSL guests
- SSH / GPG setup
- Dotfiles management
- Dev Containers support
- Azure / GCP tooling profiles
- Pester tests and CI lint/test execution
- Declarative YAML configuration
