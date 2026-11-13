#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT INT TERM

export AZ_TIRES_CONFIG=/dev/null
export AZ_TIRES_STATE_DIR="$TEST_ROOT/state"
export AZ_TIRES_DATA_DIR="$TEST_ROOT/data"
export AZ_TIRES_NDSCTL="$ROOT/tests/fake-ndsctl.sh"
export TEST_MODE=0 WAIT_SECONDS=30 DEVICE_KEY=test-key
export PESO_1_SECONDS=600 PESO_5_SECONDS=3600 PESO_10_SECONDS=7200 PESO_20_SECONDS=14400
export VOUCHER_30_SECONDS=2592000 VOUCHER_60_SECONDS=5184000
export VOUCHER_30_PRICE=200 VOUCHER_60_PRICE=400

run_customer() {
	REMOTE_ADDR="$1" REQUEST_METHOD=GET CONTENT_LENGTH=0 QUERY_STRING="$2" \
		"$ROOT/router/www/cgi-bin/api" | tail -n 1
}

run_admin() {
	REQUEST_METHOD="$1" CONTENT_LENGTH=0 QUERY_STRING="$2" \
		"$ROOT/router/admin/cgi-bin/api" | tail -n 1
}

# Browser URLSearchParams encodes MAC colons. The CGI must decode the value,
# otherwise voucher binding and session lookup silently break.
CUSTOMER_ENCODED='clientip=10.10.0.60&clientmac=02%3A00%3A00%3A00%3A00%3A60&tok=customer%2Dtoken'
run_customer 10.10.0.60 "action=wait&$CUSTOMER_ENCODED" | grep -q '"pesos":0'
[ "$(sed -n '3p' "$TEST_ROOT/state/waiting")" = '02:00:00:00:00:60' ]
[ "$(sed -n '4p' "$TEST_ROOT/state/waiting")" = 'customer-token' ]

# Only one customer can own the physical coin acceptor at a time.
OTHER='clientip=10.10.0.61&clientmac=02%3A00%3A00%3A00%3A00%3A61&tok=other'
run_customer 10.10.0.61 "action=wait&$OTHER" | grep -q 'Another customer is using the coin slot.'

# Controller calls require both the secret key and isolated controller subnet.
run_customer 10.20.0.2 'action=coin&key=wrong&event_id=wrong-key&pesos=5' | grep -q 'Controller authentication failed.'
run_customer 10.10.0.99 'action=coin&key=test-key&event_id=wrong-net&pesos=5' | grep -q 'Controller network required.'

# A valid event is accepted once; retrying the same event is idempotent.
run_customer 10.20.0.2 'action=coin&key=test-key&event_id=event-five&pesos=5&raw_pulses=5' | grep -q '"window_pesos":5'
run_customer 10.20.0.2 'action=coin&key=test-key&event_id=event-five&pesos=5&raw_pulses=5' | grep -q '"duplicate":true'
[ "$(grep -c '|coin|5|' "$TEST_ROOT/data/transactions.log")" = 1 ]

# Finish, pause, and resume preserve the purchased time and decoded MAC.
run_customer 10.10.0.60 "action=finish_coin&$CUSTOMER_ENCODED" | grep -q '"status":"active"'
SESSION="$TEST_ROOT/data/sessions/02_00_00_00_00_60"
[ -r "$SESSION" ]
[ "$(sed -n '3p' "$SESSION")" = '02:00:00:00:00:60' ]
[ "$(sed -n '5p' "$SESSION")" = 5 ]
run_customer 10.10.0.60 "action=pause&$CUSTOMER_ENCODED" | grep -q '"status":"paused"'
run_customer 10.10.0.60 "action=resume&$CUSTOMER_ENCODED" | grep -q '"status":"active"'
run_customer 10.10.0.99 "action=status&$CUSTOMER_ENCODED" | grep -q 'Device address mismatch.'

# Owner creates a voucher, which binds to exactly one device on first use.
VOUCHER_JSON="$(run_admin POST 'action=create_voucher&plan=30')"
printf '%s' "$VOUCHER_JSON" | grep -q '"price":200'
CODE="$(printf '%s' "$VOUCHER_JSON" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')"
case "$CODE" in AZT??????????) ;; *) printf 'Invalid voucher code: %s\n' "$CODE" >&2; exit 1 ;; esac

VOUCHER_CLIENT='clientip=10.10.0.70&clientmac=02%3A00%3A00%3A00%3A00%3A70&tok=voucher'
run_customer 10.10.0.70 "action=redeem_voucher&code=$CODE&$VOUCHER_CLIENT" | grep -q 'Voucher activated for this device.'
[ "$(sed -n '5p' "$TEST_ROOT/data/vouchers/$CODE")" = '02:00:00:00:00:70' ]
[ "$(grep -c '|voucher|200|' "$TEST_ROOT/data/transactions.log")" = 1 ]

# Same device may reconnect without charging again; another device is denied.
run_customer 10.10.0.70 "action=redeem_voucher&code=$CODE&$VOUCHER_CLIENT" | grep -q 'Voucher activated for this device.'
[ "$(grep -c '|voucher|200|' "$TEST_ROOT/data/transactions.log")" = 1 ]
run_customer 10.10.0.71 "action=redeem_voucher&code=$CODE&clientip=10.10.0.71&clientmac=02%3A00%3A00%3A00%3A00%3A71" | grep -q 'already linked to another device'
grep -q '|voucher-device-mismatch|' "$TEST_ROOT/data/alerts.log"

# Admin totals and listings must reflect the production data files.
SUMMARY="$(run_admin GET 'action=summary')"
printf '%s' "$SUMMARY" | grep -q '"total":205'
printf '%s' "$SUMMARY" | grep -q "\"code\":\"$CODE\""
printf '%s' "$SUMMARY" | grep -q '"alert_count":3'
printf '%s' "$SUMMARY" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s);if(!v.ok||v.earnings.total!==205||v.vouchers.length!==1)process.exit(1);});'

# Interrupted temporary files and a damaged voucher must not corrupt the JSON
# owner dashboard; the customer gets a clear owner-facing error instead.
printf 'partial\n' > "$TEST_ROOT/data/vouchers/AZTEMP.tmp.123"
printf 'broken\n200\n1\nnew\n\n0\n0\n\n' > "$TEST_ROOT/data/vouchers/AZTBROKEN000"
run_customer 10.10.0.70 "action=redeem_voucher&code=AZTBROKEN000&$VOUCHER_CLIENT" | grep -q 'Voucher data is damaged.'
run_admin GET 'action=summary' | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s);if(!v.ok||v.vouchers.some(x=>x.code.includes(".tmp.")))process.exit(1);});'

printf 'PASS: encoded MACs, exclusive coin window, controller security, duplicate events, pause/resume, vouchers, and admin totals\n'
