#!/bin/sh
set -eu

STAGE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

[ -r "$STAGE/www/index.html" ]
[ -r "$STAGE/www/cgi-bin/api" ]
[ -r "$STAGE/admin/index.html" ]
[ -r "$STAGE/admin/cgi-bin/api" ]

CONFIG=/etc/az-tires-piso.conf
DATA_DIR=/etc/az-tires-piso-data

# Preserve the existing deployment without retaining its previous brand name
# in this source tree. The glob finds the single older Piso configuration.
if [ ! -r "$CONFIG" ]; then
	for candidate in /etc/*-piso.conf; do
		[ -r "$candidate" ] || continue
		[ "$candidate" = "$CONFIG" ] && continue
		cp "$candidate" "$CONFIG"
		break
	done
fi
[ -r "$CONFIG" ] || { echo "Existing Piso WiFi configuration was not found." >&2; exit 1; }

legacy_data=''
if [ ! -d "$DATA_DIR" ]; then
	for candidate in /etc/*-piso-data; do
		[ -d "$candidate" ] || continue
		[ "$candidate" = "$DATA_DIR" ] && continue
		legacy_data="$candidate"
		break
	done
fi

mkdir -p /www/piso/cgi-bin /www/piso-admin /www/cgi-bin
for old_logo in /www/piso/*-logo.png; do [ -f "$old_logo" ] && rm -f "$old_logo"; done
cp "$STAGE/www/index.html" /www/piso/index.html
cp "$STAGE/www/styles.css" /www/piso/styles.css
cp "$STAGE/www/app.js" /www/piso/app.js
cp "$STAGE/www/cgi-bin/api" /www/piso/cgi-bin/api
cp "$STAGE/admin/index.html" /www/piso-admin/index.html
cp "$STAGE/admin/styles.css" /www/piso-admin/styles.css
cp "$STAGE/admin/app.js" /www/piso-admin/app.js
cp "$STAGE/admin/cgi-bin/api" /www/cgi-bin/piso-admin-api

chmod 0755 /www/piso /www/piso/cgi-bin /www/piso/cgi-bin/api
chmod 0755 /www/piso-admin /www/cgi-bin/piso-admin-api
chmod 0644 /www/piso/index.html /www/piso/styles.css /www/piso/app.js
chmod 0644 /www/piso-admin/index.html /www/piso-admin/styles.css /www/piso-admin/app.js

mkdir -p "$DATA_DIR/sessions" "$DATA_DIR/vouchers"
if [ -n "$legacy_data" ]; then cp -a "$legacy_data/." "$DATA_DIR/"; fi
chmod 0700 "$DATA_DIR" "$DATA_DIR/sessions" "$DATA_DIR/vouchers"

if ! grep -q '^VOUCHER_30_SECONDS=' "$CONFIG"; then
	{
		printf "VOUCHER_30_SECONDS='2592000'\n"
		printf "VOUCHER_60_SECONDS='5184000'\n"
		printf "VOUCHER_30_PRICE='200'\n"
		printf "VOUCHER_60_PRICE='400'\n"
	} >> "$CONFIG"
fi
chmod 0600 "$CONFIG"

rm -f /www/piso-admin/cgi-bin/api
rmdir /www/piso-admin/cgi-bin 2>/dev/null || true

uci -q delete uhttpd.main.httpauth || true
uci -q delete uhttpd.piso_admin_page || true
uci -q delete uhttpd.piso_admin_api || true
uci set uhttpd.piso_admin_page='httpauth'
uci set uhttpd.piso_admin_page.prefix='/piso-admin'
uci set uhttpd.piso_admin_page.username='root'
uci set 'uhttpd.piso_admin_page.password=$p$root'
uci set uhttpd.piso_admin_api='httpauth'
uci set uhttpd.piso_admin_api.prefix='/cgi-bin/piso-admin-api'
uci set uhttpd.piso_admin_api.username='root'
uci set 'uhttpd.piso_admin_api.password=$p$root'
uci add_list uhttpd.main.httpauth='piso_admin_page'
uci add_list uhttpd.main.httpauth='piso_admin_api'
uci commit uhttpd

uci set system.@system[0].hostname='AZ-Tires-Piso'
uci set wireless.piso2g.ssid='AZ Tires Piso WiFi'
uci set wireless.piso5g.ssid='AZ Tires Piso WiFi 5G'
uci set wireless.controller.ssid='AZ-Tires-Controller'
uci set opennds.@opennds[0].gatewayname='AZ Tires Piso WiFi'
uci set opennds.@opennds[0].gatewayfqdn='login.aztires'
uci -q set firewall.piso_dns.name='AZ-Tires-Piso-DNS'
uci -q set firewall.piso_dhcp.name='AZ-Tires-Piso-DHCP'
uci -q set firewall.piso_fas.name='AZ-Tires-Piso-Portal'
uci -q set firewall.controller_dhcp.name='AZ-Tires-Controller-DHCP'
uci -q set firewall.controller_api.name='AZ-Tires-Controller-API'
uci commit system
uci commit wireless
uci commit opennds
uci commit firewall

/etc/init.d/uhttpd restart
wifi reload
/etc/init.d/opennds restart

printf 'AZ Tires portal, dashboards, data paths, and WiFi names updated.\n'
