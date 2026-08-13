# ==============================================================================
# ~/.bashrc - Modular dtach Auto-Session Manager
# Architecture:
#   1. Guard Clause          --> Early exit for non-interactive shells
#   2. Environment & Config  --> Debug flags, PATH, and completions
#   3. Helper Functions      --> Logging, attachment checks, and session handlers
#   4. Core Logic            --> Orchestrator & interactive menu
#   5. Entry Point & Prompt  --> SSH trigger guard & PS1 integration
# ==============================================================================


# ==============================================================================
# LAYER 1: Guard Clause
# ==============================================================================
case $- in
    *i*) ;;
      *) return ;;
esac


# ==============================================================================
# LAYER 2: Environment & Configuration
# ==============================================================================
export DTACH_DEBUG=0

# Standard PATH exports
PATH=$PATH:$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin
export PATH

# Tool Completions
if command -v jj >/dev/null 2>&1; then
    source <(COMPLETE=bash jj)
fi


# ==============================================================================
# LAYER 3: Helper Functions
# ==============================================================================

# Conditional Debug Logging
ddebug() {
    if [ "${DTACH_DEBUG:-0}" -eq 1 ] 2>/dev/null; then
        echo "[DEBUG] $*" >&2
    fi
}

# Pure Bash/ss Socket Attachment Check
dtach_is_attached() {
    local socket_path="$1"
    local count
    count=$(ss -xla 2>/dev/null | grep -c "$socket_path")
    [ "$count" -ge 2 ]
}

# Portable Dead Socket Purge (Self-Contained UI Output)
dtach_cleanup_dead_sockets() {
    local socket_dir="$1"
    local host="$2"
    local dead_sessions=()

    ddebug "Cleaning dead sockets in ${socket_dir}..."
    for s in "$socket_dir"/${host}__*.sock; do
        [ -e "$s" ] || continue
        if ! ss -xla 2>/dev/null | grep -q "$s"; then
            local raw_name sess_name mod_time
            raw_name=$(basename "$s" .sock)
            sess_name="${raw_name#*__}"
            mod_time=$(date -r "$s" '+%H:%M %b %d')

            # 1. Audit log to syslog
            logger -t dtach "Removed dead socket: ${raw_name}.sock"

            # 2. Capture for local UI display
            dead_sessions+=("  • ${sess_name} (${mod_time})")

            # 3. Purge socket file
            ddebug "Removing stale socket file: $s"
            rm -f "$s"
        fi
    done

    # Print summary block ONLY if dead sockets were removed
    if [ "${#dead_sessions[@]}" -gt 0 ]; then
        echo "=== dtach Dead Sessions Removed [Host: ${host}] ==="
        printf '%s\n' "${dead_sessions[@]}"
        echo ""
    fi
}

# Friendly Name Generator
dtach_get_friendly_name() {
    ddebug "Generating friendly name..."
    if [ -f /usr/share/dict/words ]; then
        grep -E '^[a-z]{4,8}$' /usr/share/dict/words 2>/dev/null | shuf -n 1
    elif [ -f /usr/share/dict/american-english ]; then
        grep -E '^[a-z]{4,8}$' /usr/share/dict/american-english 2>/dev/null | shuf -n 1
    else
        local adj=("swift" "calm" "bright" "clever" "quiet" "bold" "warm" "eager")
        local noun=("falcon" "river" "cedar" "harbor" "summit" "orbit" "beacon" "forest")
        echo "${adj[$((RANDOM % ${#adj[@]}))]}-${noun[$((RANDOM % ${#noun[@]}))]}"
    fi
}

# Menu Choice Validator for Existing Sessions
dtach_is_existing_session_choice() {
    local choice="$1"
    local total_sockets="$2"

    [[ "$choice" =~ ^[0-9]+$ ]] && \
    [ "$choice" -ge 2 ] && \
    [ "$choice" -le $(( total_sockets + 1 )) ]
}

