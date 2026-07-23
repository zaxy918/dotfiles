#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly HOME_DIR="${HOME:?HOME is not set}"
readonly BACKUP_ROOT="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/dotfiles/backups"

DRY_RUN=false
BACKUP_DIR=""
INSTALLED=0
SKIPPED=0
DISCOVERED=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [--help]

Install dotfiles from this repository by creating symbolic links in $HOME.

Recognized repository layout:
  .zshrc              -> ~/.zshrc
  .p10k.zsh           -> ~/.p10k.zsh
  .tmux.conf           -> ~/.tmux.conf
  .gitconfig           -> ~/.gitconfig
  .vimrc               -> ~/.vimrc
  .config/nvim         -> ~/.config/nvim
  .config/<anything>   -> ~/.config/<anything>

Existing files that are not already linked to this repository are moved to:
  ${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/<timestamp>/

Options:
  --dry-run  Show what would change without changing anything
  -h, --help Show this help
EOF
}

log() {
  printf '%s\n' "$*"
}

run() {
  if "$DRY_RUN"; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

absolute_path() {
  local path="$1"
  local directory
  local name

  directory="$(dirname -- "$path")"
  name="$(basename -- "$path")"
  printf '%s/%s\n' "$(cd -- "$directory" && pwd -P)" "$name"
}

same_link() {
  local source="$1"
  local target="$2"
  local linked_path

  [[ -L "$target" ]] || return 1
  linked_path="$(readlink -- "$target")"

  if [[ "$linked_path" != /* ]]; then
    linked_path="$(dirname -- "$target")/$linked_path"
  fi

  [[ "$(absolute_path "$linked_path")" == "$(absolute_path "$source")" ]]
}

ensure_backup_dir() {
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y%m%d-%H%M%S')"
    run mkdir -p -- "$BACKUP_DIR"
  fi
}

backup_target() {
  local target="$1"
  local relative_target="${target#"$HOME_DIR"/}"
  local backup_path

  ensure_backup_dir
  backup_path="$BACKUP_DIR/$relative_target"
  run mkdir -p -- "$(dirname -- "$backup_path")"
  run mv -- "$target" "$backup_path"
  log "backup  $target -> $backup_path"
}

install_link() {
  local source="$1"
  local target="$2"

  [[ -e "$source" || -L "$source" ]] || return 0
  DISCOVERED=$((DISCOVERED + 1))

  if same_link "$source" "$target"; then
    log "skip    $target (already linked)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup_target "$target"
  fi

  run mkdir -p -- "$(dirname -- "$target")"
  run ln -s -- "$source" "$target"
  log "link    $target -> $source"
  INSTALLED=$((INSTALLED + 1))
}

main() {
  local name
  local source

  while (($# > 0)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  if [[ "$SCRIPT_DIR" == "$HOME_DIR" ]]; then
    printf 'Refusing to install: the repository must not be your home directory.\n' >&2
    exit 1
  fi

  log "Dotfiles source: $SCRIPT_DIR"
  log "Install target:  $HOME_DIR"
  "$DRY_RUN" && log "Mode:            dry run"
  log ""

  # install dotfiles
  for name in .zshrc .p10k.zsh .tmux.conf .gitconfig .vimrc ; do
    install_link "$SCRIPT_DIR/$name" "$HOME_DIR/$name"
  done

  if [[ -d "$SCRIPT_DIR/.config" ]]; then
    while IFS= read -r -d '' source; do
      name="$(basename -- "$source")"
      install_link "$source" "$HOME_DIR/.config/$name"
    done < <(find "$SCRIPT_DIR/.config" -mindepth 1 -maxdepth 1 -print0)
  fi

  if ((DISCOVERED == 0)); then
    printf 'No supported dotfiles were found beside this script.\n' >&2
    printf 'Place install.sh in the root of your dotfiles repository and try again.\n' >&2
    exit 1
  fi

  log ""
  log "Done: $INSTALLED linked, $SKIPPED already correct."
  if [[ -n "$BACKUP_DIR" ]]; then
    log "Backup: $BACKUP_DIR"
  fi
}

main "$@"
