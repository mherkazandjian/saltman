#!/usr/bin/env bash
set -e

# .. todo:: maybe do this via ansible here?
# add the admin user that has a home directory /admin
if ! id -u admin &>/dev/null; then
    useradd -m admin -s /bin/bash -d /admin
    chown -Rc admin:admin /admin

    # if the ssh key does not exist, generate it
    if [ ! -f /admin/.ssh/id_ed25519 ]; then
        su - admin -c "ssh-keygen -t ed25519 -C 'admin key' -f ~/.ssh/id_ed25519 -b 2048 -P '' -q"
    fi

    # add the public key to the authorized_keys file
    touch /admin/.ssh/authorized_keys
    chown admin:admin /admin/.ssh/authorized_keys
    chmod 644 /admin/.ssh/authorized_keys

    # if the environment variable SSH_PUBLIC_KEY is set, add it to the authorized_keys file
    if [ -z "$ADMIN_SSH_PUBLIC_KEY" ]; then
        echo "SALTMAN ERROR: No SSH public key provided for the admin user."
        exit 1
    fi
    if [ -n "$ADMIN_SSH_PUBLIC_KEY" ]; then
        echo "$ADMIN_SSH_PUBLIC_KEY" >> /admin/.ssh/authorized_keys
    fi
fi

# add the admin user that has also passwordless sudo access
# if the admin user is not in the sudoers file add it
if ! grep -q "^admin" /etc/sudoers; then
    echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

echo "start init"
#touch /admin/`date +%s`

exec /usr/sbin/init