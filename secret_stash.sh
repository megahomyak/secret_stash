#!/bin/bash
set -euo pipefail
cd "$secret_stash_local_dir"
read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { while ssh -o "ConnectTimeout=${secret_stash_connect_timeout:-10}" "$secret_stash_remote_host" "$@"; [ "$?" = 255 ]; do echo 'Reconnecting...' >&2; done }
read -s -p "Enter your passphrase (hidden): " part_of_passphrase; echo
passphrase="$(cat key.txt)/$query/$part_of_passphrase"
encrypted_file_name="$(echo "$query" | openssl enc -aes-256-cbc -pass "pass:$passphrase" -pbkdf2 -iter 600000 -nosalt | basenc --base64url --wrap 0)"
local_file_path="$secret_stash_local_dir/$encrypted_file_name"
remote_file_path="$secret_stash_remote_dir/$encrypted_file_name"
escape() { printf "%q" "$1"; }
(trap 'shred -fu "$editing_temp" 2>/dev/null || true' EXIT; editing_temp="$local_file_path.editing"
    (trap 'shred -fu "$downloading_temp" 2>/dev/null || true' EXIT; downloading_temp="$local_file_path.downloading"
        if ssh_remote "cat $(escape "$remote_file_path") 2>/dev/null" | gpg --quiet --decrypt --batch --yes --passphrase "$passphrase" > "$downloading_temp" 2>/dev/null; then
            cp "$downloading_temp" "$editing_temp"
        fi
    )
    "$EDITOR" "$editing_temp"
    if [ -f "$editing_temp" ]; then
        if awk 'NF { exit 1 }' "$editing_temp"; then
            shred -fu "$local_file_path" 2>/dev/null || true
            ssh_remote "shred -fu $(escape "$remote_file_path") 2>/dev/null || true"
        else
            gpg --quiet --symmetric --batch --yes --passphrase "$passphrase" < "$editing_temp" > "$local_file_path"
            ssh_remote "mkdir -p $(escape "$secret_stash_remote_dir") && cat > $(escape "$remote_file_path")" < "$local_file_path"
        fi
    fi
)
