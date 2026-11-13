# Copy this prompt into Codex at the Piso WiFi site

```text
You are working on the physical AZ Tires Piso WiFi installation. The portable package is on this computer. First locate and read, completely:

1. START-HERE-OFFLINE.md
2. README.md
3. firebase/FIREBASE-SETUP.md
4. ONSITE-INSTALLATION.md
5. FIELD-KIT-CHECKLIST.md
6. SECRETS-NOT-INCLUDED.md

Then inspect the package and validate the scripts before touching hardware. Follow ONSITE-INSTALLATION.md exactly.

The owner is bringing this laptop to the site. Help connect it as follows before making changes:
- upstream router LAN to Q20 WAN;
- laptop Ethernet or USB-Ethernet to a Q20 LAN port;
- keep laptop WiFi on the upstream router for internet;
- if Ethernet disrupts internet, configure an unused 192.168.1.0/24 address with no Ethernet gateway/DNS and mark Ethernet never-default;
- Q20 uses its own 12 V/1 A supply;
- ESP32 uses a stable 5 V USB charger and does not need laptop USB for Firebase;
- never connect 12 V to USB or GPIO.

Inspect `ip -br address` and `ip route`, then confirm both `192.168.1.1` and the public internet are reachable. Do not blindly create a second network profile if a correct one already exists.

Inventory the field kit before beginning. If the correct power supply, fused coin branch, known-good data/network cables, or insulated tools are missing, stop only the affected power/hardware work. Firebase configuration and read-only network checks may continue when safe.

Hard safety rules:
- Do not factory-reset or flash the JCG Q20.
- Do not reflash the ESP32 just to add Firebase monitoring. One coordinated ESP32 flash is allowed only for the documented hidden-SSID rename, after a current backup and preflight checks.
- Do not expose LuCI, SSH, the local owner dashboard, or any management port to WAN.
- Do not install Cloudflare Tunnel on the Q20.
- Do not copy passwords, Firebase service-account keys, voucher data, transaction logs, or router backups into the portable package, chat, source files, or command history.
- Ask the owner to enter the dedicated Firebase Q20 password locally into /etc/az-tires-firebase.conf.
- Preserve the existing portal, coin logic, sessions, vouchers, revenue, rates, WiFi, and firewall.
- Take a fresh Q20 configuration backup before mutation.
- If a preflight check fails, diagnose it without resetting or flashing.

Goal:
Install the outbound-only Firebase synchronization agent, verify authentication and telemetry, confirm the remote dashboard, flash the matching AZ Tires ESP32 controller firmware, then run the documented Q20 update that renames both customer SSIDs and the hidden controller SSID. Make one harmless settings round trip, restore the original value, and test the captive portal and one real coin transaction. Report exactly what changed, what was backed up, all test results, and the rollback path. Do not claim success unless the controller, deployed dashboard, and local Piso WiFi all pass.
```
