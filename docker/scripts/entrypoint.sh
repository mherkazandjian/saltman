#!/usr/bin/env bash
set -e

# add the admin user that has a home directory /admin
useradd -m admin -s /bin/bash -G sudo -d /admin

# add the admin user that has also passwordless sudo access
echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "asdasdasd"

exec /usr/sbin/init