#!/bin/bash
set -euo pipefail
# required vars: secret_stash_local_path, secret_stash_remote_host, secret_stash_remote_path
read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { ssh -o ConnectTimeout=5 $secret_stash_remote_host "$@"; }
cd $secret_stash_local_path
read -s -p "Enter the passphrase (hidden): " passphrase; echo
fname=$(echo $query | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url)
(temp_editing=$(mktemp); trap 'rm -f $temp_editing' EXIT
    while [ "$( ssh_remote "echo connected && mkdir -p $secret_stash_remote_path && cat $secret_stash_remote_path/$fname 2>/dev/null" | gpg --quiet --batch --yes --passphrase $passphrase --output "$temp_editing")" != "connected" ]; do :; done
    $EDITOR $temp_editing
    if awk 'NF { exit 1 }' $temp_editing; then
        rm -f $fname
        while ! ssh_remote "rm -f $secret_stash_remote_path/$fname"; do :; done
    else
        gpg --quiet --symmetric --batch --yes --passphrase $passphrase --output $fname $temp_editing
        while ! ssh_remote "cat > $secret_stash_remote_path/$fname" < $fname; do :; done
    fi
)
