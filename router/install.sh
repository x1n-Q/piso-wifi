#!/bin/sh
set -eu

CONTROLLER_WIFI_KEY="$(head -c 32 /dev/urandom | sha256sum | cut -c1-32)"
DEVICE_KEY="$(head -c 48 /dev/urandom | sha256sum | cut -c1-48)"

mkdir -p /www/piso/cgi-bin
mkdir -p /www/piso-admin /www/cgi-bin
for old_logo in /www/piso/*-logo.png; do [ -f "$old_logo" ] && rm -f "$old_logo"; done
cp /tmp/az-tires-install/www/index.html /www/piso/index.html
cp /tmp/az-tires-install/www/styles.css /www/piso/styles.css
cp /tmp/az-tires-install/www/app.js /www/piso/app.js
cp /tmp/az-tires-install/www/cgi-bin/api /www/piso/cgi-bin/api
cp /tmp/az-tires-install/admin/index.html /www/piso-admin/index.html
cp /tmp/az-tires-install/admin/styles.css /www/piso-admin/styles.css
cp /tmp/az-tires-install/admin/app.js /www/piso-admin/app.js
cp /tmp/az-tires-install/admin/cgi-bin/api /www/cgi-bin/piso-admin-api
chmod 0755 /www/piso /www/piso/cgi-bin /www/piso/cgi-bin/api
chmod 0755 /www/piso-admin /www/cgi-bin/piso-admin-api
chmod 0644 /www/piso/index.html /www/piso/styles.css /www/piso/app.js
chmod 0644 /www/piso-admin/index.html /www/piso-admin/styles.css /www/piso-admin/app.js

mkdir -p /etc/az-tires-piso-data/sessions /etc/az-tires-piso-data/vouchers
chmod 0700 /etc/az-tires-piso-data /etc/az-tires-piso-data/sessions /etc/az-tires-piso-data/vouchers

umask 077
{
	printf "TEST_MODE='0'\n"
	printf "WAIT_SECONDS='30'\n"
	printf "UPLOAD_KBPS='2048'\n"
	printf "DOWNLOAD_KBPS='5120'\n"
	printf "PESO_1_SECONDS='600'\n"
	printf "PESO_5_SECONDS='3600'\n"
	printf "PESO_10_SECONDS='7200'\n"
	printf "PESO_20_SECONDS='14400'\n"
	printf "VOUCHER_30_SECONDS='2592000'\n"
	printf "VOUCHER_60_SECONDS='5184000'\n"
	printf "VOUCHER_30_PRICE='200'\n"
	printf "VOUCHER_60_PRICE='400'\n"
	printf "CONTROLLER_WIFI_KEY='%s'\n" "$CONTROLLER_WIFI_KEY"
	printf "DEVICE_KEY='%s'\n" "$DEVICE_KEY"
} > /etc/az-tires-piso.conf

uci -q batch <<EOF
set system.@system[0].hostname='AZ-Tires-Piso'
set system.@system[0].zonename='Asia/Manila'
set system.@system[0].timezone='PST-8'

delete network.br_piso
set network.br_piso='device'
set network.br_piso.name='br-piso'
set network.br_piso.type='bridge'
delete network.piso
set network.piso='interface'
set network.piso.device='br-piso'
set network.piso.proto='static'
set network.piso.ipaddr='10.10.0.1'
set network.piso.netmask='255.255.255.0'

delete network.br_controller
set network.br_controller='device'
set network.br_controller.name='br-controller'
set network.br_controller.type='bridge'
delete network.controller
set network.controller='interface'
set network.controller.device='br-controller'
set network.controller.proto='static'
set network.controller.ipaddr='10.20.0.1'
set network.controller.netmask='255.255.255.0'

delete dhcp.piso
set dhcp.piso='dhcp'
set dhcp.piso.interface='piso'
set dhcp.piso.start='100'
set dhcp.piso.limit='100'
set dhcp.piso.leasetime='2h'
delete dhcp.controller
set dhcp.controller='dhcp'
set dhcp.controller.interface='controller'
set dhcp.controller.start='100'
set dhcp.controller.limit='20'
set dhcp.controller.leasetime='12h'

delete firewall.piso
set firewall.piso='zone'
set firewall.piso.name='piso'
add_list firewall.piso.network='piso'
set firewall.piso.input='REJECT'
set firewall.piso.output='ACCEPT'
set firewall.piso.forward='REJECT'
delete firewall.piso_wan
set firewall.piso_wan='forwarding'
set firewall.piso_wan.src='piso'
set firewall.piso_wan.dest='wan'
delete firewall.piso_dns
set firewall.piso_dns='rule'
set firewall.piso_dns.name='AZ-Tires-Piso-DNS'
set firewall.piso_dns.src='piso'
set firewall.piso_dns.proto='tcp udp'
set firewall.piso_dns.dest_port='53'
set firewall.piso_dns.target='ACCEPT'
delete firewall.piso_dhcp
set firewall.piso_dhcp='rule'
set firewall.piso_dhcp.name='AZ-Tires-Piso-DHCP'
set firewall.piso_dhcp.src='piso'
set firewall.piso_dhcp.proto='udp'
set firewall.piso_dhcp.dest_port='67'
set firewall.piso_dhcp.target='ACCEPT'
delete firewall.piso_fas
set firewall.piso_fas='rule'
set firewall.piso_fas.name='AZ-Tires-Piso-Portal'
set firewall.piso_fas.src='piso'
set firewall.piso_fas.proto='tcp'
set firewall.piso_fas.dest_port='2080'
set firewall.piso_fas.target='ACCEPT'

delete firewall.controller
set firewall.controller='zone'
set firewall.controller.name='controller'
add_list firewall.controller.network='controller'
set firewall.controller.input='REJECT'
set firewall.controller.output='ACCEPT'
set firewall.controller.forward='REJECT'
delete firewall.controller_dhcp
set firewall.controller_dhcp='rule'
set firewall.controller_dhcp.name='AZ-Tires-Controller-DHCP'
set firewall.controller_dhcp.src='controller'
set firewall.controller_dhcp.proto='udp'
set firewall.controller_dhcp.dest_port='67'
set firewall.controller_dhcp.target='ACCEPT'
delete firewall.controller_api
set firewall.controller_api='rule'
set firewall.controller_api.name='AZ-Tires-Controller-API'
set firewall.controller_api.src='controller'
set firewall.controller_api.proto='tcp'
set firewall.controller_api.dest_port='2080'
set firewall.controller_api.target='ACCEPT'

delete wireless.@wifi-iface[1]
delete wireless.@wifi-iface[0]
set wireless.radio0.country='PH'
set wireless.radio0.channel='6'
set wireless.radio0.htmode='HE20'
set wireless.radio0.disabled='0'
set wireless.radio1.country='PH'
set wireless.radio1.channel='36'
set wireless.radio1.htmode='HE80'
set wireless.radio1.disabled='0'
set wireless.piso2g='wifi-iface'
set wireless.piso2g.device='radio0'
set wireless.piso2g.network='piso'
set wireless.piso2g.mode='ap'
set wireless.piso2g.ssid='AZ Tires Piso WiFi'
set wireless.piso2g.encryption='none'
set wireless.piso2g.isolate='1'
set wireless.piso5g='wifi-iface'
set wireless.piso5g.device='radio1'
set wireless.piso5g.network='piso'
set wireless.piso5g.mode='ap'
set wireless.piso5g.ssid='AZ Tires Piso WiFi 5G'
set wireless.piso5g.encryption='none'
set wireless.piso5g.isolate='1'
set wireless.controller='wifi-iface'
set wireless.controller.device='radio0'
set wireless.controller.network='controller'
set wireless.controller.mode='ap'
set wireless.controller.ssid='AZ-Tires-Controller'
set wireless.controller.encryption='psk2'
set wireless.controller.key='$CONTROLLER_WIFI_KEY'
set wireless.controller.hidden='1'
set wireless.controller.isolate='1'

delete uhttpd.piso
set uhttpd.piso='uhttpd'
add_list uhttpd.piso.listen_http='10.10.0.1:2080'
add_list uhttpd.piso.listen_http='10.20.0.1:2080'
set uhttpd.piso.home='/www/piso'
set uhttpd.piso.cgi_prefix='/cgi-bin'
set uhttpd.piso.script_timeout='30'
set uhttpd.piso.network_timeout='15'
set uhttpd.piso.http_keepalive='10'
set uhttpd.piso.max_requests='5'
set uhttpd.piso.max_connections='60'

delete uhttpd.main.httpauth
delete uhttpd.piso_admin_page
set uhttpd.piso_admin_page='httpauth'
set uhttpd.piso_admin_page.prefix='/piso-admin'
set uhttpd.piso_admin_page.username='root'
set uhttpd.piso_admin_page.password='\$p\$root'
delete uhttpd.piso_admin_api
set uhttpd.piso_admin_api='httpauth'
set uhttpd.piso_admin_api.prefix='/cgi-bin/piso-admin-api'
set uhttpd.piso_admin_api.username='root'
set uhttpd.piso_admin_api.password='\$p\$root'
add_list uhttpd.main.httpauth='piso_admin_page'
add_list uhttpd.main.httpauth='piso_admin_api'

set opennds.@opennds[0].enabled='1'
set opennds.@opennds[0].gatewayinterface='br-piso'
set opennds.@opennds[0].gatewayname='AZ Tires Piso WiFi'
set opennds.@opennds[0].gatewayfqdn='login.aztires'
set opennds.@opennds[0].fasport='2080'
set opennds.@opennds[0].faspath='/'
set opennds.@opennds[0].fas_secure_enabled='0'
set opennds.@opennds[0].sessiontimeout='10'
set opennds.@opennds[0].uploadrate='2048'
set opennds.@opennds[0].downloadrate='5120'
set opennds.@opennds[0].maxclients='50'
set opennds.@opennds[0].debuglevel='1'
delete opennds.@opennds[0].users_to_router
add_list opennds.@opennds[0].users_to_router='allow udp port 53'
add_list opennds.@opennds[0].users_to_router='allow tcp port 53'
add_list opennds.@opennds[0].users_to_router='allow udp port 67'
add_list opennds.@opennds[0].users_to_router='allow tcp port 2080'
EOF

uci commit system
uci commit network
uci commit dhcp
uci commit firewall
uci commit wireless
uci commit uhttpd
uci commit opennds

/etc/init.d/system restart
/etc/init.d/network reload
sleep 5
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
/etc/init.d/uhttpd restart
/etc/init.d/opennds enable
/etc/init.d/opennds restart

printf 'AZ Tires Piso WiFi installed.\n'
printf 'Controller SSID: AZ-Tires-Controller\n'
printf 'Controller key: %s\n' "$CONTROLLER_WIFI_KEY"
printf 'ESP device key: %s\n' "$DEVICE_KEY"
