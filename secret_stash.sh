#!/bin/bash
set -euo pipefail
read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { while ssh -o ConnectTimeout=${secret_stash_connect_timeout:-10} $secret_stash_remote_host "$@"; [ $? = 255 ]; do echo Reconnecting... >&2; done }
cd $secret_stash_local_dir
read -s -p "Enter the passphrase (hidden): " passphrase; echo
encrypt_deterministic() { openssl enc -aes-256-cbc -pass $1 -pbkdf2 -nosalt; }
fname=$(echo $query | encrypt_deterministic pass:$passphrase | encrypt_deterministic file:key.txt | basenc --base64url)
(trap 'rm -f $temp_editing' EXIT; temp_editing=$(mktemp)
    encrypt_nondeterministic() { gpg --quiet --symmetric --batch --yes --passphrase $1; }
    decrypt_nondeterministic() { gpg --quiet --decrypt --batch --yes --passphrase $1; }
    ssh_remote "mkdir -p $secret_stash_remote_dir && cat $secret_stash_remote_dir/$fname 2>/dev/null" | decrypt_nondeterministic $(cat key.txt) | decrypt_nondeterministic $passphrase > $temp_editing || true
    $EDITOR $temp_editing
    if awk 'NF { exit 1 }' $temp_editing; then
        rm -f $fname
        ssh_remote "rm -f $secret_stash_remote_dir/$fname"
    else
        (encrypt_nondeterministic $passphrase | encrypt_nondeterministic $(cat key.txt)) < $temp_editing > $fname
        ssh_remote "cat > $secret_stash_remote_dir/$fname" < $fname
    fi
)
