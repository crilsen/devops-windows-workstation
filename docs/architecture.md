# Architecture

## Flow

`bootstrap.ps1` is the single entry point. It sources `scripts/Common.ps1` and invokes each stage in order. Flags (`-SkipWSL`, `-SkipDocker`, `-Minimal`, `-InstallTools`, `-ConfigureTerminal`) select subsets; `-Cloud` (`AWS`, `Azure`, `OCI`, `GCP`, `All`; default `AWS`) selects cloud provider CLIs on both Windows and Ubuntu; `-WhatIf`/`-Verbose` propagate through `SupportsShouldProcess`.

```text
Install-Prerequisites → Install-WSL (+ guest) → Install-DevOpsTools → Configure-Docker → Configure-PowerShell → Configure-OhMyPosh → Configure-Terminal → Test-Environment
```

## Stages

1. **Install-Prerequisites**: Windows build check (19041+ for WSL2), admin detection (warn-only), winget presence, PowerShell 7 + Windows Terminal validation, `CurrentUser` execution policy to `RemoteSigned` only when restrictive.
2. **Install-WSL**: host side (default version 2, Ubuntu install when absent, `.wslconfig` only when the user has none), then guest provisioning: copies `scripts/wsl-setup.sh` into Ubuntu via `\\wsl$\Ubuntu\tmp` and runs it with the `-Cloud` selection. Skips the guest step until Ubuntu first-run setup completes. The guest script installs base packages (git, curl, jq), kubectl, Helm and the selected cloud CLIs from official sources — never credentials.
3. **Install-DevOpsTools**: winget-first installs with binary-presence checks (`Test-CommandAvailable`). Includes Windows Terminal and Docker Desktop. Cloud CLIs follow `-Cloud`: AWS always, Azure (`Microsoft.AzureCLI`), OCI (`Oracle.OCI-CLI`) and GCP (`Google.CloudSDK`) opt-in. Docker is opt-out; `-Minimal` narrows to the core set.
4. **Configure-Docker**: patches `%APPDATA%\Docker\settings.json` with backup — enables the WSL2 engine and ensures Ubuntu is in `integratedWslDistros`, preserving all other keys. Skips with guidance when Docker Desktop never launched. Restart Docker Desktop to apply.
5. **Configure-PowerShell**: deploys `configs/Microsoft.PowerShell_profile.ps1` verbatim to `$PROFILE.CurrentUserAllHosts` with timestamped backup and content-equality short-circuit.
6. **Configure-OhMyPosh**: installs Oh My Posh + Cascadia Code, deploys `configs/oh-my-posh.json` to `~/.oh-my-posh/devops-workstation.json` with the same backup semantics.
7. **Configure-Terminal**: installs Windows Terminal when `wt` is missing, then parses the existing `settings.json` (Store or per-user path), backs it up, sets `defaultProfile` to PowerShell 7 when found, enables `copyOnSelect`, and applies font/acrylic/cursor to PowerShell/Ubuntu profiles only. Unrelated profiles are untouched. Missing file → skip + pointer to the example.
8. **Test-Environment**: probes each binary for a version string (cloud CLIs only for the selected `-Cloud` profile), checks the Nerd Font registry key best-effort, runs read-only `docker info` and `aws sts get-caller-identity` only when they succeed, and prints the summary table.

## Idempotency and safety

- Check-before-change everywhere; `[OK] / [CHANGE] / [SKIP]` log lines make convergence visible.
- Mutations go through `Backup-File` (`<name>.backup-YYYYMMDD-HHmmss`).
- No secrets are created or stored; no firewall/Defender/policy weakening.
