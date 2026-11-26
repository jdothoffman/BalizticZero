#!/usr/bin/env bash
# Deploys the Baliztic Zero advisor API (api/) to an Azure Linux VM.
#
#   deploy/deploy.sh check    Read-only: Azure login, VM, SSH, Go toolchain, what is already set up.
#   deploy/deploy.sh set-key  Prompt for the Anthropic API key and store it on the VM, root-only.
#   deploy/deploy.sh setup    One time: DNS name and HTTPS port in Azure, Caddy, service user, secrets.
#   deploy/deploy.sh deploy   Test, build, upload, restart, health check; rolls back if the new build fails.
#   deploy/deploy.sh status   Service state and the public health check.
#   deploy/deploy.sh logs     Follow the service log.
#
# Settings (environment variables, defaults in brackets):
#   AZ_RG [RG-TELEMETRY-LAB]  AZ_VM [vm-telemetry-lab]  SSH_USER [azureuser]
#   DNS_LABEL [baliztic-api]  -> https://<DNS_LABEL>.<region>.cloudapp.azure.com
#   GO [go]                   Go toolchain used to cross-compile.
#   ANTHROPIC_API_KEY         Read by `setup` only when the server has no secrets yet. Prompted for if unset.
#   AI_MODEL                  Optional, written by `setup`. The API falls back to its own default when empty.
#
# Secrets never go on a command line or into git: they travel over SSH stdin into
# /etc/baliztic-api/env (root, mode 600) on the server.

set -euo pipefail

AZ_RG="${AZ_RG:-RG-TELEMETRY-LAB}"
AZ_VM="${AZ_VM:-vm-telemetry-lab}"
SSH_USER="${SSH_USER:-azureuser}"
DNS_LABEL="${DNS_LABEL:-baliztic-api}"
GO="${GO:-go}"

NSG_RULE="allow-https-baliztic-api"
NSG_PRIORITY=1010
REMOTE_DIR=/opt/baliztic-api
REMOTE_ENV=/etc/baliztic-api/env
SERVICE=baliztic-api

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="$ROOT/deploy"
API_DIR="$ROOT/api"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Azure lookups -------------------------------------------------------------

az_ready() {
    command -v az >/dev/null || die "Azure CLI not found. Install it and run 'az login'."
    az account show >/dev/null 2>&1 || die "Not logged in to Azure. Run 'az login'."
}

vm_nic_id() {
    az vm show -g "$AZ_RG" -n "$AZ_VM" --query "networkProfile.networkInterfaces[0].id" -o tsv
}

public_ip_id() {
    az network nic show --ids "$(vm_nic_id)" --query "ipConfigurations[0].publicIPAddress.id" -o tsv
}

nsg_id() {
    az network nic show --ids "$(vm_nic_id)" --query "networkSecurityGroup.id" -o tsv
}

vm_ip() {
    az network public-ip show --ids "$(public_ip_id)" --query "ipAddress" -o tsv
}

vm_fqdn() {
    az network public-ip show --ids "$(public_ip_id)" --query "dnsSettings.fqdn" -o tsv
}

# --- SSH -----------------------------------------------------------------------

HOST=""
ssh_target() {
    if [[ -z "$HOST" ]]; then
        HOST="$(vm_ip)"
        [[ -n "$HOST" ]] || die "VM $AZ_VM has no public IP."
    fi
    printf '%s@%s' "$SSH_USER" "$HOST"
}

remote() {
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "$(ssh_target)" "$@"
}

upload() {
    scp -q -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new "$1" "$(ssh_target):$2"
}

# --- Build ---------------------------------------------------------------------

# Picks a Go that runs here. An Intel-only Go earlier on PATH fails on Apple silicon without
# Rosetta, so fall back to Homebrew's when plain `go` does not start.
resolve_go() {
    "$GO" version >/dev/null 2>&1 && return 0
    local candidate
    for candidate in /opt/homebrew/bin/go /usr/local/bin/go; do
        if [[ "$GO" == go && -x "$candidate" ]] && "$candidate" version >/dev/null 2>&1; then
            GO="$candidate"
            return 0
        fi
    done
    return 1
}

