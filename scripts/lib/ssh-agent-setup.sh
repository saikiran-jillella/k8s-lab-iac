#!/bin/bash
# Shared SSH agent setup sourced by all scripts that use SSH.
# Ensures the lab key exists (prompting to generate if missing),
# starts ssh-agent if needed, and loads the key once.

LAB_KEY="$HOME/.ssh/k8s_lab_ed25519"

if [[ ! -f "$LAB_KEY" ]]; then
    echo
    echo "Lab SSH key not found:"
    echo "  $LAB_KEY"
    echo

    read -rp "Generate it now? [Y/n] " answer
    answer=${answer:-Y}

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$LAB_KEY")"

        echo
        echo "Creating a new Ed25519 SSH key."
        echo "You may enter a passphrase or leave it empty."
        echo

        if ! ssh-keygen -t ed25519 -f "$LAB_KEY"; then
            echo
            echo "SSH key generation was cancelled or failed."
            return 1 2>/dev/null || exit 1
        fi
    else
        echo
        echo "SSH key setup cancelled."
        return 1 2>/dev/null || exit 1
    fi
fi

if ! ssh-add -l >/dev/null 2>&1; then
    echo "Starting ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null
fi

# Compare the fingerprint of the lab key against the keys loaded in the agent
FINGERPRINT=$(ssh-keygen -lf "$LAB_KEY" | awk '{print $2}')
if ! ssh-add -l 2>/dev/null | grep -q "$FINGERPRINT"; then
    echo "Loading lab SSH key into agent (you may be prompted for its passphrase)..."

    if ! ssh-add "$LAB_KEY"; then
        echo
        echo "Failed to load SSH key into the agent."
        return 1 2>/dev/null || exit 1
    fi
fi