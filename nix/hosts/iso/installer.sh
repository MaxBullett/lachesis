#!/usr/bin/env bash
# Guided installer for flake-based deployments. Handles disko, install,
# account password prompts, and cleanup for the selected host.
set -Eeuo pipefail
IFS=$'\n\t'
export LANG=C

readonly REQUIRED=(gum nix jq lsblk curl nmcli nmtui findmnt disko nixos-install nixos-enter)
readonly FLAKE=/iso/nix-config
declare -a DECLARED_DISKS=()
declare -a INSTALL_USERS=()
SELECTED_PLAN=""

format_user_list() {
  local -n list_ref=$1
  local header=$2

  if ((${#list_ref[@]} == 0)); then
    printf '%s:\n  (none)\n' "$header"
    return
  fi

  local user
  printf '%s:\n' "$header"
  for user in "${list_ref[@]}"; do
    printf '  - %s\n' "$user"
  done
}

info(){ local IFS=' '; gum style --foreground "#8AADF4" "🛈 $*"; }
ok(){ local IFS=' '; gum style --foreground "#A6DA95" "✔ $*"; }
warn(){ local IFS=' '; gum style --foreground "#EED49F" "⚠ $*"; }
err(){ local IFS=' '; gum style --foreground "#ED8796" "✖ $*" >&2; }

run_cmd() {
  local label=$1
  shift
  local cmd=("$@")

  info "$label"
  if "${cmd[@]}"; then
    ok "$label"
  else
    err "$label failed"
    exit 1
  fi
}

plan_step() {
  local label=$1
  shift
  local cmd=("$@")

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "dry-run: $label -> $(printf '%q ' "${cmd[@]}")"
    return 0
  fi

  run_cmd "$label" "${cmd[@]}"
}

main() {
  trap 'err "Installer aborted"; exit 1' INT
  trap 'err "Unexpected error"; exit 1' ERR

  check_dependencies
  ensure_root
  choose_mode
  confirm_live_environment
  ensure_network
  load_flake
  select_host
  verify_declared_disks
  prepare_mount_environment
  choose_plan_of_action
  summarize
  confirm_execution
  execute_plan
  finalize_installation
}

check_dependencies() {
  for dep in "${REQUIRED[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      err "Missing dependency: $dep"
      exit 1
    fi
  done
}

ensure_root() {
  if [[ $(id -u) -ne 0 ]]; then
    err "Must run as root"
    exit 1
  fi
}

choose_mode() {
  gum style --border normal --margin "1 0" --padding "1 2" --bold "NixOS Guided Installer"

  local choice
  choice=$(printf "%s\n" "Proceed" "Dry-run" "Abort" | gum choose --header "Mode")
  case "$choice" in
    Abort) info "Exit"; exit 0 ;;
    Dry-run) DRY_RUN=1 ;;
    Proceed) DRY_RUN=0 ;;
  esac

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "Dry-run mode: only printing actions"
  fi
}

confirm_live_environment() {
  if [[ ! -e /iso && -e /run/current-system ]]; then
    if ! gum confirm --default=false "Not running from live installer. Continue?"; then
      exit 1
    fi
  fi
}

ensure_network() {
  until has_network; do
    warn "No network connection"
    if gum confirm "Open nmtui to configure network?"; then
      nmtui
    else
      err "Cannot continue without a network connection"
      exit 1
    fi
  done

  ok "Network OK"
}

has_network() {
  curl -fsI --max-time 5 https://cache.nixos.org >/dev/null 2>&1
}

load_flake() {
  if [[ ! -e "$FLAKE/flake.nix" ]]; then
    err "Missing $FLAKE/flake.nix on the ISO"
    exit 1
  fi

  cd "$FLAKE"
}

select_host() {
  local host_list
  if ! host_list=$(nix eval --json --no-write-lock-file .#nixosConfigurations \
      --apply 'x: builtins.attrNames x' 2>&1 | jq -r '.[]'); then
    err "Failed to evaluate nixosConfigurations"
    exit 1
  fi

  if [[ -z "$host_list" ]]; then
    err "No nixosConfigurations found in flake"
    exit 1
  fi

  if [[ -n ${HOST:-} ]] && grep -qx "$HOST" <<<"$host_list"; then
    SELECTED_HOST=$HOST
  else
    SELECTED_HOST=$(printf "%s\n" "$host_list" | gum choose --header "Select host")
  fi

  if [[ -z "$SELECTED_HOST" ]]; then
    err "No host selected"
    exit 1
  fi

  export FLAKE HOST=$SELECTED_HOST
}

