#!/bin/sh

set -eu

SOURCE_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

command -v curl >/dev/null 2>&1 || {
	echo "Installing HTTPS client and CA certificates..."
	opkg update
	opkg install curl ca-bundle
}

cp "$SOURCE_DIR/az-tires-firebase-sync" /usr/bin/az-tires-firebase-sync
chmod 0755 /usr/bin/az-tires-firebase-sync

if [ ! -e /etc/az-tires-firebase.conf ]; then
	cp "$SOURCE_DIR/az-tires-firebase.conf.example" /etc/az-tires-firebase.conf
	chmod 0600 /etc/az-tires-firebase.conf
	echo "Created /etc/az-tires-firebase.conf. Fill in the Firebase values, then rerun this installer."
	exit 2
fi

chmod 600 /etc/az-tires-firebase.conf
mkdir -p /etc/az-tires-firebase-state
chmod 700 /etc/az-tires-firebase-state
mkdir -p /etc/crontabs
[ -e /etc/crontabs/root ] || : > /etc/crontabs/root

sed -i '\|/usr/bin/az-tires-firebase-sync sync|d' /etc/crontabs/root
printf '%s\n' '*/1 * * * * /usr/bin/az-tires-firebase-sync sync >>/tmp/az-tires-firebase.log 2>&1' >> /etc/crontabs/root
/etc/init.d/cron restart

/usr/bin/az-tires-firebase-sync test-auth
/usr/bin/az-tires-firebase-sync sync

echo "AZ Tires Firebase monitoring installed. Sync runs once per minute."
