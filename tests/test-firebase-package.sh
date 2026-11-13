#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

sh -n "$ROOT/firebase/q20/az-tires-firebase-sync"
sh -n "$ROOT/firebase/q20/install.sh"
sh -n "$ROOT/firebase/q20/uninstall.sh"
node --check "$ROOT/firebase/dashboard/app.js"
node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(process.argv[1],"utf8"));' "$ROOT/firebase/database.rules.json"
node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(process.argv[1],"utf8"));' "$ROOT/firebase/initial-data.example.json"

printf '%s\n' \
	"FIREBASE_API_KEY='test-key'" \
	"FIREBASE_DATABASE_URL='https://example.invalid'" \
	"FIREBASE_DEVICE_EMAIL='device@example.invalid'" \
	"FIREBASE_DEVICE_PASSWORD='not-a-real-password'" \
	"SITE_NAME='Test AZ Tires Piso'" > "$TMP/firebase.conf"

printf '%s\n' \
	"WAIT_SECONDS='30'" \
	"UPLOAD_KBPS='2048'" \
	"DOWNLOAD_KBPS='5120'" \
	"PESO_1_SECONDS='600'" \
	"PESO_5_SECONDS='3600'" \
	"PESO_10_SECONDS='7200'" \
	"PESO_20_SECONDS='14400'" \
	"VOUCHER_30_PRICE='200'" \
	"VOUCHER_60_PRICE='400'" > "$TMP/piso.conf"

export PATH="$ROOT/tests/fixtures/firebase:$PATH"
export AZ_TIRES_FIREBASE_CONFIG="$TMP/firebase.conf"
export AZ_TIRES_FIREBASE_STATE="$TMP/state"
export AZ_TIRES_PISO_CONFIG="$TMP/piso.conf"
export AZ_TIRES_ADMIN_API="$ROOT/tests/fixtures/firebase/mock-admin-api"
export AZ_TIRES_FIREBASE_LOCK="$TMP/lock"

auth_output="$($ROOT/firebase/q20/az-tires-firebase-sync test-auth)"
case "$auth_output" in *'test-device-uid'*) ;; *) echo "Auth parser test failed" >&2; exit 1 ;; esac

telemetry="$($ROOT/firebase/q20/az-tires-firebase-sync show-telemetry)"
printf '%s' "$telemetry" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s);if(v.site_name!=="Test AZ Tires Piso"||v.earnings.today!==10||v.remote_config.wait_seconds!==30)process.exit(1);});'

$ROOT/firebase/q20/az-tires-firebase-sync sync

# A power loss can leave a lock directory behind. A stale lock must recover
# automatically instead of disabling all future remote monitoring.
mkdir -p "$AZ_TIRES_FIREBASE_LOCK"
printf '1\n' > "$AZ_TIRES_FIREBASE_LOCK/started"
$ROOT/firebase/q20/az-tires-firebase-sync sync
[ ! -e "$AZ_TIRES_FIREBASE_LOCK" ]
echo "Firebase package tests passed."
