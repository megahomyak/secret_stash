#!/bin/bash
set -euo pipefail
# required vars: secret_stash_local_path, secret_stash_remote_host, secret_stash_remote_path
read -p "Enter your query: " query
ssh_remote() { ssh $secret_stash_remote_host "$@"; }
cd $secret_stash_local_path
if [ "${query:0:1}" = "-" ]; then # Deletion
    fname=${query:1}
    rm $fname
    ssh_remote "rm $secret_stash_remote_path/$fname"
else # Possible creation -> editing
    read -s -p "Enter the passphrase (hidden): " passphrase; echo
    fname=$(echo $query | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url)
    echo EDITING $fname
    (
        temp_editing=$(mktemp)
        trap 'rm -f $temp_editing' EXIT
        ( ssh_remote "mkdir -p $secret_stash_remote_path && cat $secret_stash_remote_path/$fname" | gpg --quiet --batch --yes --passphrase $passphrase --decrypt --output $temp_editing ) || true
        $EDITOR $temp_editing
        gpg --quiet --symmetric --batch --yes --passphrase $passphrase --output $fname $temp_editing
    )
    ssh_remote "cat > $secret_stash_remote_path/$fname" < $fname
fi