# Branch A: Create & Exec New Session
dtach_create_session() {
    local host="$1"
    local socket_dir="$2"

    local default_name
    default_name=$(dtach_get_friendly_name)
    default_name=${default_name:-session-$RANDOM}

    read -p "Session name [default: ${default_name}]: " user_name
    user_name=${user_name:-$default_name}
    
    # Sanitize input; fallback if user enters invalid characters only
    user_name=$(echo "$user_name" | tr -cd 'a-zA-Z0-9_-')
    [ -z "$user_name" ] && user_name=$(dtach_get_friendly_name)

    export DTACH_SESSION_NAME="$user_name"
    export DTACH_ACTIVE=1
    local target_socket="${socket_dir}/${host}__${user_name}.sock"

    if [ -e "$target_socket" ] && pgrep -f "dtach -c ${target_socket}" >/dev/null 2>&1; then
        ddebug "Socket exists with active master. Attaching instead."
        exec dtach -a "$target_socket" -Ez
    else
        ddebug "Launching new master: dtach -c $target_socket -Ez $SHELL"
        exec dtach -c "$target_socket" -Ez "$SHELL"
    fi
}

# Branch B: Attach to Existing Session
dtach_attach_session() {
    local choice="$1"
    shift
    local sockets=("$@")

    local array_index=$(( choice - 2 ))
    local target_socket="${sockets[$array_index]}"
    local raw_name
    raw_name=$(basename "$target_socket" .sock)

    export DTACH_SESSION_NAME="${raw_name#*__}"
    export DTACH_ACTIVE=1
    ddebug "Attaching to session: dtach -a $target_socket -Ez"
    exec dtach -a "$target_socket" -Ez
}

# Render Session Menu
dtach_render_menu() {
    local host="$1"
    shift
    local sockets=("$@")

    echo "=== dtach Available Sessions [Host: ${host}] ==="
    echo "  1) [+] Create a new session"

    local i=2
    for s in "${sockets[@]}"; do
        local raw_name
        raw_name=$(basename "$s" .sock)
        local sess_name="${raw_name#*__}"
        local mod_time
        mod_time=$(date -r "$s" '+%H:%M %b %d')

        local status="   [detached]"
        if dtach_is_attached "$s"; then
            status=" * [ATTACHED]"
        fi

        echo "  $i) ${sess_name} (${mod_time})${status}"
        ((i++))
    done
    echo ""
}

# Dispatcher
dtach_process_selection() {
    local choice="$1"
    local host="$2"
    local socket_dir="$3"
    shift 3
    local sockets=("$@")

    if [ "$choice" -eq 1 ]; then
        dtach_create_session "$host" "$socket_dir"
    elif dtach_is_existing_session_choice "$choice" "${#sockets[@]}"; then
        dtach_attach_session "$choice" "${sockets[@]}"
    else
        ddebug "Invalid selection made. Dropping to standard login shell."
        return 1
    fi
}


# ==============================================================================
# LAYER 4: Core Logic (Orchestrator)
# ==============================================================================
dtach_auto() {
    local host="${HOSTNAME%%.*}"
    local socket_dir="${HOME}/.dtach"
    ddebug "Entering dtach_auto() on host '${host}'"

    mkdir -p "$socket_dir"
    chmod 700 "$socket_dir"

    # 1. Maintenance & UI notice for dead sockets
    dtach_cleanup_dead_sockets "$socket_dir" "$host"

    # 2. Collect active sockets
    local sockets=()
    while IFS= read -r -d '' file; do
        sockets+=("$file")
    done < <(find "$socket_dir" -maxdepth 1 -name "${host}__*.sock" -printf "%T@ %p\0" 2>/dev/null | sort -znr | cut -z -d' ' -f2-)

    # 3. Render Menu
    dtach_render_menu "$host" "${sockets[@]}"

    # 4. Prompt for selection
    local default_opt=1
    read -p "Select session [1-$(( ${#sockets[@]} + 1 ))] (default $default_opt): " choice
    choice=${choice:-$default_opt}

    # 5. Dispatch Action
    dtach_process_selection "$choice" "$host" "$socket_dir" "${sockets[@]}"
}


# ==============================================================================
# LAYER 5: Entry Point & Prompt Integration
# ==============================================================================

# Update Prompt (PS1) if inside an active dtach session
if [ -n "$DTACH_SESSION_NAME" ] && [[ "$PS1" != "${DTACH_SESSION_NAME}: "* ]]; then
    PS1="${DTACH_SESSION_NAME}: ${PS1}"
fi

# SSH Invocation Guard Block
if [ -z "$DTACH_ACTIVE" ]; then
    if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
        dtach_auto
    fi
fi
