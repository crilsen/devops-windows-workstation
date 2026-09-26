# Architecture

## Flow

`bootstrap.ps1` is the single entry point. It sources `scripts/Common.ps1` and invokes each stage in order. Flags (`-SkipWSL`, `-SkipDocker`, `-Minimal`, `-InstallTools`, `-ConfigureTerminal`) select subsets; `-WhatIf`/`-Verbose` propagate through `SupportsShouldProcess`.

```text
Install-Prerequisites → Install-WSL → Install-DevOpsTools → Configure-PowerShell → Configure-OhMyPosh → Configure-Terminal → Test-Environment
```

## Stages

1. **Install-Prerequisites**: Windows build check (19041+ for WSL2), admin detection (warn-only), winget presence, PowerShell 7 + Windows Terminal validation, `CurrentUser` execution policy to `RemoteSigned` only when restrictive.
2. **Install-WSL**: requires `wsl` CLI; sets default version 2, installs Ubuntu when absent, deploys `configs/.wslconfig` only when the user has none. No guest package installation in the MVP.
3. **Install-DevOpsTools**: winget-first installs with binary-presence checks (`Test-CommandAvailable`). Docker and Azure CLI are opt-out/opt-in. `-Minimal` narrows to the core set.
4. **Configure-PowerShell**: deploys `configs/Microsoft.PowerShell_profile.ps1` verbatim to `$PROFILE.CurrentUserAllHosts` with timestamped backup and content-equality short-circuit.
5. **Configure-OhMyPosh**: installs Oh My Posh + Cascadia Code, deploys `configs/oh-my-posh.json` to `~/.oh-my-posh/devops-workstation.json` with the same backup semantics.
6. **Configure-Terminal**: parses the existing `settings.json`, backs it up, sets `defaultProfile` to PowerShell 7 when found, enables `copyOnSelect`, and applies font/acrylic/cursor to PowerShell/Ubuntu profiles only. Unrelated profiles are untouched. Missing file → skip + pointer to the example.
7. **Test-Environment**: probes each binary for a version string, checks the Nerd Font registry key best-effort, runs read-only `aws sts get-caller-identity` only when it succeeds, and prints the summary table.

## Idempotency and safety

- Check-before-change everywhere; `[OK] / [CHANGE] / [SKIP]` log lines make convergence visible.
- Mutations go through `Backup-File` (`<name>.backup-YYYYMMDD-HHmmss`).
- No secrets are created or stored; no firewall/Defender/policy weakening.
