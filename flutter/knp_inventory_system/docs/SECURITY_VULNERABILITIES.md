# KNP Inventory System — Security Vulnerability Report

**Project:** `knp_inventory_system`  
**Stack:** Flutter + Firebase Auth + Cloud Firestore  
**Report date:** May 22, 2026  
**Scope:** Client app (`lib/`) + implied Firebase backend (rules not in repo)

---

## Executive summary

The app has **real security weaknesses** for production or untrusted users. Authorization and “employee only” access are implemented **mostly in the Flutter UI**, not enforced by Firestore rules or a real employee allowlist. The highest risk is **permissive or missing Firestore security rules** combined with **any valid Firebase Auth session** having full read/write access to shared inventory data.

**Overall risk:** **High** (if Firebase Console rules are loose or default-dev permissive)  
**Overall risk:** **Medium–High** (even with `auth != null` only — all employees share god-mode)

---

## Threat model (assumed)

| Actor | Capability |
|-------|------------|
| Anonymous | Should have **no** access to inventory data |
| Non-employee with Google/email | Should **not** sign in or access data |
| Authenticated employee | May manage inventory per business rules |
| Malicious insider / stolen session | Should be limited (currently **not** limited) |
| Attacker with REST/SDK | Can bypass Flutter if rules allow |

---

## Vulnerability register

| ID | Severity | Category | Title | Status in codebase |
|----|----------|----------|-------|-------------------|
| V-01 | **Critical** | Broken access control | Missing / unversioned Firestore security rules | **Mitigated** — `firestore.rules` + `firebase.json`; deploy via [FIREBASE_DEPLOYMENT.md](FIREBASE_DEPLOYMENT.md) |
| V-02 | **High** | Broken access control | No server-side authorization on CRUD | **Mitigated** — rules require `employees/{uid}` with `active: true` |
| V-03 | **High** | Broken authentication | Employee check always passes | **Fixed** — `EmployeeService` + `checkIsEmployee()` |
| V-04 | **High** | Broken authentication | Email login lacks invite-only parity | **Mitigated** — Google `isNewUser` block + shared employee gate; disable email sign-up in Console |
| V-05 | **High** | Broken access control | Client-only security (bypass app) | **Mitigated** — Firestore rules are authoritative |
| V-06 | **High** | Broken access control | No RBAC / least privilege | **Deferred** — flat employee access by design (v1) |
| V-07 | **Medium** | Input validation | Weak Firestore field validation | **Fixed** — `inventory_validators.dart` + rules schema |
| V-08 | **Medium** | Information disclosure | Verbose login error messages | **Fixed** — `AuthService.authErrorMessage()` + safe inventory errors |
| V-09 | **Medium** | Configuration | No Firebase App Check | **Mitigated** — `firebase_app_check` in app; enforce in Console |
| V-10 | **Medium** | Configuration | Android release uses debug signing | **Mitigated** — release uses `key.properties` when present; see `key.properties.example` |
| V-11 | **Low** | Session management | `authStateChanges` unused | **Fixed** — `AuthGate` in `main.dart` |
| V-12 | **Low** | Logging & monitoring | No audit trail | **Partial** — `lastUpdatedBy` on writes; full audit needs Cloud Functions |
| V-13 | **Info** | Design | Firebase API keys in source | Expected; rules + App Check required |
| V-14 | **Info** | Testing | No security tests | **Mitigated** — `test/inventory_validators_test.dart`, `tools/firestore_rules_test/` |

---

## Detailed findings

### V-01 — Missing Firestore security rules (Critical)

**Description:** Repository contains no `firestore.rules` (or equivalent). All data protection depends on Firebase Console configuration, which is unknown from the repo and may be permissive during development.

**Affected assets:** `inventory`, `categories` collections

**Impact:** Unauthenticated or over-privileged access; full read/write/delete of inventory via API, scripts, or modified clients.

**Evidence:** No rules file in project; `InventoryService` performs unrestricted collection access.

**Remediation:**

- Add versioned `firestore.rules` to the project.
- Default deny all; allow only verified employees (custom claims or UID allowlist).
- Deploy via Firebase CLI in CI.

---

### V-02 — No server-side authorization on data operations (High)

