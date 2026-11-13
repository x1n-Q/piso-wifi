# Firebase setup

This design uses the Firebase Spark plan, Email/Password Authentication, Realtime Database, and static Firebase Hosting. It does not require Cloud Functions, Cloud Storage, a billing account, or a Cloudflare Tunnel.

## 1. Create the project, Hosting site, and web app

1. Open Firebase Console and create a project.
   - Project display name: `AZ Tires Piso WiFi`
   - Suggested Project ID: `az-tires-piso-wifi` (Firebase may require a unique suffix)
2. Open **Hosting > Get started** and create the default Hosting site. Try `az-tires-piso` as its site ID if available.
3. Add a Web app named `AZ Tires Remote Dashboard` after the Hosting site exists. No SDK installation is needed.
4. Copy `apiKey`, the exact `authDomain`, and `projectId` into `FIREBASE-VALUES-TO-PROVIDE.txt`.
5. Keep the project on the Spark plan unless the owner intentionally chooses otherwise.

Firebase projects created after October 15, 2026 defer creation of their default Hosting site. Creating Hosting before the Web app ensures the generated `authDomain` points at the correct default site. The Hosting site ID can differ from the Firebase project ID, so copy the real value instead of assuming it.

These Web app values identify the Firebase project; they are not administrator secrets. Database Rules and Firebase Authentication provide access control.

## 2. Enable Authentication

1. Open **Authentication > Sign-in method**.
2. Enable **Email/Password**.
3. Create three different users:
   - one AZ Tires owner/admin user for the dashboard;
   - one maintenance/admin user for the dashboard;
   - one dedicated Q20 device user for the sync agent.
4. Copy all UIDs and emails to `FIREBASE-VALUES-TO-PROVIDE.txt`.
5. Store their strong, unique passwords in the owner's password manager—not in this package.

If a custom dashboard hostname is used, add it under Authentication's authorized domains.

## 3. Create Realtime Database

1. Open **Realtime Database** and create one database.
2. Choose the nearest practical region.
3. Start in locked mode.
4. Copy the exact database URL into `FIREBASE-VALUES-TO-PROVIDE.txt`. It may end in `firebaseio.com` or `firebasedatabase.app`; do not guess it.

The two administrator UIDs are already listed in `initial-data.example.json`. Replace `REPLACE_WITH_Q20_DEVICE_FIREBASE_UID`, save the result as `initial-data.json`, and import it at the database root using the Firebase Console. It must create:

```json
{
  "admins": {
    "THE_OWNER_UID": true,
    "THE_MAINTENANCE_UID": true
  },
  "deviceAccounts": {
    "THE_Q20_DEVICE_UID": true
  }
}
```

Then open the **Rules** tab, paste the complete contents of `database.rules.json`, and publish. The default is deny. Only a UID explicitly listed under `deviceAccounts` can write its own telemetry/applied state and read its own desired settings. An UID explicitly listed under `admins` can read devices and write only desired settings. This registry also prevents an unrelated self-created Firebase account from consuming database space as a fake device.

## 4. Configure the dashboard

Copy `dashboard/config.example.js` to `dashboard/config.js`, then replace all four placeholders:

```js
window.AZ_TIRES_FIREBASE = {
  apiKey: "PUBLIC_WEB_API_KEY",
  authDomain: "EXACT_AUTH_DOMAIN_FROM_FIREBASE",
  projectId: "PROJECT_ID",
  databaseUrl: "EXACT_REALTIME_DATABASE_URL",
  deviceUid: "DEDICATED_Q20_USER_UID"
};
```

Do not put either password in JavaScript.

## 5. Deploy Firebase Hosting

With Node.js and the Firebase CLI installed, run from this `firebase` directory:

```sh
cp .firebaserc.example .firebaserc
# Replace REPLACE_WITH_FIREBASE_PROJECT_ID inside .firebaserc.
firebase login
firebase deploy --only database,hosting
```

The dashboard will be available at `https://DEFAULT_SITE_ID.web.app` after deployment. The Firebase Console shows the exact URL. Sign in with the owner account, not the Q20 device account.

If the CLI is unavailable, the Realtime Database rules can still be published in the Console first. Hosting can be deployed later from another computer.

## 6. Dashboard address

The default dashboard address is `https://az-tires.web.app`. No Cloudflare configuration is required.

If AZ Tires later supplies its own domain, use Firebase Hosting's **Add custom domain** wizard and follow the exact DNS records Firebase provides. This is ordinary DNS, not a Cloudflare Tunnel. Leave LuCI, SSH, and the local Q20 owner dashboard private.

## 7. Prepare the on-site Q20 configuration

The portable copy contains only `q20/az-tires-firebase.conf.example`. The dedicated device password is intentionally absent. At the site, copy it to `/etc/az-tires-firebase.conf`, fill the API key, database URL, device email, and device password locally, then set mode 600.

Continue with the root-level `ONSITE-INSTALLATION.md`.
