#!/bin/sh

set -eu

if [ -e /etc/crontabs/root ]; then
	sed -i '\|/usr/bin/az-tires-firebase-sync sync|d' /etc/crontabs/root
	/etc/init.d/cron restart
fi

rm -f /usr/bin/az-tires-firebase-sync
rm -rf /etc/az-tires-firebase-state

echo "Firebase sync has been removed."
echo "Credentials were kept at /etc/az-tires-firebase.conf so this is recoverable."
echo "Delete that file manually only if the device account has also been disabled in Firebase."