**Description:** `InventoryService` streams and mutates Firestore without role checks. Any principal allowed by Firestore rules has full CRUD on all documents.

**Location:** `lib/services/inventory_service.dart`

**Operations exposed:**

- `getInventoryStream()` — read all
- `addIngredient` / `updateIngredient` / `deleteIngredient`
- `getCategoriesStream`, `addCategory`, `deleteCategory`, `renameCategory` (batch updates)

**Impact:** Data breach, tampering, mass deletion, category destruction.

**Remediation:** Enforce in Firestore rules; optional Cloud Functions for sensitive ops.

---

### V-03 — Employee eligibility check is a stub (High)

**Description:** `AuthService.checkIsEmployee()` always returns `true`. `AuthLoadingScreen` displays verification UX but does not block non-employees.

**Location:** `lib/services/auth_service.dart` (lines 12–17), `lib/screens/auth_loading_screen.dart`

**Impact:** Contradicts “employee only” requirement; any Firebase Auth user proceeds to `MainLayout`.

**Remediation:**

- Check `employees` collection, allowlist, or `request.auth.token.employee == true`.
- Sign out and deny UI if check fails.
- Mirror check in Firestore rules.

---

### V-04 — Uneven authentication: Google vs email/password (High)

**Description:**

- **Google:** If `additionalUserInfo.isNewUser`, account is deleted and user signed out (client-side invite-only pattern).
- **Email/password:** `signInWithEmailAndPassword` only — no allowlist, no new-user block.

**Location:** `lib/services/auth_service.dart`

**Impact:**

- Email path bypasses Google’s invite-only intent.
- If Email sign-up is enabled in Console, outsiders can register.
- Pre-created email accounts with weak/shared passwords get full access.

**Remediation:**

- Disable public email sign-up in Console.
- After any sign-in, run same employee allowlist check as Google.
- Prefer custom claims + blocking functions.

---

### V-05 — Security controls only in client (High)

**Description:** Whitelist logic, employee gate, delete confirmations, and edit flows exist only in Flutter widgets. Firebase SDK can be used directly with a stolen or created ID token.

**Impact:** Complete bypass of UI-only controls; OWASP **Broken Access Control**.

**Remediation:** Treat app checks as UX only; enforce with Firestore rules and Auth custom claims.

---

### V-06 — No roles, audit trail, or least privilege (High)

**Description:** No admin vs staff distinction. No logging of create/update/delete with user identity.

**Impact:** Insider threat; no forensic recovery after malicious edits.

**Remediation:** Roles via custom claims; `audit_logs` collection or Cloud Function triggers.

---

### V-07 — Weak input validation on persisted data (Medium)

**Description:** Form validators mostly require non-empty fields. Quantities parsed with `double.tryParse` without range checks (negative/large values possible). No max length on names in model layer.

**Location:** `lib/screens/home_screen.dart`, `lib/screens/add_modify_screen.dart`, `lib/models/ingredient.dart`

**Impact:** Corrupt inventory state; misleading low-stock alerts; potential rule evasion if types unexpected.

**Remediation:** Client validation + Firestore rules schema validation (`request.resource.data`).

---

### V-08 — Information disclosure via login errors (Medium)

**Description:** Login failures show raw exception: `'Login failed: ${e.toString()}'`, `'Google Login failed: ${e.toString()}'`.

**Location:** `lib/screens/login_screen.dart`

**Impact:** User enumeration hints; internal error details exposed to end users.

**Remediation:** Generic user messages; log details only in debug/admin channels.

---

### V-09 — No Firebase App Check (Medium)

**Description:** App does not use App Check to attest requests from legitimate app instances.

**Impact:** Easier automated abuse of Auth/Firestore when rules are misconfigured.

**Remediation:** Enable App Check for Android, iOS, Web; enforce on Firestore and Auth.

---

### V-10 — Android release signed with debug keys (Medium)

**Description:** `release` build type uses `signingConfigs.getByName("debug")`.

**Location:** `android/app/build.gradle.kts`

**Impact:** Release APK integrity and trust chain weaker for sideloaded distribution.

**Remediation:** Production keystore and Play App Signing.

---

### V-11 — Unused auth state stream (Low)

**Description:** `AuthService.authStateChanges` defined but never subscribed globally.

