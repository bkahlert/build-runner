#!/bin/bash

set -euo pipefail

source logr.sh

# Fixes permissions to stdout and stderr.
# see https://github.com/containers/conmon/pull/112
fix_std_permissions() {
  chmod -R 0777 /proc/self/fd/1 /proc/self/fd/2 || failr "failed to change permissions of stdout and stderr"
}

# Updates the group ID of the specified group.
# Arguments:
#   1 - name of the group
#   2 - ID of the group
update_group_id() {
  local -r group=${1:?group missing}
  local -r gid=${2:?gid missing}
  if [ "$gid" ] && [ "$gid" != "$(id -g "${group}")" ]; then
    sed -i -e "s/^${group}:\([^:]*\):[0-9]*/${group}:\1:${gid}/" /etc/group
    sed -i -e "s/^${group}:\([^:]*\):\([0-9]*\):[0-9]*/${group}:\1:\2:${gid}/" /etc/passwd
  fi
}

# Updates the user ID of the specified user.
# Arguments:
#   1 - name of the user
#   2 - ID of the user
update_user_id() {
  local -r user=${1:?user missing}
  local -r uid=${2:?uid missing}
  if [ "$uid" ] && [ "$uid" != "$(id -u "${user}")" ]; then
    sed -i -e "s/^${user}:\([^:]*\):[0-9]*:\([0-9]*\)/${user}:\1:${uid}:\2/" /etc/passwd
  fi
}

# Fixes the home permissions for the specified user.
# Arguments:
#   1 - name of the user
fix_home_permissions() {
  local -r user=${1:?user missing}
  local -r home="/home/$user"
  mkdir -p "$home"
  chown -R "$user" "$home"
  chmod -R u+rw "$home"
}

# Updates the timezone.
# Arguments:
#   1 - timezone
update_timezone() {
  local -r timezone=${1:?timezone missing}
  ln -snf "/usr/share/zoneinfo/$timezone" /etc/localtime
  echo "$timezone" >/etc/timezone
}

# Sets the specified configuration keyword values in sshd_config.
# If a keyword is present, its value will be updated.
# If a keyword commented out, it will be commented in and its value will be updated.
# If a keyword is not present, it will be added with its value to the end of the file.
#
# Arguments:
#   List of key value pairs, e.g. "foo=bar"
set_sshd_config() {
  local option
  for option in "$@"; do
    logr info "SSH daemon config: setting $option"
    local key="${option%%=*}"
    local value="${option#*=}"
    if [ ! "$key" ]; then
      logr warn "SSH daemon config: skipping invalid key in ${option}"
      continue
    fi
    if sed \
      --expression 's/#?[[:space:]]*'${key}' .*$/'${key}' '${value}'/g' \
      --in-place \
      --regexp-extended \
      /etc/ssh/sshd_config; then
      logr success "SSH daemon config: $key set to $value"
    else
      logr error "SSH daemon config: failed to set $key to $value"
    fi
  done
}

# Enables SSH public key authentication and
# disables password authentication for the specified user.
# Arguments:
#   1 - name of the user
#   2 - public key
use_ssh_public_key_authentication() {
  local -r user="${1:?user missing}"
  local -r public_key="${2:?public key missing}"

  mkdir -p "/home/${user}/.ssh"

  logr task "setting authorized key for $user to ${public_key:0:10}" \
    -- bash -c "echo '$public_key' >'/home/$user/.ssh/authorized_keys'"
  logr task "setting random password for $user" \
    -- bash -c "echo '$user:$(tr -dc '[:alnum:]' </dev/urandom 2>/dev/null | dd bs=4 count=8 2>/dev/null)' | chpasswd"

  logr task "disabling password authentication" \
    -- set_sshd_config \
    'ChallengeResponseAuthentication=no' \
    'PasswordAuthentication=no'
}

# Enables SSH password authentication and
# disables public key authentication for the specified user.
# Arguments:
#   1 - name of the user
#   2 - password (default: $user)
use_ssh_password_authentication() {
  local -r user="${1:?user missing}"
  local -r password="${2:-${user}}"

  logr task "setting password for $user to ${password:0:2}" \
    -- bash -c "echo '$user:$password' | chpasswd"
  logr task "removing authorized key from $user" \
    -- bash -c "[ ! -f '/home/$user/.ssh/authorized_keys' ] || rm '/home/$user/.ssh/authorized_keys'"

  logr task "enabling password authentication" \
    -- set_sshd_config \
    'ChallengeResponseAuthentication=yes' \
    'PasswordAuthentication=yes'
}

