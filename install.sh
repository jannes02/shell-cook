#!/usr/bin/env bash
# Installs shell-cook with uv, then runs `shell-cook setup`, which
# asks before it touches ~/.bashrc and skips the edit if the line is already
# there.
#
# Usage: ./install.sh [-y|--yes] [-e|--editable] [--name NAME] [--dry-run]
#   -y, --yes       do not ask; answer yes to every question
#   -e, --editable  install this checkout in editable mode (development)
#   --name NAME     name of the shell command (default: ask, suggesting "cook")
#   --dry-run       only print what would be done
#
# Also works piped: curl -fsSL <raw-url>/install.sh | bash
set -euo pipefail

REPO_URL="${SHELL_COOK_REPO:-https://github.com/jannes02/shell-cook}"
ASSUME_YES=0
EDITABLE=0
DRY_RUN=0
ALIAS_NAME=""

die() {
    echo "error: $*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: install.sh [-y|--yes] [-e|--editable] [--name NAME] [--dry-run]
  -y, --yes       do not ask; answer yes to every question
  -e, --editable  install this checkout in editable mode (development)
  --name NAME     name of the shell command (default: ask, suggesting "cook")
  --dry-run       only print what would be done
EOF
}

# True if a controlling terminal is available (also when stdin is a pipe).
have_tty() {
    { : </dev/tty; } 2>/dev/null
}

# Asks a y/N question on the terminal; returns 0 for yes.
confirm() {
    [ "$ASSUME_YES" = 1 ] && return 0
    have_tty || die "not interactive; re-run with --yes"
    local answer
    read -r -p "$1 [y/N] " answer </dev/tty
    case "$answer" in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Prints a command and runs it unless --dry-run is set.
run() {
    echo "+ $*"
    if [ "$DRY_RUN" = 0 ]; then
        "$@"
    fi
}

# Like run, but gives the command the terminal as stdin when this script is
# piped (curl | bash), so that its prompts work.
run_tty() {
    if [ "$ASSUME_YES" = 1 ] || [ -t 0 ]; then
        run "$@"
    elif have_tty; then
        run "$@" </dev/tty
    else
        die "no terminal available; re-run with --yes"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -y | --yes) ASSUME_YES=1 ;;
        -e | --editable) EDITABLE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --name)
            [ "$#" -ge 2 ] || die "--name needs a value"
            ALIAS_NAME="$2"
            shift
            ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done

command -v uv >/dev/null 2>&1 ||
    die "uv not found. Install it first: https://docs.astral.sh/uv/getting-started/installation/"

# Prefer the local checkout when this script lives inside one.
source_spec="git+$REPO_URL"
script="${BASH_SOURCE[0]:-}"
if [ -n "$script" ] && [ -f "$script" ]; then
    here="$(cd "$(dirname "$script")" && pwd)"
    if [ -f "$here/pyproject.toml" ] &&
        grep -q '^name = "shell-cook"' "$here/pyproject.toml"; then
        source_spec="$here"
    fi
fi

if [ "$source_spec" = "git+$REPO_URL" ]; then
    [ "$EDITABLE" = 0 ] || die "--editable needs a local checkout"
    case "$REPO_URL" in
        *"<you>"*) die "set SHELL_COOK_REPO to the repository URL" ;;
    esac
fi

echo "This will install shell-cook from: $source_spec"
confirm "Run 'uv tool install' now?" || { echo "Aborted."; exit 1; }

install_args=(tool install --force)
if [ "$EDITABLE" = 1 ]; then
    install_args+=(--editable)
fi
run uv "${install_args[@]}" "$source_spec"

bin_dir="$(uv tool dir --bin)"
case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "Note: $bin_dir is not in PATH. Run 'uv tool update-shell' and open a new terminal." ;;
esac

# `setup` asks before changing ~/.bashrc and skips it if already configured.
setup_args=(setup)
if [ "$ASSUME_YES" = 1 ]; then
    setup_args+=(-y)
fi
if [ -n "$ALIAS_NAME" ]; then
    setup_args+=(--name "$ALIAS_NAME")
fi
run_tty "$bin_dir/shell-cook" "${setup_args[@]}"

# Offer the Claude login if there is none yet (interactive runs only).
if [ "$DRY_RUN" = 0 ] && [ "$ASSUME_YES" = 0 ]; then
    if ! "$bin_dir/shell-cook" login status >/dev/null 2>&1; then
        echo "You are not logged in to Claude yet."
        if confirm "Log in now?"; then
            run_tty "$bin_dir/shell-cook" login
        else
            echo "Later: shell-cook login (or set ANTHROPIC_API_KEY)."
        fi
    fi
fi

echo "Done. Open a new terminal, then run: shell-cook update"
