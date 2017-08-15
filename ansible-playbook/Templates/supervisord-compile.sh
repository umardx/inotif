#!/bin/sh
cd /usr/ports/sysutils/py-supervisor
# Compile default option.
make install clean BATCH=yes
# Append `inotif_enable="YES"` if not exist.
grep -q -F 'inotif_enable="YES"' /usr/local/etc/supervisord.conf || echo 'inotif_enable="YES"' >> /usr/local/etc/supervisord.conf

