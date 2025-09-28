#!/usr/bin/env bash
set -Eeuo pipefail

# NixOS Guided Installer
# Overview:
#   - Interactive by default using gum; non-interactive via flags (e.g., --yes).
#   - Installs a chosen flake host with disko-install on a selected disk.
#   - Logs to /tmp/nixos-installer.log (configurable with --log).
# Structure:
#   1) CLI/Defaults
#   2) Logging + helpers
#   3) Preconditions (root, deps)
#   4) Network check
#   5) Host selection + flake check
#   6) Disko file resolution
#   7) Disk selection + mount hygiene
#   8) Preview / Install
#   9) Post-install password setup
# Usage:
#   - Preview (no changes): installer.sh --dry-run
#   - Non-interactive install: installer.sh --host HOST --disk /dev/sdX --yes --set-passwords --include-root
#   - Custom repo path: installer.sh --repo /path/to/nix-config
# Notes:
#   - gum is a hard dependency.
#   - This script wipes the selected disk.

################################################################################
# Defaults
################################################################################
REPO_DIR=${REPO_DIR:-/iso/nix-config}
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
NO_NETWORK=${NO_NETWORK:-0}
NO_FLAKE_CHECK=${NO_FLAKE_CHECK:-0}
LOG_FILE=${LOG_FILE:-/tmp/nixos-installer.log}
SELECTED_HOST=""
SELECTED_DISK=""
DISKO_FILE=""
SET_PASSWORDS=0
INCLUDE_ROOT=0
ALL_USERS=0
ASK_PER_USER=1

################################################################################
# CLI
################################################################################
usage() {
  cat <<EOF
Usage: installer.sh [options]

Options:
  --repo DIR            Path to repo (default: /iso/nix-config or $REPO_DIR)
  --host NAME           Host name from flake (nixosConfigurations.<NAME>)
  --disk DEV            Target disk device (e.g., /dev/nvme0n1)
  --disko FILE          Path to disko config (default: nix/hosts/<host>/disk-configuration.nix)
  -n, --dry-run         Preview actions; do not modify disks
  -y, --yes             Assume yes for all prompts (non-interactive)
  --force               Force unmount of /mnt if busy
  --no-network          Skip network checks
  --no-flake-check      Skip 'nix flake check'
  --set-passwords       Enable post-install password setup
  --no-passwords        Disable password setup prompt
  --include-root        Include root in password setup
  --all-users           Select all normal users automatically
  --no-ask-per-user     Do not ask per-user; set for selected set silently
  --log FILE            Write detailed logs to FILE (default: /tmp/nixos-installer.log)
  -h, --help            Show this help and exit
EOF
}

FORCE_UNMOUNT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) shift; REPO_DIR=${1:-$REPO_DIR} ;;
    --host) shift; SELECTED_HOST=${1:-} ;;
    --disk) shift; SELECTED_DISK=${1:-} ;;
    --disko) shift; DISKO_FILE=${1:-} ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    --force) FORCE_UNMOUNT=1 ;;
    --no-network) NO_NETWORK=1 ;;
    --no-flake-check) NO_FLAKE_CHECK=1 ;;
    --set-passwords) SET_PASSWORDS=1 ;;
    --no-passwords) SET_PASSWORDS=0 ;;
    --include-root) INCLUDE_ROOT=1 ;;
    --all-users) ALL_USERS=1 ;;
    --no-ask-per-user) ASK_PER_USER=0 ;;
    --log) shift; LOG_FILE=${1:-$LOG_FILE} ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

################################################################################
# Logging & helpers
################################################################################
# Ensure log directory exists; ignore errors (e.g., when using /tmp)
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Try to create/touch the requested log file; if that fails, fall back to mktemp
if ! touch "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="$(mktemp -t nixos-installer.XXXXXX.log)"
fi

# Best-effort tighten perms
chmod 600 "$LOG_FILE" 2>/dev/null || true

log()  { printf "%s %s\n" "[$(date +'%F %T')]" "$*" | tee -a "$LOG_FILE" >&2; }
fail() { log "ERROR: $*"; exit 1; }

confirm() {
  local msg="$1"
  if [ "$ASSUME_YES" = 1 ]; then return 0; fi
  gum confirm "$msg"
}

on_error() {
  local exit_code=$?
  log "Installer failed with exit code $exit_code"
  log "See log: $LOG_FILE"
}
trap on_error ERR

require() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"
}

################################################################################
# Preconditions
################################################################################
# Only require root for destructive mode
if [ "$DRY_RUN" != 1 ] && [ "$(id -u)" -ne 0 ]; then
  fail "Must run this script as root (or use sudo). Tip: preview with --dry-run."
fi

# Dependencies
for dep in gum jq nix disko nmcli lsblk parted nixos-enter; do require "$dep"; done

cd "$REPO_DIR" || fail "Cannot cd into repo: $REPO_DIR"

# Friendly header
if [ "$DRY_RUN" = 1 ]; then
  log "NixOS Guided Installer — DRY RUN (no changes will be made)"
else
  log "NixOS Guided Installer — WARNING: This will DESTROY data on the selected disk"
fi

