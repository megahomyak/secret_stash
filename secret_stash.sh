#!/bin/bash
set -u
secret_doc_name="$1"
secret_stash_remote_path="$secret_stash_remote_path"
secret_stash_remote_host_name="$secret_stash_remote_host_name"
secret_stash_local_path="$secret_stash_local_path"

temp="$(mktemp)"
(
set -euo pipefail
read -s -p "Enter the passphrase (hidden): " passphrase
echo
secret_doc_name_encrypted="$(echo "$secret_doc_name" | openssl enc -aes-256-cbc -pass pass:$passphrase -pbkdf2 -nosalt | basenc --base64url)"
secret_doc_remote_path_quoted="$(printf "%q" "$secret_stash_remote_path/$secret_doc_name_encrypted")"
mkdir -p "$secret_stash_local_path"
cd "$secret_stash_local_path"
if scp "$secret_stash_remote_host_name:"$secret_doc_remote_path_quoted "$secret_doc_local_path"; then
    gpg --quiet --batch --yes --passphrase "$passphrase" --decrypt "$secret_doc_local_path" > "$temp"
fi
"$EDITOR" "$temp"
if awk "NF { exit 1 }" "$temp"; then
    rm "$secret_doc_local_path" || true
    ssh "$secret_stash_remote_host_name" "rm $secret_doc_remote_path_quoted" || true
else
    gpg --quiet --symmetric --batch --yes --passphrase "$passphrase" --output "$secret_doc_local_path" "$temp"
    ssh "$secret_stash_remote_host_name" "mkdir -p $secret_doc_remote_path_quoted"
    scp "$secret_doc_local_path" "$secret_stash_remote_host_name:"$secret_doc_remote_path_quoted
fi
)
subshell_exit_code="$?"
rm "$temp"
exit "$subshell_exit_code"
