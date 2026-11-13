# Portable package contents

- `README.md` — existing system, rates, wiring, and build notes
- `START-HERE-OFFLINE.md` — workflow overview
- `firebase/` — rules, static owner dashboard, Q20 sync agent, installer, and setup guide
- `ONSITE-INSTALLATION.md` — physical-site checklist, validation, and rollback
- `FIELD-KIT-CHECKLIST.md` — tools, cables, supplies, and real test coins to bring
- `CODEX-HANDOFF-PROMPT.md` — prompt for the on-site Codex session
- `router/` — source for the current portal, local owner dashboard, API, and Q20 configuration
- `esp8266/AZTiresCoinController/` — controller source and example secrets only
- `firmware-prebuilt/` — non-network ESP32 power diagnostic only; credential-bearing controller binaries are excluded
- `packages/` — local Q20 packages already part of the project
- `tests/` — validation scripts
- `SECRETS-NOT-INCLUDED.md` — list of deliberately omitted data
- `SHA256SUMS.txt` — integrity hashes generated for the portable copy

Large local compilers/toolchains, build intermediates, credential-bearing controller binaries, hardware backups, and secrets are deliberately excluded. The controller source and non-network power-diagnostic firmware are included.
