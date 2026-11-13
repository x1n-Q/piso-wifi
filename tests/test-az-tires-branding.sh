#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
old_brand='dan''trix'

if find "$ROOT" \
  -path "$ROOT/tools" -prune -o \
  -path "$ROOT/packages" -prune -o \
  -path "$ROOT/router-backups" -prune -o \
  -path "$ROOT/esp32/backups" -prune -o \
  -path "$ROOT/deployment-secrets" -prune -o \
  -path '*/build' -prune -o \
  -iname "*$old_brand*" -print | grep -q .; then
  echo "Old brand remains in an active path." >&2
  exit 1
fi

if find "$ROOT" -type f \
  -not -path "$ROOT/tools/*" \
  -not -path "$ROOT/packages/*" \
  -not -path "$ROOT/router-backups/*" \
  -not -path "$ROOT/esp32/backups/*" \
  -not -path "$ROOT/deployment-secrets/*" \
  -not -path '*/build/*' \
  -not -name 'secrets.h' \
  -not -name '*.bin' \
  -not -name '*.png' \
  -exec grep -IlEi "$old_brand" {} + | grep -q .; then
  echo "Old brand remains in active source content." >&2
  exit 1
fi

grep -Fq "set wireless.piso2g.ssid='AZ Tires Piso WiFi'" "$ROOT/router/install.sh"
grep -Fq "set wireless.piso5g.ssid='AZ Tires Piso WiFi 5G'" "$ROOT/router/install.sh"
grep -Fq "set wireless.controller.ssid='AZ-Tires-Controller'" "$ROOT/router/install.sh"
grep -Fq 'const char* WIFI_SSID = "AZ-Tires-Controller";' "$ROOT/esp8266/AZTiresCoinController/AZTiresCoinController.ino"
grep -Fq 'safeOriginUrl' "$ROOT/router/www/app.js"
grep -Fq 'url.protocol === "http:" || url.protocol === "https:"' "$ROOT/router/www/app.js"
grep -Fq -- '--page: #f4f7fb' "$ROOT/router/www/styles.css"
grep -Fq -- '--page: #f4f7fb' "$ROOT/router/admin/styles.css"
grep -Fq -- '--page: #f4f7fb' "$ROOT/firebase/dashboard/styles.css"

printf '%s\n' 'PASS: AZ Tires naming, SSIDs, redirect validation, and light themes verified'
