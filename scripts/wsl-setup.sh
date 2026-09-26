#!/usr/bin/env bash
# Ubuntu (WSL2) guest provisioning for devops-windows-workstation.
# Runs INSIDE Ubuntu, invoked by scripts/Install-WSL.ps1 via `wsl -d Ubuntu`.
# Idempotent: every tool is checked with `command -v` before install.
# Never touches credentials: CLIs are installed, never configured.
#
# Usage: wsl-setup.sh [aws] [azure] [oci] [gcp] [all]
# With no args, installs base tooling + AWS CLI only.
set -euo pipefail

log_ok()     { echo "[OK] $*"; }
log_change() { echo "[CHANGE] $*"; }
log_skip()   { echo "[SKIP] $*"; }
log_step()   { echo "[STEP] $*"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

WANT_AWS=false; WANT_AZURE=false; WANT_OCI=false; WANT_GCP=false

if [ "$#" -eq 0 ]; then
  WANT_AWS=true
else
  for arg in "$@"; do
    case "$arg" in
      aws)   WANT_AWS=true ;;
      azure) WANT_AZURE=true ;;
      oci)   WANT_OCI=true ;;
      gcp)   WANT_GCP=true ;;
      all)   WANT_AWS=true; WANT_AZURE=true; WANT_OCI=true; WANT_GCP=true ;;
      *)     echo "[WARN] Unknown profile '$arg' (expected: aws azure oci gcp all)" ;;
    esac
  done
fi

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

log_step "Updating apt index and base packages"
$SUDO apt-get update -y
for pkg in git curl unzip jq ca-certificates gnupg lsb-release apt-transport-https; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    log_ok "$pkg already installed"
  else
    log_change "Installing $pkg"
    $SUDO apt-get install -y "$pkg"
  fi
done

# --- kubectl (official binary, stable) --------------------------------------
if has_cmd kubectl; then
  log_ok "kubectl already installed ($(kubectl version --client --short 2>/dev/null || echo present))"
else
  log_change "Installing kubectl"
  KUBE_STABLE="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLO "https://dl.k8s.io/release/${KUBE_STABLE}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  $SUDO mv kubectl /usr/local/bin/kubectl
  log_ok "kubectl installed ($KUBE_STABLE)"
fi

# --- Helm (official installer) ------------------------------------------------
if has_cmd helm; then
  log_ok "helm already installed"
else
  log_change "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log_ok "helm installed"
fi

# --- AWS CLI v2 (official installer) ------------------------------------------
if [ "$WANT_AWS" = true ]; then
  if has_cmd aws; then
    log_ok "AWS CLI already installed"
  else
    log_change "Installing AWS CLI v2"
    TMPDIR_AWS="$(mktemp -d)"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPDIR_AWS/awscliv2.zip"
    (cd "$TMPDIR_AWS" && unzip -q awscliv2.zip && $SUDO ./aws/install)
    rm -rf "$TMPDIR_AWS"
    log_ok "AWS CLI installed"
  fi
else
  log_skip "AWS CLI not selected"
fi

# --- Azure CLI (official Microsoft script) ------------------------------------
if [ "$WANT_AZURE" = true ]; then
  if has_cmd az; then
    log_ok "Azure CLI already installed"
  else
    log_change "Installing Azure CLI"
    curl -fsSL https://aka.ms/InstallAzureCLIDeb | $SUDO bash
    log_ok "Azure CLI installed"
  fi
else
  log_skip "Azure CLI not selected"
fi

# --- OCI CLI (official installer, non-interactive defaults) -------------------
if [ "$WANT_OCI" = true ]; then
  if has_cmd oci; then
    log_ok "OCI CLI already installed"
  else
    log_change "Installing OCI CLI"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
    log_ok "OCI CLI installed (run 'oci setup config' manually to configure)"
  fi
else
  log_skip "OCI CLI not selected"
fi

# --- Google Cloud CLI (official apt repository) --------------------------------
if [ "$WANT_GCP" = true ]; then
  if has_cmd gcloud; then
    log_ok "gcloud already installed"
  else
    log_change "Installing Google Cloud CLI"
    $SUDO apt-get install -y apt-transport-https ca-certificates gnupg curl
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | $SUDO tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
    $SUDO apt-get update -y && $SUDO apt-get install -y google-cloud-cli
    log_ok "gcloud installed (run 'gcloud init' manually to configure)"
  fi
else
  log_skip "Google Cloud CLI not selected"
fi

echo ""
echo "Ubuntu guest provisioning complete. No credentials were created or modified."
