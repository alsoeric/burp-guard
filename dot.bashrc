# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

dtach_auto() {
    local socket_dir="${HOME}/.dtach"
    mkdir -p "$socket_dir"

    # Clean dead sockets safely without throwing errors on empty dirs
    for s in "$socket_dir"/*.sock; do
        [ -e "$s" ] || continue
        if command -v nc >/dev/null 2>&1; then
            nc -z -U "$s" 2>/dev/null || rm -f "$s"
        fi
    done

    # Collect active sockets sorted by modification time
    local sockets=()
    while IFS= read -r -d '' file; do
        sockets+=("$file")
    done < <(find "$socket_dir" -maxdepth 1 -name "*.sock" -printf "%T@ %p\0" 2>/dev/null | sort -znr | cut -z -d' ' -f2-)

    local choice=""
    if [ ${#sockets[@]} -gt 0 ]; then
        echo "Found active dtach session(s):"
        local i=1
        for s in "${sockets[@]}"; do
            echo "  $i) $(basename "$s" .sock) (Last active: $(date -r "$s" '+%Y-%m-%d %H:%M'))"
            ((i++))
        done

        read -p "Connect to [1] (or type a new session name): " choice
        choice=${choice:-1}

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#sockets[@]}" ]; then
            local target_socket="${sockets[$((choice-1))]}"
            echo "Attaching to $(basename "$target_socket" .sock)..."
            dtach -Ez -a "$target_socket"
        else
            echo "Creating new session: $choice"
            dtach -Ez -c "${socket_dir}/${choice}.sock" "$SHELL"
        fi
    else
        echo "No active sessions. Starting new main session..."
        dtach -Ez -c "${socket_dir}/main.sock" "$SHELL"
    fi

    # RECOVERY FALLBACK:
    # Drops to standard bash shell if dtach exits with an error or fails to launch
    if [ $? -ne 0 ]; then
        echo "dtach encountered an error. Dropping to recovery shell..."
        exec /bin/bash --login
    fi
}
dtach_auto() {
    local socket_dir="${HOME}/.dtach"
    mkdir -p "$socket_dir"

    # Clean dead sockets safely without throwing errors on empty dirs
    for s in "$socket_dir"/*.sock; do
        [ -e "$s" ] || continue
        if command -v nc >/dev/null 2>&1; then
            nc -z -U "$s" 2>/dev/null || rm -f "$s"
        fi
    done

    # Collect active sockets sorted by modification time
    local sockets=()
    while IFS= read -r -d '' file; do
        sockets+=("$file")
    done < <(find "$socket_dir" -maxdepth 1 -name "*.sock" -printf "%T@ %p\0" 2>/dev/null | sort -znr | cut -z -d' ' -f2-)

    local choice=""
    if [ ${#sockets[@]} -gt 0 ]; then
        echo "Found active dtach session(s):"
        local i=1
        for s in "${sockets[@]}"; do
            echo "  $i) $(basename "$s" .sock) (Last active: $(date -r "$s" '+%Y-%m-%d %H:%M'))"
            ((i++))
        done

        read -p "Connect to [1] (or type a new session name): " choice
        choice=${choice:-1}

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#sockets[@]}" ]; then
            local target_socket="${sockets[$((choice-1))]}"
            echo "Attaching to $(basename "$target_socket" .sock)..."
            dtach -a "$target_socket" -Ez
        else
            echo "Creating new session: $choice"
            dtach -c "${socket_dir}/${choice}.sock" -Ez "$SHELL"
        fi
    else
        echo "No active sessions. Starting new main session..."
        dtach -c "${socket_dir}/main.sock" -Ez "$SHELL"
    fi

    # RECOVERY FALLBACK:
    # Drops to standard bash shell if dtach exits with an error or fails to launch
    if [ $? -ne 0 ]; then
        echo "dtach encountered an error. Dropping to recovery shell..."
        exec /bin/bash --login
    fi
}

# This must go at the end of `.bashrc` because it'll put you into a detached session.
# Run only on interactive SSH sessions and outside existing dtach sessions
if [ -n "$SSH_CONNECTION" ] && [ -z "$DTACH_ACTIVE" ]; then
    export DTACH_ACTIVE=1
    dtach_auto
fi