if [ "$ASSUME_YES" != 1 ]; then
  confirm "Proceed?" || exit 1
fi

################################################################################
# Network
################################################################################
ensure_network() {
  if [ "$NO_NETWORK" = 1 ]; then return 0; fi
  if ping -c1 -W1 cache.nixos.org >/dev/null 2>&1; then
    return 0
  fi
  log "Network not detected (or cache unreachable)."
  if gum confirm "Open nmtui to connect to Wi‑Fi?"; then nmtui || true; fi
  # quick nmcli attempt
  local IFACE SSID PASS
  IFACE=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi" {print $1; exit}')
  if [ -n "$IFACE" ]; then
    if [ "$ASSUME_YES" = 1 ]; then
      log "Skipping interactive Wi‑Fi in non-interactive mode."
    else
      SSID=$(gum input --placeholder "SSID" || true)
      if [ -n "$SSID" ]; then
        PASS=$(gum input --password --placeholder "Wi‑Fi password" || true)
        nmcli dev wifi connect "$SSID" password "$PASS" ifname "$IFACE" || true
      fi
    fi
  fi
}
ensure_network

################################################################################
# Flake and host selection
################################################################################
list_hosts() {
  nix eval --json --apply builtins.attrNames .#nixosConfigurations 2>/dev/null | jq -r '.[]'
}

