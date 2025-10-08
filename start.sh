#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "ERROR: tmux is required but not installed or not on PATH." >&2
    exit 1
fi

declare -a MENU_OPTIONS=(
    "Start Bootstrap"
    "Start Server"
    "Start Health Monitor"
    "Start API"
    "Quit"
)

get_script_for_option() {
    case "$1" in
        1) echo "$SCRIPT_DIR/start_bootstrap.sh" ;;
        2) echo "$SCRIPT_DIR/start_node.sh" ;;
        3) echo "$SCRIPT_DIR/start_health.sh" ;;
        4) echo "$SCRIPT_DIR/start_api.sh" ;;
        *) return 1 ;;
    esac
}

get_session_for_option() {
    case "$1" in
        1) echo "bootstrap" ;;
        2) echo "server" ;;
        3) echo "health" ;;
        4) echo "api" ;;
        *) return 1 ;;
    esac
}

run_script_in_tmux() {
    local session_name="$1"
    local script_path="$2"

    if [ ! -f "$script_path" ]; then
        echo "ERROR: Unable to locate script at $script_path" >&2
        return 1
    fi

    if tmux has-session -t "$session_name" 2>/dev/null; then
        while true; do
            read -r -p "Session '$session_name' already exists. [A]ttach, [R]estart, or [C]ancel? " choice
            case "${choice,,}" in
                a|"")
                    tmux attach -t "$session_name" || echo "tmux session '$session_name' is no longer available."
                    return 0
                    ;;
                r)
                    tmux kill-session -t "$session_name"
                    break
                    ;;
                c|q)
                    echo "Cancelled. Returning to menu."
                    return 0
                    ;;
                *)
                    echo "Please type A to attach, R to restart, or C to cancel."
                    ;;
            esac
        done
    fi

    tmux new-session -d -s "$session_name" -c "$SCRIPT_DIR" bash "$script_path"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to start tmux session '$session_name'." >&2
        return 1
    fi

    echo "Session '$session_name' is ready. You'll be attached now (detach with Ctrl-b d)."
    tmux attach -t "$session_name" || echo "tmux session '$session_name' ended."
}

PS3=$'\n'"Select an option (number): "

while true; do
    echo
    echo "What would you like to do?"
    select option in "${MENU_OPTIONS[@]}"; do
        if [ -z "$option" ]; then
            echo "Invalid selection. Please choose a number between 1 and ${#MENU_OPTIONS[@]}."
            break
        fi

        if [ "$option" = "Quit" ]; then
            echo "Goodbye!"
            exit 0
        fi

        action_index="$REPLY"
        script_path="$(get_script_for_option "$action_index")" || {
            echo "No script mapped for that option." >&2
            break
        }

        session_name="$(get_session_for_option "$action_index")" || {
            echo "No session name mapped for that option." >&2
            break
        }

        run_script_in_tmux "$session_name" "$script_path"
        break
    done
done
