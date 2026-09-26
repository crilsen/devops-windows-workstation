# Customization

## Prompt (`configs/oh-my-posh.json`)

Local-first theme: edit the JSON, then re-run `scripts/Configure-OhMyPosh.ps1` (or `bootstrap.ps1 -ConfigureTerminal`). Segments degrade gracefully: AWS/Kubernetes/Git blocks render nothing when their CLIs or contexts are absent.

- OS icon switches Windows/Ubuntu automatically (`os` segment).
- Hide AWS when you do not use it: remove the `aws` segment or set `"display_default": false` (already set).
- Kubernetes errors are suppressed (`"display_error": false`).
- Long-command threshold is 5s (`executiontime.threshold`); raise it to reduce noise.
- Override per-machine without editing the repo: set `$env:POSH_THEME` to a custom JSON path; the profile prefers it when set.

## PowerShell profile (`configs/Microsoft.PowerShell_profile.ps1`)

Aliases: `k` (kubectl), `tf` (terraform), `g` (git), `d` (docker). Add yours at the bottom. `Add-PathOnce` keeps `PATH` duplicate-free. PSReadLine history/completion/predictions can be tuned via `Set-PSReadLineOption`.

## WSL (`configs/.wslconfig`)

Deployed once to `%USERPROFILE%\.wslconfig`. Tune `memory`, `processors`, `swap` to the host. Restart WSL (`wsl --shutdown`) to apply. The repo default is 8GB/4CPU/8GB swap with `localhostForwarding` and sparse VHD.

## Windows Terminal (`configs/terminal-settings.example.json`)

Reference only. `Configure-Terminal.ps1` installs Windows Terminal when `wt` is missing, then applies: PowerShell 7 default, `CaskaydiaCove Nerd Font`, acrylic 0.92, bar cursor, `copyOnSelect`. Adjust opacity down (e.g. `0.85`) for more transparency or set `useAcrylic: false` for maximum legibility.

## Docker Desktop (`configs/docker-settings.example.json`)

Reference subset. `Configure-Docker.ps1` enables the WSL2 engine and adds Ubuntu to `integratedWslDistros` in `%APPDATA%\Docker\settings.json`, keeping every other key untouched. Re-run the script after editing the example to converge. Restart Docker Desktop to apply; run `wsl --shutdown` if the integration does not pick up immediately.

## Cloud profiles (`-Cloud AWS|Azure|OCI|GCP|All`)

Default is AWS only. Combine providers (`-Cloud Azure,GCP`) or take everything (`-Cloud All`). The selection drives winget installs on Windows and `scripts/wsl-setup.sh` arguments in Ubuntu. Validate with `scripts/Test-Environment.ps1 -Cloud <same selection>`.

## Ubuntu guest (`scripts/wsl-setup.sh`)

Runs inside Ubuntu via `wsl -d Ubuntu`. Installs base packages, kubectl (stable binary), Helm (official installer) and the selected cloud CLIs from vendor sources. Add guest packages in the base section following the existing `has_cmd` guard. Terraform/OpenTofu guest installs are intentionally left out for now — tracked in the roadmap.
