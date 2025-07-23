#!/bin/bash
set -euo pipefail
# required vars: secret_stash_local_path, secret_stash_remote_host, secret_stash_remote_path
query=test
#read -s -p "Enter your query (hidden): " query; echo
ssh_remote() { ssh $secret_stash_remote_host "$@"; }
cd $secret_stash_local_path
passphrase=test
#read -s -p "Enter the passphrase (hidden): " passphrase; echo
encrypt_fname() { fname="$1"; echo $fname | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url; }
send() {
    fname="$1"
    ssh_remote "cat > $secret_stash_remote_path/$fname" < $fname
}
if [ "${query:0:1}" = '!' ]; then # Re-send; handy for when I have connectivity issues
    send "$(encrypt_fname ${query:1})"
else # (Try to download) and edit
    fname=$(encrypt_fname $query)
    temp_editing=$(mktemp); trap 'rm -f $temp_editing' EXIT
    ( ssh_remote "mkdir -p $secret_stash_remote_path && cat $secret_stash_remote_path/$fname 2&>/dev/null" | gpg --quiet --batch --yes --passphrase $passphrase --decrypt --output $temp_editing ) || true
    $EDITOR $temp_editing
    if awk 'NF { exit 1 }' $temp_editing; then
        rm -f $fname
        ssh_remote "rm -f $secret_stash_remote_path/$fname"
    else
        gpg --quiet --symmetric --batch --yes --passphrase $passphrase --output $fname $temp_editing
        echo 
        send $fname
    fi
fi
