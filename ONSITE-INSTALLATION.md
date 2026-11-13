# On-site installation

Perform this only when physically connected to the AZ Tires Q20 management network and after the Firebase setup is complete.

Before leaving for the site, pack and check every essential item in `FIELD-KIT-CHECKLIST.md`.

## What to connect to the laptop

Use this physical layout:

```text
Upstream internet router LAN port  --->  Q20 WAN port
Laptop Ethernet/USB-Ethernet       --->  Q20 LAN port
Q20 12 V / 1 A adapter             --->  Q20 power input
Stable 5 V USB charger             --->  ESP32 USB power
```

Important:

- Connect the laptop to a **Q20 LAN** port, not its WAN port.
- The laptop may keep its WiFi connected to the upstream router for internet while Ethernet is used only to manage the Q20.
- The ESP32 does not need a laptop USB connection for the Firebase installation. Use laptop USB only for serial diagnosis or intentional firmware flashing.
- Never connect the 12 V coin supply to a USB port or an ESP32 GPIO.
- Keep the known optocoupler output wiring: `VCC -> ESP32 3V3`, `GND -> ESP32 GND`, `OUT -> GPIO27`.

First try Ethernet with its normal automatic/DHCP setting. If the laptop does not receive a Q20 management address or loses internet because Ethernet becomes the default route, open the laptop's wired-network settings and set:

- IPv4 method: **Manual**
- Address: `192.168.1.10`
- Netmask/prefix: `255.255.255.0` or `/24`
- Gateway: leave blank
- DNS: leave blank
- Enable **Use this connection only for resources on its network**, **Never use as default route**, or the equivalent option

Keep WiFi connected for the laptop's normal internet route. Then verify:

```sh
ip -br address
ip route
ping -c 3 192.168.1.1
```

If `192.168.1.10` is already used, have Codex inspect the network and select another unused address in `192.168.1.0/24`; do not guess over an active device.

## Safety and preservation rules

- Do not factory-reset or reflash the Q20.
- Do not reflash the ESP32 merely for Firebase monitoring.
- Do not expose LuCI, SSH, or `/piso-admin/` through WAN, port forwarding, or a tunnel.
- Back up the current Q20 configuration and confirm the local Piso WiFi still works before changing anything.
- Never type a password into a command that will be saved in shell history.

## 1. Preflight

From the on-site PC connected to a Q20 LAN port:

```sh
ping -c 3 192.168.1.1
ssh root@192.168.1.1
```

On the Q20, confirm internet and correct time:

```sh
date
ping -c 3 8.8.8.8
nslookup identitytoolkit.googleapis.com
```

Before continuing, verify locally:

- `http://192.168.1.1/piso-admin/` opens;
- the customer captive portal opens;
- the ESP32 controller is online when powered;
- current revenue, sessions, vouchers, and configuration are intact.

Create a fresh recoverable Q20 backup using LuCI **System > Backup / Flash Firmware** and save it to the on-site PC.

## 2. Copy the Firebase Q20 files

On the PC, change into this package and run:

```sh
scp -r firebase/q20 root@192.168.1.1:/root/az-tires-firebase
ssh root@192.168.1.1
```

On the Q20:

```sh
chmod +x /root/az-tires-firebase/az-tires-firebase-sync
chmod +x /root/az-tires-firebase/install.sh
chmod +x /root/az-tires-firebase/uninstall.sh
cp /root/az-tires-firebase/az-tires-firebase.conf.example /etc/az-tires-firebase.conf
chmod 600 /etc/az-tires-firebase.conf
vi /etc/az-tires-firebase.conf
```

In `vi`, enter the public API key, exact Realtime Database URL, dedicated Q20 device email, and its password. Do not use the owner account here.

## 3. Test before enabling the minute job

```sh
/root/az-tires-firebase/az-tires-firebase-sync test-auth
/root/az-tires-firebase/az-tires-firebase-sync show-telemetry
```

`test-auth` must show the same device UID configured in `dashboard/config.js`. `show-telemetry` must return valid JSON containing the existing local owner summary. If either fails, stop and correct that problem; do not reset or flash anything.

## 4. Install and verify

```sh
sh /root/az-tires-firebase/install.sh
/usr/bin/az-tires-firebase-sync sync
tail -n 50 /tmp/az-tires-firebase.log
```

Open the remote dashboard, sign in with the owner account, and confirm:

- Q20 shows online within two minutes;
- totals match the local owner dashboard;
- connected/authenticated counts are plausible;
- controller status matches the hardware;
- no password appears in page source, logs, or the portable package.

Change one harmless setting, such as the coin window from 30 to 31 seconds, wait up to two minutes, verify `applied`, then restore it to 30. Re-test one real coin transaction and one customer login locally.

## 5. Apply the AZ Tires names and light interface

Do this over the laptop's Ethernet connection after Firebase and the existing Piso WiFi have passed their tests. Customer devices will disconnect once and must join the new SSID. The hidden controller SSID also changes to `AZ-Tires-Controller`, so flash the matching ESP32 firmware immediately before applying the Q20 update.

From the laptop, copy the prepared router files:

```sh
scp -r router root@192.168.1.1:/tmp/az-tires-router
ssh root@192.168.1.1
```

On the Q20, save the exact files that will change and the current data/configuration:

```sh
mkdir -p /root/az-tires-backups/pre-az-tires-name/www
cp /etc/config/wireless /root/az-tires-backups/pre-az-tires-name/wireless
cp /etc/config/opennds /root/az-tires-backups/pre-az-tires-name/opennds
tar -czf /root/az-tires-backups/pre-az-tires-name/www-piso.tar.gz /www/piso /www/piso-admin /www/cgi-bin/piso-admin-api
```

With coin-acceptor power off, build and upload `esp8266/AZTiresCoinController` using the ESP32 command in `README.md`. Its `secrets.h` must contain the existing controller WiFi key and device API key. Do not paste those values into chat or commit them to the portable package. The newly flashed ESP32 will remain temporarily offline until the next command updates the Q20.

Apply the prepared portal, light dashboards, data-path migration, customer SSIDs, and hidden controller SSID:

```sh
sh /tmp/az-tires-router/update-live.sh
```

Reconnect a phone to `AZ Tires Piso WiFi`, verify the white AZ Tires portal, and confirm the controller returns online on `AZ-Tires-Controller`. Then perform one real coin transaction and confirm the local and Firebase owner dashboards still agree. If the controller stays offline, verify the ESP32 firmware, SSID, WiFi key, and stable 5 V power before proceeding.

## 6. Rollback

If Firebase causes any issue:

```sh
sh /root/az-tires-firebase/uninstall.sh
```

This removes the scheduled sync but deliberately keeps `/etc/az-tires-firebase.conf` for recoverability. Disable the Q20 device account in Firebase Authentication if the installation is abandoned. Delete the local credential file only after that account is disabled.

To roll back only the AZ Tires public-name change, restore the files saved under `/root/az-tires-backups/pre-az-tires-name`, extract `www-piso.tar.gz` at `/`, then reload WiFi and restart openNDS/uhttpd. Confirm the actual backup files exist before restoring them.
