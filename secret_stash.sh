#!/bin/bash
set -euo pipefail
read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { while ssh -o ConnectTimeout=${secret_stash_connect_timeout:-10} $secret_stash_remote_host "$@"; [ $? = 255 ]; do echo Reconnecting... >&2; done }
cd $secret_stash_local_dir
read -s -p "Enter the passphrase (hidden): " passphrase; echo
fname=$(echo $query | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url)
(temp_editing=$(mktemp); trap 'rm -f $temp_editing' EXIT
    ssh_remote "mkdir -p $secret_stash_remote_dir && cat $secret_stash_remote_dir/$fname 2>/dev/null" | gpg --quiet --decrypt --batch --yes --passphrase $(cat key.txt) | gpg --quiet --decrypt --batch --yes --passphrase $passphrase --output $temp_editing || true
    echo $fname
    $EDITOR $temp_editing
    if awk 'NF { exit 1 }' $temp_editing; then
        rm -f $fname
        ssh_remote "rm -f $secret_stash_remote_dir/$fname"
    else
        cat $temp_editing | gpg --quiet --symmetric --batch --yes --passphrase $(cat key.txt) | gpg --quiet --symmetric --batch --yes --passphrase $passphrase --output $fname
        ssh_remote "cat > $secret_stash_remote_dir/$fname" < $fname
    fi
)