go_ready() {
    resolve_go || die "'$GO version' failed. Install Go for this Mac (brew install go) or set GO=/path/to/go."
}

remote_goarch() {
    case "$(remote uname -m)" in
        x86_64) echo amd64 ;;
        aarch64 | arm64) echo arm64 ;;
        *) die "Unsupported server architecture: $(remote uname -m)" ;;
    esac
}

build() {
    local out="$1" arch="$2"
    say "Testing the API"
    (cd "$API_DIR" && "$GO" vet ./... && "$GO" test -count=1 ./...)
    say "Building for linux/$arch"
    (cd "$API_DIR" && GOOS=linux GOARCH="$arch" CGO_ENABLED=0 "$GO" build -trimpath -ldflags="-s -w" -o "$out" ./cmd/baliztic-api)
}

# --- Commands ------------------------------------------------------------------

cmd_check() {
    az_ready
    say "Azure subscription: $(az account show --query name -o tsv)"
    az vm show -g "$AZ_RG" -n "$AZ_VM" --query "name" -o tsv >/dev/null || die "VM $AZ_VM not found in $AZ_RG."
    say "VM: $AZ_VM ($(az vm show -g "$AZ_RG" -n "$AZ_VM" -d --query powerState -o tsv)) at $(vm_ip)"
    local fqdn
    fqdn="$(vm_fqdn)"
    say "DNS name: ${fqdn:-not set (setup will add $DNS_LABEL)}"
    if az network nsg rule show --ids "$(nsg_id)/securityRules/$NSG_RULE" >/dev/null 2>&1; then
        say "Port 443: open (rule $NSG_RULE)"
    else
        say "Port 443: closed (setup will open it)"
    fi
    remote true || die "SSH to $(ssh_target) failed. Check that your key is on the VM."
    say "SSH: ok ($(remote uname -m))"
    remote sudo -n true || die "sudo on the VM needs a password; the script needs passwordless sudo."
    say "Caddy: $(remote 'command -v caddy >/dev/null && caddy version | cut -d" " -f1 || echo not installed')"
    say "Service: $(remote "systemctl is-active $SERVICE 2>/dev/null || true")"
    say "Secrets: $(remote "sudo test -f $REMOTE_ENV && echo present || echo missing")"
    if resolve_go; then
        say "Go: $("$GO" version)"
    else
        warn "'$GO version' failed. Install Go for this Mac (brew install go) or set GO=/path/to/go before deploying."
    fi
}

cmd_setup() {
    az_ready
    local location ip_id nsg fqdn
    location="$(az vm show -g "$AZ_RG" -n "$AZ_VM" --query location -o tsv)"
    ip_id="$(public_ip_id)"
    nsg="$(nsg_id)"
    [[ -n "$ip_id" ]] || die "VM $AZ_VM has no public IP."
    [[ -n "$nsg" ]] || die "VM $AZ_VM has no network security group on its NIC."

    fqdn="$(vm_fqdn)"
    if [[ -z "$fqdn" ]]; then
        say "Adding DNS name $DNS_LABEL.$location.cloudapp.azure.com"
        az network public-ip update --ids "$ip_id" --dns-name "$DNS_LABEL" -o none
        fqdn="$(vm_fqdn)"
    fi
    say "DNS name: $fqdn"

    if ! az network nsg rule show --ids "$nsg/securityRules/$NSG_RULE" >/dev/null 2>&1; then
        say "Opening port 443 in ${nsg##*/}"
        az network nsg rule create -g "$AZ_RG" --nsg-name "${nsg##*/}" -n "$NSG_RULE" \
            --priority "$NSG_PRIORITY" --direction Inbound --access Allow --protocol Tcp \
            --source-address-prefixes Internet --destination-port-ranges 443 -o none
    fi

    remote true || die "SSH to $(ssh_target) failed."
    remote sudo -n true || die "sudo on the VM needs a password."

    say "Installing Caddy and creating the service user"
    remote 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
if ! command -v caddy >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get install -y -q debian-keyring debian-archive-keyring apt-transport-https curl gnupg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -q
    apt-get install -y -q caddy
fi
id baliztic >/dev/null 2>&1 || useradd --system --home-dir /opt/baliztic-api --shell /usr/sbin/nologin baliztic
install -d -o root -g root -m 755 /opt/baliztic-api
install -d -o root -g root -m 700 /etc/baliztic-api
REMOTE

    if remote "sudo -n grep -q '^ANTHROPIC_API_KEY=.' $REMOTE_ENV 2>/dev/null"; then
        say "API key already on the server; leaving it as it is (deploy/deploy.sh set-key replaces it)"
    else
        cmd_set_key
    fi

    sync_config "$fqdn"
    say "Setup done. Next: deploy/deploy.sh deploy"
}

