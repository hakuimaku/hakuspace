#!/usr/bin/env bash
# Record orchestrator output while retaining an interactive terminal for prompts.
start_run_log() {
    # The recorder stays outside the updater's exec and owns the entire run.
    [[ "${HAKUSPACE_LOG_ACTIVE:-0}" != 1 ]] || return 0
    local operation="$1" command echo_mode=never
    shift
    command -v script >/dev/null 2>&1 || {
        printf 'Logging requires the script command from util-linux.\n' >&2
        exit 1
    }
    mkdir -p -- "$HAKU_DIR/log" || return 1
    HAKUSPACE_LOG_FILE="$(mktemp --suffix=.log "$HAKU_DIR/log/$operation-$(date +%Y-%m-%d_%H-%M-%S).XXXXXX")" || return 1
    export HAKUSPACE_LOG_FILE HAKUSPACE_LOG_ACTIVE=1
    printf 'Log file: %s\n' "$HAKUSPACE_LOG_FILE"
    [[ ! -t 0 ]] || echo_mode=auto
    # Bash quoting preserves arguments; the child retains the user's original shell setting.
    printf -v command '%q ' env "SHELL=${SHELL:-$BASH}" "$BASH" "$HAKU_DIR/$operation.sh" "$@"
    SHELL="$BASH" exec script --quiet --return --flush --echo "$echo_mode" \
        --command "exec $command" --log-out "$HAKUSPACE_LOG_FILE"
}
