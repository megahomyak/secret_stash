#!/bin/bash
secret_doc_path="$1"
temp="$(mktemp)"
(
set -euo pipefail
read -s -p "Enter the passphrase (hidden): " passphrase
echo
if [ -f "$secret_doc_path" ]; then
    gpg --quiet --batch --yes --passphrase "$passphrase" --decrypt "$secret_doc_path" > "$temp"
fi
"$EDITOR" "$temp"
gpg --quiet --symmetric --batch --yes --passphrase "$passphrase" --output "$secret_doc_path" "$temp"
)
subshell_exit_code="$?"
rm "$temp"
exit "$subshell_exit_code"