# Runs on the VM as root. Reads the API key (and optional model) from stdin, so neither
# ever appears in a command line. Replaces only those lines in the env file, adds the
# listener address, provider, and a phone token if the file lacks them, and prints
# NEW_DEV_TOKEN=<token> when it had to create one.
SET_KEY_REMOTE='
set -euo pipefail
umask 077
dir=/etc/baliztic-api
env="$dir/env"
install -d -o root -g root -m 700 "$dir"
IFS= read -r key
IFS= read -r model || true
[[ -n "$key" ]] || { echo "no key received" >&2; exit 1; }
tmp="$(mktemp "$dir/.env.XXXXXX")"
if [[ -f "$env" ]]; then
    grep -v -E "^(ANTHROPIC_API_KEY|AI_MODEL)=" "$env" > "$tmp" || true
fi
grep -q "^ADDR=" "$tmp" || printf "ADDR=127.0.0.1:8080\n" >> "$tmp"
grep -q "^AI_PROVIDER=" "$tmp" || printf "AI_PROVIDER=claude\n" >> "$tmp"
if ! grep -q "^DEV_TOKEN=." "$tmp"; then
    token="$(openssl rand -hex 32)"
    printf "DEV_TOKEN=%s\n" "$token" >> "$tmp"
    printf "NEW_DEV_TOKEN=%s\n" "$token"
fi
printf "ANTHROPIC_API_KEY=%s\n" "$key" >> "$tmp"
[[ -n "$model" ]] && printf "AI_MODEL=%s\n" "$model" >> "$tmp"
chown root:root "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$env"
if systemctl cat baliztic-api >/dev/null 2>&1; then
    systemctl restart baliztic-api
    echo "RESTARTED=yes"
fi
'

cmd_set_key() {
    az_ready
    remote true || die "SSH to $(ssh_target) failed."
    remote sudo -n true || die "sudo on the VM needs a password."

    local key="${ANTHROPIC_API_KEY:-}"
    if [[ -z "$key" ]]; then
        [[ -t 0 ]] || die "Set ANTHROPIC_API_KEY or run this in a terminal so it can prompt."
        read -r -s -p "Paste the Anthropic API key (input hidden), then press Return: " key
        echo
    fi
    key="${key//[[:space:]]/}"
    [[ "$key" == sk-ant-* ]] || die "That does not look like an Anthropic API key (it should start with sk-ant-). Nothing was changed."

    say "Writing the key to $REMOTE_ENV on $AZ_VM"
    local output token
    output="$(printf '%s\n%s\n' "$key" "${AI_MODEL:-}" | remote "sudo -n bash -c $(printf '%q' "$SET_KEY_REMOTE")")"
    key=""

    say "Key saved (root-only, mode 600)."
    if grep -q '^RESTARTED=yes' <<<"$output"; then
        say "Restarted $SERVICE so it uses the new key."
    fi
    token="$(sed -n 's/^NEW_DEV_TOKEN=//p' <<<"$output")"
    if [[ -n "$token" ]]; then
        cat <<EOF

  New phone token (DEV_TOKEN). Shown once; it is stored only on the server.
  The app sends it as:  Authorization: Bearer <token>

      $token

EOF
    fi
}

