#!/bin/bash

set -euo pipefail

declare file
for key in dsa ecdsa ed25519 rsa; do
  file="/etc/ssh/ssh_host_${key}_key"
  [ -e "$file" ] || /usr/bin/yes 2>/dev/null | /usr/bin/ssh-keygen -f "$file" -N '' -t $key >/dev/null || true
done
