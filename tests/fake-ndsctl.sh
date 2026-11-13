#!/bin/sh

case "$1" in
	auth) printf '%s authenticated\n' "$2" ;;
	deauth) printf '%s deauthenticated\n' "$2" ;;
	json) printf '{"state":"Authenticated","custom":"test"}\n' ;;
	*) printf 'unsupported test command\n' >&2; exit 1 ;;
esac
