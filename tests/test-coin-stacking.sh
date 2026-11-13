#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT INT TERM

export AZ_TIRES_CONFIG=/dev/null
export AZ_TIRES_STATE_DIR="$TEST_ROOT/state"
export AZ_TIRES_DATA_DIR="$TEST_ROOT/data"
export AZ_TIRES_NDSCTL="$ROOT/tests/fake-ndsctl.sh"
export TEST_MODE=1 WAIT_SECONDS=90 DEVICE_KEY=test-key
export PESO_1_SECONDS=600 PESO_5_SECONDS=3600 PESO_10_SECONDS=7200 PESO_20_SECONDS=14400

run_api() {
	REMOTE_ADDR="$1" REQUEST_METHOD=GET CONTENT_LENGTH=0 QUERY_STRING="$2" \
		"$ROOT/router/www/cgi-bin/api" | tail -n 1
}

CUSTOMER='clientip=10.10.0.50&clientmac=02:00:00:00:00:50&tok=test'
run_api 10.10.0.50 "action=wait&$CUSTOMER" | grep -q '"pesos":0'

SECOND_CUSTOMER='clientip=10.10.0.51&clientmac=02:00:00:00:00:51&tok=second'
run_api 10.10.0.51 "action=wait&$SECOND_CUSTOMER" | grep -q 'Another customer is using the coin slot.'

i=1
while [ "$i" -le 5 ]; do
	run_api 10.20.0.2 "action=coin&key=test-key&event_id=stack-$i&pesos=1" | grep -q "\"window_pesos\":$i"
	i=$((i + 1))
done

[ "$(sed -n '5p' "$TEST_ROOT/state/waiting")" = 5 ]
[ "$(wc -l < "$TEST_ROOT/data/transactions.log")" = 5 ]

# A false sixth edge from a P5 coin must never over-credit the customer.
run_api 10.20.0.2 'action=coin&key=test-key&event_id=noisy-5&pesos=6&raw_pulses=6' | grep -q '"accepted_pesos":5'
[ "$(sed -n '5p' "$TEST_ROOT/state/waiting")" = 10 ]

# A noisy 24-pulse P20 coin is normalized, then a later P20 still stacks after
# the running total has passed P25. There is no total-payment ceiling.
run_api 10.20.0.2 'action=coin&key=test-key&event_id=noisy-20&pesos=24&raw_pulses=24' | grep -q '"accepted_pesos":20'
run_api 10.20.0.2 'action=coin&key=test-key&event_id=after-25&pesos=20&raw_pulses=20' | grep -q '"window_pesos":50'
[ "$(sed -n '5p' "$TEST_ROOT/state/waiting")" = 50 ]
[ "$(wc -l < "$TEST_ROOT/data/transactions.log")" = 8 ]
run_api 10.20.0.2 'action=coin&key=test-key&event_id=ambiguous-14&pesos=14&raw_pulses=14' | grep -q 'Coin pulse signal was noisy and was rejected.'
[ "$(sed -n '5p' "$TEST_ROOT/state/waiting")" = 50 ]
grep -q '|ambiguous-pulse-batch|' "$TEST_ROOT/data/alerts.log"
SESSION_FILE="$TEST_ROOT/data/sessions/02_00_00_00_00_50"
[ ! -e "$SESSION_FILE" ]

run_api 10.10.0.50 "action=finish_coin&$CUSTOMER" | grep -q '"ok":true'
[ ! -e "$TEST_ROOT/state/waiting" ]
[ "$(sed -n '5p' "$SESSION_FILE")" = 50 ]
REMAINING=$(( $(sed -n '2p' "$SESSION_FILE") - $(date +%s) ))
[ "$REMAINING" -ge 35998 ] && [ "$REMAINING" -le 36000 ]

run_api 10.20.0.2 'action=coin&key=test-key&event_id=orphan-coin&pesos=1' | grep -q 'Coin rejected: INSERT COIN was not started.'
grep -q '|coin-without-window|' "$TEST_ROOT/data/alerts.log"
[ "$(wc -l < "$TEST_ROOT/data/transactions.log")" = 8 ]

printf 'PASS: noisy P5/P20 normalized, total passed P25 to P50, and orphan coin rejected\n'
