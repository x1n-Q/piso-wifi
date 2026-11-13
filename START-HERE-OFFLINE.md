# Start here — AZ Tires Piso WiFi offline package

This package is for finishing Firebase remote monitoring when the physical Q20 and ESP32 are at the Piso WiFi site, not beside the developer.

## What is ready

- Existing JCG Q20, openNDS captive portal, owner dashboard, and ESP32 source
- ESP32/ESP8266-compatible controller source; build it locally with the site-specific secrets
- Firebase owner dashboard
- Secure Realtime Database rules
- Q20 outbound synchronization agent and installer
- On-site installation and rollback instructions
- A copy-and-paste Codex handoff for the computer at the site

The Firebase project values are placeholders until the owner provides them. No Firebase password, router password, WiFi password, voucher database, transaction log, or hardware backup is placed in this portable package.

## Chosen architecture

```text
Owner phone/PC
    |
    | HTTPS + Firebase owner login
    v
Firebase Hosting + Realtime Database
    ^
    | outbound HTTPS once per minute
    |
JCG Q20 at the Piso WiFi site ---- ESP32 coin controller
```

There is no inbound port forwarding and no Cloudflare Tunnel on the Q20. The Firebase dashboard uses `https://az-tires.web.app`. Do not expose LuCI, SSH, or `/piso-admin/` publicly.

## Correct order

1. Read `firebase/FIREBASE-VALUES-TO-PROVIDE.txt`.
2. Create/configure the Firebase project using `firebase/FIREBASE-SETUP.md`.
3. Put the public Firebase values and UIDs into the placeholder files.
4. Deploy the database rules and dashboard.
5. At the Piso WiFi site, follow `ONSITE-INSTALLATION.md`.
6. Pack everything in `FIELD-KIT-CHECKLIST.md`.
7. Use `CODEX-HANDOFF-PROMPT.md` if another Codex session will perform the on-site work.

The ESP32 does not need to be reflashed to add Firebase monitoring. The Q20 sync agent reads the existing local owner API.
