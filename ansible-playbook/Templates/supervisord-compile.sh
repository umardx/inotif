#!/bin/sh
cd /usr/ports/sysutils/py-supervisor
# Compile default option.
make install clean BATCH=YES
# Append `inotif_enable="YES"` if not exist.
grep -q -F 'inotif_enable="YES"' /etc/rc.conf || echo 'inotif_enable="YES"' >> /etc/rc.conf
