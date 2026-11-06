# shell-cook shell integration. Add this line to ~/.bashrc:
#   eval "$(shell-cook shell-init __ALIAS__)"
__ALIAS__() {
    local cmd rc answer

    # shell-init prints the function itself: show it, do not treat it as a
    # command to review.
    if [ "${1:-}" = "shell-init" ]; then
        command shell-cook "$@"
        return
    fi

    # stdout = generated command; stderr (status, risk, diffs) goes to the tty.
    cmd=$(command shell-cook "$@")
    rc=$?

    # 0 = ok, 10 = ok but high risk, anything else = error/abort.
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 10 ]; then
        return "$rc"
    fi

    # Empty stdout: subcommand without a command to run.
    [ -z "$cmd" ] && return

    if [[ "$cmd" == *$'\n'* ]]; then
        # A one-line prompt cannot hold or edit a multi-line command, so show
        # it unchanged and ask. What you read is exactly what runs.
        printf '%s\n' "$cmd" >&2
        read -r -p "Multi-line command (not editable). Run as shown? [y/N] " \
            answer || return
        case "$answer" in
            y | Y | yes | YES) ;;
            *) echo "Aborted." >&2; return 1 ;;
        esac
    else
        # -r keeps backslashes (regexes, escapes); IFS= keeps leading blanks.
        IFS= read -r -e -i "$cmd" -p "$ " cmd || return
    fi

    # High risk: require an explicit typed "yes".
    if [ "$rc" -eq 10 ]; then
        read -r -p "HIGH RISK - type 'yes' to run: " answer
        [ "$answer" = "yes" ] || { echo "Aborted." >&2; return 1; }
    fi

    history -s "$cmd"
    eval "$cmd"
}