sync_config() {
    local fqdn="$1" tmp
    tmp="$(mktemp -d)"
    sed "s/__FQDN__/$fqdn/" "$DEPLOY_DIR/Caddyfile.tmpl" > "$tmp/Caddyfile"
    upload "$tmp/Caddyfile" /tmp/baliztic-Caddyfile
    upload "$DEPLOY_DIR/baliztic-api.service" /tmp/baliztic-api.service
    rm -rf "$tmp"
    say "Installing the Caddyfile and the service unit"
    remote 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
caddy validate --adapter caddyfile --config /tmp/baliztic-Caddyfile
install -o root -g root -m 644 /tmp/baliztic-Caddyfile /etc/caddy/Caddyfile
install -o root -g root -m 644 /tmp/baliztic-api.service /etc/systemd/system/baliztic-api.service
rm -f /tmp/baliztic-Caddyfile /tmp/baliztic-api.service
systemctl daemon-reload
systemctl enable --now caddy >/dev/null
systemctl reload caddy
systemctl enable baliztic-api >/dev/null
REMOTE
}

cmd_deploy() {
    az_ready
    go_ready
    local fqdn arch tmp
    fqdn="$(vm_fqdn)"
    [[ -n "$fqdn" ]] || die "No DNS name on the VM yet. Run deploy/deploy.sh setup first."
    remote "sudo -n test -f $REMOTE_ENV" || die "No secrets on the server yet. Run deploy/deploy.sh setup first."

    if [[ -n "$(git -C "$ROOT" status --porcelain -- api)" ]]; then
        warn "api/ has uncommitted changes; deploying the working tree as it is."
    fi

    arch="$(remote_goarch)"
    tmp="$(mktemp -d)"
    BUILD_DIR="$tmp"
    trap 'rm -rf "${BUILD_DIR:-}"' EXIT
    build "$tmp/baliztic-api" "$arch"

    sync_config "$fqdn"

    say "Uploading and restarting"
    upload "$tmp/baliztic-api" /tmp/baliztic-api.new
    if ! remote 'sudo -n bash -s' <<'REMOTE'; then
set -euo pipefail
dir=/opt/baliztic-api
install -o root -g root -m 755 /tmp/baliztic-api.new "$dir/baliztic-api.next"
rm -f /tmp/baliztic-api.new
[[ -f "$dir/baliztic-api" ]] && cp -p "$dir/baliztic-api" "$dir/baliztic-api.prev"
mv -f "$dir/baliztic-api.next" "$dir/baliztic-api"
systemctl restart baliztic-api

healthy=no
for _ in $(seq 1 15); do
    if curl -fsS --max-time 2 http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
        healthy=yes
        break
    fi
    sleep 1
done
if [[ "$healthy" == yes ]]; then
    exit 0
fi

echo "New build did not pass the health check. Last log lines:" >&2
journalctl -u baliztic-api -n 20 --no-pager >&2 || true
if [[ -f "$dir/baliztic-api.prev" ]]; then
    echo "Rolling back to the previous build." >&2
    mv -f "$dir/baliztic-api.prev" "$dir/baliztic-api"
    systemctl restart baliztic-api
fi
exit 1
REMOTE
        die "Deploy failed; the server is back on the previous build if there was one."
    fi

    say "Checking https://$fqdn/healthz"
    local attempt
    for attempt in 1 2 3 4 5 6; do
        if curl -fsS --max-time 10 "https://$fqdn/healthz"; then
            echo
            say "Deployed. API base URL: https://$fqdn"
            return 0
        fi
        sleep 5
    done
    die "The service is healthy on the VM, but https://$fqdn/healthz did not answer. The first certificate can take a minute; try deploy/deploy.sh status."
}

cmd_status() {
    az_ready
    local fqdn
    fqdn="$(vm_fqdn)"
    remote "systemctl --no-pager --lines=5 status $SERVICE caddy" || true
    if [[ -n "$fqdn" ]]; then
        say "https://$fqdn/healthz"
        curl -sS --max-time 10 "https://$fqdn/healthz" || true
        echo
    fi
}

cmd_logs() {
    az_ready
    ssh -t -o ConnectTimeout=15 "$(ssh_target)" "sudo journalctl -u $SERVICE -u caddy -f -n 50"
}

case "${1:-}" in
    check) cmd_check ;;
    setup) cmd_setup ;;
    set-key) cmd_set_key ;;
    deploy) cmd_deploy ;;
    status) cmd_status ;;
    logs) cmd_logs ;;
    *)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