select_host() {
  if [ -n "$SELECTED_HOST" ]; then echo "$SELECTED_HOST"; return; fi
  mapfile -t HOSTS < <(list_hosts)
  [ ${#HOSTS[@]} -gt 0 ] || fail "No nixosConfigurations found in flake."
  printf "%s\n" "${HOSTS[@]}" | gum choose --limit 1 --header "Select target host"
}

HOST=$(select_host)
[ -n "$HOST" ] || fail "No host selected"

if [ "$NO_FLAKE_CHECK" != 1 ]; then
  log "Checking flake... (use --no-flake-check to skip)"
  nix flake check --quiet || log "flake check reported issues; continuing"
fi

################################################################################
# Disko file resolution
################################################################################
resolve_disko_file() {
  if [ -n "$DISKO_FILE" ]; then
    [ -f "$DISKO_FILE" ] || fail "Disko file not found: $DISKO_FILE"
    echo "$DISKO_FILE"; return
  fi
  local df="nix/hosts/${HOST}/disk-configuration.nix"
  if [ -f "$df" ]; then echo "$df"; return; fi
  if [ "$ASSUME_YES" = 1 ]; then
    fail "No default disko file found for host and non-interactive mode enabled"
  fi
  log "No disk-configuration.nix at $df"
  local ALT
  ALT=$(gum input --placeholder "Path to disko config (e.g., nix/hosts/laptop/disk-configuration.nix)" || true)
  if [ -z "$ALT" ] || [ ! -f "$ALT" ]; then
    fail "Disko config not provided or not found"
  fi
  echo "$ALT"
}

DISKO_FILE=$(resolve_disko_file)
log "Using disko file: $DISKO_FILE"

################################################################################
# Disk selection & checks
################################################################################
choose_disk() {
  if [ -n "$SELECTED_DISK" ]; then echo "$SELECTED_DISK"; return; fi
  mapfile -t DISKS < <(lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF=="disk" {print $1"  ["$2"]  "$3}')
  [ ${#DISKS[@]} -gt 0 ] || fail "No disks detected"
  local SEL
  SEL=$(printf "%s\n" "${DISKS[@]}" | gum choose --limit 1 --header "Select target disk (WILL BE WIPED)")
  echo "$SEL" | awk '{print $1}'
}

DISK=$(choose_disk)
[ -n "$DISK" ] || fail "No disk selected"
export DISK  # for disko configs using env.DISK

# Sanity: ensure target looks like a disk
[ -b "$DISK" ] || fail "Not a block device: $DISK"
lsblk -no TYPE "$DISK" | grep -qx "disk" || fail "$DISK is not a disk device"

################################################################################
# Mount hygiene
################################################################################
show_mnt_mounts() {
  log "Current mounts under /mnt:"; mount | grep "/mnt" || true
}

umount_all_mnt() {
  if mount | grep -q "^.* on /mnt"; then
    show_mnt_mounts
    if [ "$ASSUME_YES" = 1 ] || confirm "Unmount everything under /mnt now?"; then
      # Try lazy then force if requested
      umount -R /mnt 2>/dev/null || true
      if mount | grep -q "^.* on /mnt"; then
        if [ "$FORCE_UNMOUNT" = 1 ]; then
          log "Forcing lazy unmount of /mnt"
          umount -Rl /mnt || true
        else
          fail "/mnt still mounted; retry with --force or unmount manually"
        fi
      fi
    else
      fail "Cannot continue with /mnt busy"
    fi
  fi
}

show_mnt_mounts
umount_all_mnt

################################################################################
# Execute steps
################################################################################
preview() {
  log "[DRY-RUN] Would WIPE and partition $DISK using $DISKO_FILE"
  gum spin --title "Previewing Disko plan (no changes)..." -- \
      disko --dry-run --mode zap_create_mount "$DISKO_FILE" | tee -a "$LOG_FILE"
  log "[DRY-RUN] Would run: disko-install --disko $DISKO_FILE --flake .#$HOST --yes"
}

run_install() {
  log "About to WIPE and partition $DISK using $DISKO_FILE"
  if [ "$ASSUME_YES" != 1 ]; then
    confirm "I understand this is destructive. Continue?" || exit 1
  fi
  gum spin --title "Partitioning, mounting and installing ($HOST) with disko-install..." -- \
      disko-install --disko "$DISKO_FILE" --flake ".#$HOST" --yes | tee -a "$LOG_FILE"
}

################################################################################
# Post-install password setup (dynamic, no hard-coded names)
################################################################################
get_normal_users() {
  # List users with UID >= 1000 (exclude nobody), login shell not nologin/false
  if [ ! -f /mnt/etc/passwd ]; then
    log "No /mnt/etc/passwd found; skipping user discovery"
    return 0
  fi
  awk -F: '($3 >= 1000 && $1 != "nobody" && $7 !~ /(nologin|false)$/) {print $1}' /mnt/etc/passwd
}

choose_users() {
  # Args: list of users on stdin; outputs selected users (newline separated)
  local users; mapfile -t users
  if [ ${#users[@]} -eq 0 ]; then return 0; fi
  if [ "$ALL_USERS" = 1 ]; then
    printf "%s\n" "${users[@]}"
    return 0
  fi
  if [ "$ASSUME_YES" = 1 ]; then
    # Non-interactive: default to all
    printf "%s\n" "${users[@]}"
    return 0
  fi
  printf "%s\n" "${users[@]}" | gum choose --no-limit --header "Select users to set passwords for"
}

prompt_secret() {
  # Prints the confirmed secret to stdout; returns non-zero on abort
  local user="$1" p1 p2
  while true; do
    if command -v gum >/dev/null 2>&1; then
      p1=$(gum input --password --placeholder "Password for $user" || true)
      p2=$(gum input --password --placeholder "Confirm password for $user" || true)
    else
      read -r -s -p "Enter password for $user: " p1; echo
      read -r -s -p "Confirm password for $user: " p2; echo
    fi
    if [ -z "$p1" ]; then
      if [ "$ASSUME_YES" = 1 ]; then return 1; fi
      if confirm "Empty password for $user?"; then break; else continue; fi
    fi
    if [ "$p1" = "$p2" ]; then
      printf "%s" "$p1"
      return 0
    fi
    log "Passwords do not match. Please try again."
  done
  printf "%s" "$p1"
}

set_password_for_user() {
  local user="$1" pass="$2"
  # Use nixos-enter to ensure proper environment; avoid logging the secret
  # shellcheck disable=SC2016
  nixos-enter --root /mnt -- sh -c 'umask 077; read -r line; echo "$line" | chpasswd' <<EOF
${user}:${pass}
EOF
}

maybe_run_password_setup() {
  # Decide if we should run password setup
  if [ "$DRY_RUN" = 1 ]; then return 0; fi
  # If explicitly disabled
  if [ "$SET_PASSWORDS" = 0 ] && [ "$ASSUME_YES" = 1 ]; then return 0; fi
  # In interactive mode, ask unless explicitly enabled
  if [ "$SET_PASSWORDS" != 1 ] && [ "$ASSUME_YES" != 1 ]; then
    if ! confirm "Set user passwords now?"; then return 0; fi
  fi

  # Build selection list
  local users sel users_arr
  sel=()
  if [ "$INCLUDE_ROOT" = 1 ]; then sel+=(root); fi

  mapfile -t users < <(get_normal_users)
  if [ ${#users[@]} -gt 0 ]; then
    mapfile -t users_arr < <(printf "%s\n" "${users[@]}" | choose_users)
    # If choose_users printed nothing (e.g., cancel), default to all in non-interactive
    if [ ${#users_arr[@]} -eq 0 ] && [ "$ASSUME_YES" = 1 ]; then users_arr=("${users[@]}"); fi
    sel+=("${users_arr[@]}")
  fi

  # Deduplicate selection
  if [ ${#sel[@]} -gt 0 ]; then
    mapfile -t sel < <(printf "%s\n" "${sel[@]}" | awk '!x[$0]++')
  fi

  if [ ${#sel[@]} -eq 0 ]; then
    log "No users selected for password setup; skipping"
    return 0
  fi

  log "Setting passwords for: ${sel[*]}"
  local u pw
  for u in "${sel[@]}"; do
    if [ "$ASK_PER_USER" = 1 ] && [ "$ASSUME_YES" != 1 ]; then
      if ! confirm "Set password for $u?"; then continue; fi
    fi
    pw=$(prompt_secret "$u") || { log "Skipped $u"; continue; }
    set_password_for_user "$u" "$pw"
    # Wipe variable asap
    pw=""
    log "Password set for $u"
  done
}

################################################################################
# Main
################################################################################
if [ "$DRY_RUN" = 1 ]; then
  preview
  log "Preview complete."
else
  run_install
  maybe_run_password_setup
  log "Installation complete. You can now reboot into your new system. Run: reboot"
fi
