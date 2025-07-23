#!/bin/bash
set -euo pipefail
read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { while ssh -o ConnectTimeout=${secret_stash_connect_timeout:-10} $secret_stash_remote_host "$@"; [ $? = 255 ]; do echo Reconnecting... >&2; done }
cd $secret_stash_local_dir
read -s -p "Enter the passphrase (hidden): " passphrase; echo
fname=$(echo $query | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url)
(trap 'rm -f $temp_editing' EXIT; temp_editing=$(mktemp)
    encrypt() { gpg --quiet --symmetric --batch --yes --passphrase "$1"; }
    decrypt() { gpg --quiet --decrypt --batch --yes --passphrase "$1"; }
    ssh_remote "mkdir -p $secret_stash_remote_dir && cat $secret_stash_remote_dir/$fname 2>/dev/null" | decrypt $(cat key.txt) | decrypt $passphrase > $temp_editing || true
    $EDITOR $temp_editing
    if awk 'NF { exit 1 }' $temp_editing; then
        rm -f $fname
        ssh_remote "rm -f $secret_stash_remote_dir/$fname"
    else
        (encrypt $passphrase | encrypt $(cat key.txt)) < $temp_editing > $fname
        ssh_remote "cat > $secret_stash_remote_dir/$fname" < $fname
    fi
)
