#!/usr/bin/env bash
set -euo pipefail

while true; do
    echo "==> Inspecting status..."
    jj status
    echo ""

    # Optional diff view
    read -r -p "Would you like to view the diff before committing? [y/N]: " show_diff
    if [[ "${show_diff}" =~ ^[Yy]$ ]]; then
        echo "--- Current Diff ---"
        jj diff
        echo "--------------------"
        echo ""
    fi

    # Interactive describe with non-empty validation loop
    commit_msg=""
    while [[ -z "${commit_msg// /}" ]]; do
        read -r -p "Enter a description for this change: " commit_msg
        if [[ -z "${commit_msg// /}" ]]; then
            echo "Error: Commit message cannot be empty. Please try again." >&2
        fi
    done

    echo "-> Describing change..."
    jj describe -m "${commit_msg}"

    echo "-> Moving main bookmark..."
    jj bookmark set main -r @

    echo "-> Pushing bookmark to remote..."
    jj git push --remote origin --bookmark main

    echo "-> Opening clean slate for next task..."
    jj new
    echo ""

    # Continue or end prompt
    read -r -p "Do you want to continue working or call it a day? [c=Continue / e=End]: " next_action
    case "${next_action}" in
        [Cc]*)
            echo "Starting next workflow loop..."
            echo ""
            ;;
        *)
            echo "All changes saved and pushed. Have a good evening!"
            exit 0
            ;;
    esac
done