verify_declared_disks() {
  local json
  if ! json=$(nix eval --json --no-write-lock-file \
      ".#nixosConfigurations.${HOST}.config.disko.devices.disk" \
      --apply 'disks: builtins.map (disk: disk.device) (builtins.attrValues disks)' 2>/dev/null); then
    warn "Unable to load disk definitions; skipping disk preflight"
    return
  fi

  if [[ $(jq -r type <<<"$json") != "array" ]]; then
    warn "Disk definitions did not produce a list; skipping disk preflight"
    return
  fi

  DECLARED_DISKS=()
  mapfile -t DECLARED_DISKS < <(jq -r 'map(select(. != null and . != ""))[]' <<<"$json")

  if ((${#DECLARED_DISKS[@]} == 0)); then
    warn "No disks declared in configuration; skipping disk preflight"
    return
  fi

  local missing=()
  for idx in "${!DECLARED_DISKS[@]}"; do
    local device="${DECLARED_DISKS[$idx]}"
    if [[ $device != /* ]]; then
      device="/dev/disk/by-id/$device"
    fi

    DECLARED_DISKS[idx]="$device"
    if [[ ! -b "$device" ]]; then
      missing+=("$device")
    fi
  done

  if ((${#missing[@]} > 0)); then
    err "Missing block devices: ${missing[*]}"
    exit 1
  fi

  ok "Declared disks present"
}

fetch_install_users() {
  INSTALL_USERS=()

  local json
  if ! json=$(nix eval --json --no-write-lock-file \
      ".#nixosConfigurations.${HOST}.config.users.users" \
      --apply 'users: let names = builtins.attrNames users; in builtins.filter (name: let user = builtins.getAttr name users; in (user.isNormalUser or false) || name == "root") names' 2>/dev/null); then
    return 1
  fi

  if [[ $(jq -r type <<<"$json" 2>/dev/null) != "array" ]]; then
    return 1
  fi

  mapfile -t INSTALL_USERS < <(jq -r '.[]' <<<"$json")
  return 0
}

prepare_mount_environment() {
  info "Preparing mount environment"

  local -a mounts=()

  if mountpoint -q /mnt; then
    while IFS= read -r mp; do
      [[ -z "$mp" ]] && continue
      mounts+=("$mp")
    done < <(findmnt --noheadings --output TARGET --submounts /mnt 2>/dev/null || true)
  fi

  local disk
  for disk in "${DECLARED_DISKS[@]}"; do
    while IFS= read -r mp; do
      [[ -z "$mp" || "$mp" == "[SWAP]" ]] && continue
      mounts+=("$mp")
    done < <(lsblk -rno MOUNTPOINT "$disk" 2>/dev/null || true)
  done

  if ((${#mounts[@]} > 0)); then
    declare -A seen=()
    local target
    for target in "${mounts[@]}"; do
      [[ -z "$target" ]] && continue
      if [[ -z ${seen[$target]+_} ]]; then
        seen[$target]=1

        if [[ "$target" == "/" ]]; then
          err "Refusing to unmount /. Please run from a live environment."
          exit 1
        fi

        if [[ ${DRY_RUN:-0} -eq 1 ]]; then
          warn "dry-run: would unmount --recursive $target"
        else
          if mountpoint -q "$target"; then
            warn "Unmounting $target"
            if ! umount --recursive "$target" 2>/dev/null; then
              if ! umount "$target"; then
                err "Failed to unmount $target"
                exit 1
              fi
            fi
          fi
        fi
      fi
    done
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "dry-run: would ensure /mnt exists and is empty"
  else
    mkdir -p /mnt
    if [[ -n $(ls -A /mnt 2>/dev/null) ]]; then
      warn "/mnt not empty; cleaning up"
      find /mnt -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
  fi

  ok "/mnt ready"
}

choose_plan_of_action() {
  local -a options=(
    "full-install::Full install - wipe disks, run disko, mount, build, and switch"
    "format-only::Format & mount - run disko and mount volumes, skip OS build"
    "mount-only::Mount existing filesystem - skip formatting and install"
    "abort::Abort"
  )

  local preset=${PLAN:-}
  if [[ -n $preset ]]; then
    case $preset in
      full-install|format-only|mount-only) SELECTED_PLAN=$preset ;;
      abort) info "Abort requested via PLAN variable"; exit 0 ;;
      *) warn "Unknown PLAN '$preset'; falling back to interactive selection";;
    esac
  fi

  if [[ -z $SELECTED_PLAN ]]; then
    local formatted=()
    local entry
    for entry in "${options[@]}"; do
      formatted+=("${entry#*::}")
    done

    local choice
    choice=$(printf "%s\n" "${formatted[@]}" | gum choose --header "Select installer plan") || {
      err "Plan selection cancelled"
      exit 1
    }

    [[ -z $choice ]] && {
      err "No plan selected"
      exit 1
    }

    case "$choice" in
      "Full install - wipe disks, run disko, mount, build, and switch") SELECTED_PLAN=full-install ;;
      "Format & mount - run disko and mount volumes, skip OS build") SELECTED_PLAN=format-only ;;
      "Mount existing filesystem - skip formatting and install") SELECTED_PLAN=mount-only ;;
      "Abort") info "Exit"; exit 0 ;;
      *) err "Unknown selection"; exit 1 ;;
    esac
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "dry-run: plan selected = $SELECTED_PLAN"
  else
    ok "Plan selected: $SELECTED_PLAN"
  fi

  export PLAN=$SELECTED_PLAN
}

execute_plan() {
  case $SELECTED_PLAN in
    full-install)
      plan_step "Wipe, format, and mount target filesystems" disko --mode destroy,format,mount --flake "${FLAKE}#${HOST}"
      plan_step "Install NixOS" nixos-install --root /mnt --flake "${FLAKE}#${HOST}" --no-root-password
      ;;
    format-only)
      plan_step "Wipe, format, and mount target filesystems" disko --mode destroy,format,mount --flake "${FLAKE}#${HOST}"
      ;;
    mount-only)
      plan_step "Mount target filesystems" disko --mode mount --flake "${FLAKE}#${HOST}"
      ;;
    *)
      err "Unknown plan '$SELECTED_PLAN'"
      exit 1
      ;;
  esac
}

finalize_installation() {
  case $SELECTED_PLAN in
    full-install)
      if ((${#INSTALL_USERS[@]} == 0)); then
        if ! fetch_install_users; then
          warn "Unable to determine users for password setup; skipping automatic password prompts"
        fi
      fi

      if ((${#INSTALL_USERS[@]} > 0)); then
        local summary
        summary=$(format_user_list INSTALL_USERS "Setting passwords for")
        info "$summary"
        local user
        for user in "${INSTALL_USERS[@]}"; do
          plan_step "Set password for ${user}" nixos-enter --root /mnt -- passwd "$user"
        done
      else
        warn "No users discovered for password setup"
      fi

      plan_step "Unmount target filesystems" disko --mode unmount --flake "${FLAKE}#${HOST}"

      if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        warn "dry-run: would prompt to reboot"
      else
        if gum confirm --default=true "Reboot into installed system now?"; then
          info "Rebooting into installed system"
          systemctl reboot
        else
          info "Reboot skipped; system remains mounted at /mnt"
        fi
      fi
      ;;
    format-only)
      warn "Volumes remain mounted at /mnt for manual steps; run 'disko --mode unmount --flake \"${FLAKE}#${HOST}\"' when finished"
      ;;
    mount-only)
      warn "Mount-only plan selected; no automatic unmount performed"
      ;;
    *)
      warn "Skipping finalize step for plan '$SELECTED_PLAN'"
      ;;
  esac
}

summarize() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "dry-run: would use host=$HOST from flake=$FLAKE"
  else
    ok "Using host=$HOST from flake=$FLAKE"
  fi

  if ((${#DECLARED_DISKS[@]} > 0)); then
    info "Target disks: ${DECLARED_DISKS[*]}"
  fi

  if [[ -n $SELECTED_PLAN ]]; then
    info "Selected plan: $SELECTED_PLAN"
  fi

  if [[ $SELECTED_PLAN == "full-install" ]]; then
    if fetch_install_users; then
      if ((${#INSTALL_USERS[@]} > 0)); then
        local summary
        summary=$(format_user_list INSTALL_USERS "Users queued for password setup")
        info "$summary"
      else
        warn "No normal users found for password setup"
      fi
    else
      warn "Unable to evaluate users; password setup may need manual handling"
    fi

    info "Installer will prompt for passwords, unmount, then ask before rebooting"
  fi
}

confirm_execution() {
  if [[ $SELECTED_PLAN == "mount-only" ]]; then
    return
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    warn "dry-run: skipping confirmation prompt"
    return
  fi

  if ! gum confirm --default=true "Proceed with plan '$SELECTED_PLAN'?"; then
    info "Install aborted at confirmation step"
    exit 0
  fi
}

main "$@"
