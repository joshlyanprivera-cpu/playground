# Firebase Deployment & Security Runbook

This document covers deploying Firestore security rules and configuring Firebase Console for the KNP Inventory System.

## Prerequisites

- [Firebase CLI](https://firebase.google.com/docs/cli) installed (`npm install -g firebase-tools`)
- Logged in: `firebase login`
- Default Firebase project: **`knp-inventory`** (see [`.firebaserc`](../.firebaserc))

## Deploy Firestore rules

From the project root:

```bash
firebase deploy --only firestore:rules
```

Verify in Firebase Console → Firestore → Rules that production rules match `firestore.rules` in this repo. **Remove any test-mode rules** (`allow read, write: if true`) before production.

## Employee allowlist (`employees` collection)

Each staff member needs a document at `employees/{uid}` where `uid` is their Firebase Authentication UID.

### Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | yes | Work email (for admin reference) |
| `displayName` | string | no | Display name |
| `active` | boolean | yes | `true` = can access inventory; `false` = revoked |
| `addedAt` | timestamp | recommended | When access was granted |

Example (Firebase Console → Firestore → Add document):

- **Collection ID:** `employees`
- **Document ID:** `{Firebase Auth UID}`
- **Fields:**
  - `email`: `staff@establishment.com`
  - `displayName`: `Jane Doe`
  - `active`: `true`
  - `addedAt`: server timestamp

### Automatic pending registration (first sign-in)

When a user signs in for the first time, the app creates `employees/{uid}` with:

- `active: false` (pending approval)
- `email`, optional `displayName`, `addedAt`

They cannot use inventory until an administrator sets `active: true`.

### Admin: Manage Employees in the app

The account **`admin@knp.com`** (must match exactly in Firebase Auth) can:

1. Sign in and open **Profile** → **Manage Employees**
2. See all users in the `employees` collection (updates live)
3. Toggle **Active** to approve or revoke access

Admin inventory access is allowed via Firestore rules even before the admin’s own `employees` doc exists. After first sign-in, the admin also appears in the manage list (usually pending until self-activated).

### Onboarding a new employee (manual alternative)

1. Firebase Console → **Authentication** → **Add user** (email/password) or allow Google sign-in.
2. User signs in once → pending `employees/{uid}` is created automatically, **or** manually create the doc with `active: true`.
3. Admin approves in **Manage Employees** (or set `active: true` in Console).

### Offboarding

1. Set `active` to `false` in **Manage Employees** or Firestore (immediate lockout).
2. Optionally disable or delete the user in Authentication.

Only **admin@knp.com** may update `active` on employee documents (enforced by rules). Users may only create their own pending record once.

## Firebase Authentication (Console)

- [ ] **Disable** public Email/Password **sign-up** — only sign-in for admin-created accounts  
  (Authentication → Sign-in method → Email/Password → disable “Email link” / sign-up as applicable)
- [ ] Enable only providers the business uses (Email, Google, etc.)
- [ ] Configure **Authorized domains** for OAuth (Authentication → Settings)
- [ ] Do not embed service account keys in the Flutter app

## Firebase App Check

1. Console → **App Check** → register each app (Android, iOS, Web).
2. For local development, register **debug tokens** from app logs.
3. Enforce App Check on **Cloud Firestore** (and Auth if required).

See app initialization in `lib/main.dart` (`firebase_app_check`).

## Android release signing

1. Generate a release keystore (one-time):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (do **not** commit):

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-upload-keystore.jks>
   ```

3. Release builds use the production signing config in `android/app/build.gradle.kts`.

4. Update `applicationId` from `com.example.knp_inventory_system` before Play Store release.

## Security rules tests

From `tools/firestore_rules_test/`:

```bash
npm install
npm test
```

Requires Firebase emulator or rules unit testing setup (see `tools/firestore_rules_test/README.md`).

## Verification checklist (production)

- [ ] `firebase deploy --only firestore:rules` succeeded
- [ ] No permissive dev rules in production
- [ ] Every staff member has `employees/{uid}` with `active: true`
- [ ] Email sign-up disabled (invite-only)
- [ ] App Check enforced on Firestore
- [ ] Test: user without `employees` doc cannot read `inventory`

## Related docs

- [SECURITY_VULNERABILITIES.md](SECURITY_VULNERABILITIES.md) — vulnerability register and remediation status