**Impact:** User may remain in app after server-side disable/revoke until manual restart; minor session hygiene issue.

**Remediation:** `StreamBuilder` or listener at root to redirect to login on sign-out.

---

### V-12 — No audit trail (Low)

**Description:** No record of which user changed or deleted inventory/categories.

**Impact:** No accountability for data incidents.

**Remediation:** Firestore `audit_logs` or Cloud Function on write.

---

### V-13 — Firebase config in repository (Informational)

**Description:** `lib/firebase_options.dart` and `web/index.html` contain API keys and OAuth client IDs.

**Note:** This is **normal** for Firebase client apps. Keys are not secret; security depends on rules, App Check, and Auth configuration.

**Remediation:** Ensure Console restrictions (authorized domains, SHA fingerprints); do not rely on hiding keys.

---

### V-14 — No automated security testing (Informational)

**Description:** Only `test/smoke_test.dart` with `expect(1 + 1, 2)`.

**Remediation:** Rules unit tests (Firebase emulator), auth flow widget tests, allowlist integration tests.

---

## Employee-only goal — gap analysis

| Requirement | Current state | Related vulns |
|-------------|---------------|-----------------|
| Unknown users cannot log in | Partial (Google `isNewUser` only) | V-03, V-04, V-05 |
| Recognized employees only | Not implemented (`checkIsEmployee` stub) | V-03 |
| Enforcement survives bypassing app | Not implemented | V-01, V-02, V-05 |
| Fired employee loses access | No `active` flag / claims refresh | V-03, V-06 |

**Recommended architecture (reference):**

1. Admin-maintained `employees` collection or Console-only user creation
2. `checkIsEmployee()` + custom claim `employee: true`
3. Firestore rules: `request.auth.token.employee == true`
4. Optional: Auth blocking function `beforeUserCreated`
5. Keep Google `isNewUser` block as defense-in-depth or replace with blocking function

---

## Firebase Console verification checklist

Use this when auditing deployment (not visible in repo):

- [ ] Firestore: default deny; no public read/write
- [ ] Firestore: writes require employee claim or allowlisted UID
- [ ] Auth: email sign-up disabled if using invite-only email
- [ ] Auth: only intended sign-in providers enabled
- [ ] Google: authorized domains and OAuth clients configured
- [ ] App Check enforced on Firestore (and Auth if applicable)
- [ ] No test-mode permissive rules left in production
- [ ] Service account keys not embedded in app

---

## Risk matrix

| Severity | Count | IDs |
|----------|-------|-----|
| Critical | 1 | V-01 |
| High | 5 | V-02 – V-06 |
| Medium | 4 | V-07 – V-10 |
| Low | 2 | V-11 – V-12 |
| Info | 2 | V-13 – V-14 |

**Worst-case scenario:** Loose rules + any Auth account → **complete inventory wipe or exfiltration**.

---

## Prioritized remediation roadmap

| Priority | Action |
|----------|--------|
| P0 | Deploy strict Firestore rules; deny by default |
| P0 | Implement real employee allowlist + custom claims |
| P1 | Unify Google + email post-login employee check |
| P1 | Replace `checkIsEmployee()` stub |
| P2 | App Check; field validation in rules |
| P2 | Generic login errors; audit logging |
| P3 | Release signing; auth state listener; security tests |

---

## Code references (key evidence)

**Stub employee check:**

```dart
// lib/services/auth_service.dart
Future<bool> checkIsEmployee(User user) async {
  return true;
}
```

**Google new-user block (client only):**

```dart
if (userCredential.additionalUserInfo?.isNewUser ?? false) {
  await userCredential.user?.delete();
  await _auth.signOut();
  throw Exception('Access Denied: ...');
}
```

**Unrestricted Firestore access pattern:**

```dart
// lib/services/inventory_service.dart
_firestore.collection('inventory').snapshots()
// add / update / delete without authz layer
```

---

## Document control

| Field | Value |
|-------|--------|
| Version | 1.1 |
| Author | Security review (Cursor analysis) |
| Based on | Codebase analysis session |
| Last remediation | May 22, 2026 — security implementation plan |
| Next review | After first production deploy of rules + employee seeding |

---

*End of report*
