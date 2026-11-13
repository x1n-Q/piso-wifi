# Remote dashboard

This is a static, dependency-free owner dashboard. It signs in through Firebase Authentication's HTTPS REST endpoint and polls the Q20's Realtime Database node every 30 seconds.

Before deployment, fill only the public project values and dedicated device UID in `config.js`. Never add an owner password, Q20 device password, router password, or Firebase service-account key.

The dashboard intentionally cannot open a shell, flash firmware, restart the router, delete sessions, or create vouchers. Those higher-risk operations remain local to the Q20.
