#!/usr/bin/env bash
set -o errexit

INSTALL_TARGET="${1:-"/usr/local/bin/open"}"
BIN_SOURCE="https://raw.githubusercontent.com/Unoqwy/open.sh/master/open.sh"

echo "Downloading open.sh binary"
_tmp=$(mktemp)
curl --fail -o "$_tmp" "$BIN_SOURCE"
chmod +rx "$_tmp"
echo "Installing open.sh to '$INSTALL_TARGET'"
mv  "$_tmp" "$INSTALL_TARGET"
echo "Done!"
