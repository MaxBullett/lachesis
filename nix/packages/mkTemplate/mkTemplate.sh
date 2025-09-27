#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (so the command works from subdirectories too)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

TEMPLATES_DIR="nix/templates"

err() { echo "Error: $*" >&2; }
die() { err "$@"; exit 1; }

usage() {
  cat <<EOF
Usage:
  mkTemplate list
  mkTemplate <template> <name> [--dry-run] [--force]

Examples:
  mkTemplate list
  mkTemplate nixosModule bluetooth

Notes:
- Reads templates from $TEMPLATES_DIR
- Replaces __NAME__ in file contents (and optionally in file/dir names for directory templates)
EOF
}

list_templates() {
  [[ -d "$TEMPLATES_DIR" ]] || die "Templates dir not found: $TEMPLATES_DIR"
  echo "Available templates:"
  # Single-file templates (*.nix)
  while IFS= read -r f; do
    name="${f%.nix}"
    [[ "$name" == _* ]] && continue
    echo "  - $name (file)"
  done < <(find "$TEMPLATES_DIR" -maxdepth 1 -type f -name '*.nix' -printf '%f\n' | sort)

  # Directory templates
  while IFS= read -r d; do
    [[ "$d" == _* ]] && continue
    echo "  - $d (dir)"
  done < <(find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
}

# Validators per template kind
validate_name_nix_attr() { # module names
  local name="$1"
  [[ "$name" =~ ^[a-z_][a-z0-9_]*$ ]] || die "Invalid name: $name (use letters, digits, underscores; cannot start with a digit)"
}

subst_in_file() {
  local file="$1" name="$2"
  # Replace __NAME__ in contents
  sed -i -e "s/__NAME__/${name}/g" "$file"
}

render_file_template() {
  local tpl_file="$1" dest_file="$2" name="$3" dry="$4" force="$5"
  [[ -f "$tpl_file" ]] || die "Template missing: $tpl_file"
  if [[ -e "$dest_file" && "$force" != 1 ]]; then
    die "Refusing to overwrite: $dest_file (use --force)"
  fi
  echo "Creating $dest_file"
  [[ "$dry" == 1 ]] && return 0
  mkdir -p "$(dirname "$dest_file")"
  cp "$tpl_file" "$dest_file"
  subst_in_file "$dest_file" "$name"
}

render_dir_template() {
  local tpl_dir="$1" dest_dir="$2" name="$3" dry="$4" force="$5" rename_paths="${6:-1}"
  [[ -d "$tpl_dir" ]] || die "Template dir missing: $tpl_dir"
  if [[ -e "$dest_dir" && "$force" != 1 ]]; then
    die "Refusing to overwrite existing path: $dest_dir (use --force)"
  fi
  echo "Creating $dest_dir"
  [[ "$dry" == 1 ]] && return 0
  rm -rf "$dest_dir"
  mkdir -p "$(dirname "$dest_dir")"
  cp -R "$tpl_dir" "$dest_dir"
  # Substitute in all regular files
  while IFS= read -r f; do
    subst_in_file "$f" "$name"
  done < <(find "$dest_dir" -type f)
  # Optionally rename files/dirs containing __NAME__ in their names
  if [[ "$rename_paths" == 1 ]]; then
    while IFS= read -r p; do
      new="${p//__NAME__/$name}"
      if [[ "$new" != "$p" ]]; then
        mv "$p" "$new"
      fi
    done < <(find "$dest_dir" -depth -name '*__NAME__*')
  fi
}

render_nixos_module() {
  local name="$1" dry="$2" force="$3"
  validate_name_nix_attr "$name"
  local tpl="$TEMPLATES_DIR/nixosModule.nix"
  local dest_dir="nix/modules/nixos/$name"
  local dest_file="$dest_dir/default.nix"
  render_file_template "$tpl" "$dest_file" "$name" "$dry" "$force"
}

# Examples to enable later (uncomment and adapt when you add templates):
# render_home_module() {
#   local name="$1" dry="$2" force="$3"
#   validate_name_nix_attr "$name"
#   local tpl="$TEMPLATES_DIR/homeModule.nix"
#   local dest_dir="nix/modules/home-manager/$name"
#   local dest_file="$dest_dir/default.nix"
#   render_file_template "$tpl" "$dest_file" "$name" "$dry" "$force"
# }

main() {
  if [[ $# -lt 1 ]]; then usage; exit 0; fi
  case "$1" in
    -h|--help) usage; exit 0 ;;
    list) list_templates; exit 0 ;;
  esac

  local template="$1"; shift
  local name="${1:-}"; [[ -n "$name" ]] || die "Missing <name>"; shift || true

  local dry=0 force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --force) force=1; shift ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  case "$template" in
    nixosModule) render_nixos_module "$name" "$dry" "$force" ;;
    # homeModule)  render_home_module  "$name" "$dry" "$force" ;;
    *) die "Unknown template: $template (run 'mkTemplate list' to see known ones)" ;;
  esac
}

main "$@"