# Fixes SSH permissions for the specified user and group.
# Arguments:
#   1 - name of the user
#   2 - name of the group
fix_ssh_permissions() {
  local -r user="${1:?user missing}"
  local -r group="${2:?group missing}"
  local ssh_dir="/home/$user/.ssh"

  [ -d "$ssh_dir" ] || return 0

  logr task "changing ownership of $ssh_dir to $user:$group" \
    -- chown -R "$user:$group" "$ssh_dir"
  logr task "changing permissions of $ssh_dir to 0700" \
    -- chmod -R 0700 "$ssh_dir"
  for key_file in "/home/${user}/.ssh/key_file_"*; do
    if [ -f "${key_file}" ]; then
      logr task "changing permissions of private key $key_file to 0600" -- chmod -R 0600 "$key_file"
    fi
  done
  for pub_key_file in "$ssh_dir/"*.pub; do
    if [ -f "$pub_key_file" ]; then
      logr task "changing permissions of public key $pub_key_file to 0644" -- chmod -R 0644 "${pub_key_file}"
    fi
  done
}

# Starts supervisord and waits for the given processes to start.
# The actual service configuration is located at /etc/supervisor/supervisord.conf.
# Arguments:
#   * - processes to wait for
# Return:
#   PID of the supervisord process
start_processes() {
  /usr/bin/supervisord \
    --nodaemon \
    --pidfile=/var/run/supervisord.pid \
    --configuration /etc/supervisor/supervisord.conf \
    &>/dev/null &

  for process in "$@"; do
    logr task "waiting for $process" -- wait_for_process "$process"
  done
}

# Waits for the specified process.
# Arguments:
#   1 - name of the process
#   2 - max time to wait in seconds (default: 30)
# Returns:
#   0 - process started in time
#   1 - process failed to start in time
wait_for_process() {
  local -r process_name="$1"
  local -r -i max_time_wait="${2:-30}"
  local waited_sec=0
  while ! pgrep "$process_name" >/dev/null; do
    logr info "waiting $((max_time_wait - waited_sec))s for process ${process_name}"
    sleep 1
    waited_sec=$((waited_sec + 1))
    [ "$waited_sec" -lt "$max_time_wait" ] || logr fail "$process_name did not start in time"
  done
  logr info "$process_name is running"
}

# Keeps the container alive by waiting for supervisord to finish.
# Arguments:
#  None
run_as_service() {
  local -r -i pid="$(cat /var/run/supervisord.pid)"
  while [ -e "/proc/$pid" ]; do
    sleep 1
  done
}

# Entrypoint for this container that updates system settings
# in order to reflect the configuration made by environment variables.
# Arguments:
#   * - Runs the passed arguments as a command line with dropped permissions.
#       If no arguments were passed runs as a service.
main() {
  local -r uid=${PUID:-1000} gid=${PGID:-1000} user=runner group=runner timezone=${TZ:-UTC}
  local -a -r processes=("sshd")

  logr task "updating ID of group $group to $gid" -- update_group_id "$group" "$gid"
  logr task "updating ID of user $user to $uid" -- update_user_id "$user" "$uid"
  logr task "updating timezone to $timezone" -- update_timezone "$timezone"

  if [ "${AUTHORIZED_KEYS-}" ]; then
    logr task "switching to SSH public key authentication" -- use_ssh_public_key_authentication "$user" "$AUTHORIZED_KEYS"
  elif [ "${PASSWORD-}" ]; then
    logr task "switching to SSH password authentication" -- use_ssh_password_authentication "$user" "$PASSWORD"
    # bashsupport disable=BP2001,BP5006
    unset PASSWORD && export -n PASSWORD
  fi
  logr task "disabling password authentication for user root" -- set_sshd_config 'PermitRootLogin=prohibit-password'

  logr task "fixing permissions of stdout and stderr" -- fix_std_permissions
  logr task "fixing permissions of home directory for $user" -- fix_home_permissions "$user"
  logr task "fixing permissions of .ssh directory for $user" -- fix_ssh_permissions "$user" "$group"

  if [ "${#@}" -gt 0 ]; then
    logr info "changing to $user:$group"
    util cursor show
    yasu "$user:$group" entrypoint_user.sh "$@"
  else
    #    logr task "starting processes: ${processes[*]}" -- start_processes "${processes[@]}"
    start_processes "${processes[@]}"
    logr info "running as service"
    run_as_service
  fi
}

main "$@"
