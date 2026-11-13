# Secrets and private data intentionally not included

The portable package must not contain:

- Q20 root/admin password
- WiFi/controller password
- Firebase owner password
- Firebase Q20 device password
- Firebase service-account JSON or private key
- `/etc/az-tires-firebase.conf` after it contains credentials
- ESP controller `secrets.h`
- Q20 configuration/firmware backups
- ESP32 pre-install flash backup
- live voucher database
- transaction or security-alert logs copied from the Q20

Public Firebase Web app configuration (`apiKey`, `authDomain`, `projectId`, and `databaseURL`) is safe to place in the static dashboard because access is controlled by Authentication and Database Rules. Passwords and service-account keys are not public configuration.

Use a password manager. Enter the Q20 device password only at the site and protect `/etc/az-tires-firebase.conf` with mode 600. If the flash drive is lost, no live account should be compromised by its contents.
