# Firestore security rules tests

Unit tests for [`firestore.rules`](../../firestore.rules) using the Firebase Rules Unit Testing library.

## Prerequisites

- Node.js 18+
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Java (for Firestore emulator, if not already installed)

## Run

```bash
cd tools/firestore_rules_test
npm install
npm test
```

Tests start the Firestore emulator automatically via `@firebase/rules-unit-testing`.

## What is covered

- Unauthenticated users cannot read or write `inventory`
- Authenticated users without an `employees` document are denied
- Users with `active: false` are denied
- Active employees can read and write valid inventory data
- Invalid field values (negative quantity, oversized name) are rejected
