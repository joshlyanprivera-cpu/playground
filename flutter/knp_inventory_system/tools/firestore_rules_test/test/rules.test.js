const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const rulesPath = path.resolve(__dirname, '../../../firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

const PROJECT_ID = 'knp-inventory';

const validIngredient = {
  name: 'Espresso Beans',
  classification: 'Coffee',
  quantityClassification: 'kg',
  quantity: 2.5,
  lastUpdated: new Date(),
};

let testEnv;
let passed = 0;
let failed = 0;

async function runTest(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`  ok ${name}`);
  } catch (err) {
    failed += 1;
    console.error(`  FAIL ${name}`);
    console.error(`       ${err.message}`);
  }
}

async function seedEmployee(uid, active = true, email = null) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('employees').doc(uid).set({
      email: email ?? `${uid}@test.com`,
      active,
      addedAt: new Date(),
    });
  });
}

function adminContext(uid = 'admin1') {
  return testEnv.authenticatedContext(uid, {
    token: { email: 'admin@knp.com' },
  });
}

const pendingEmployee = {
  email: 'newuser@test.com',
  displayName: 'New User',
  active: false,
  addedAt: new Date(),
};

async function main() {
  console.log('Firestore rules tests\n');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  try {
    await runTest('unauthenticated cannot read inventory', async () => {
      await testEnv.clearFirestore();
      const unauthed = testEnv.unauthenticatedContext();
      await assertFails(
        unauthed.firestore().collection('inventory').doc('a').get(),
      );
    });

    await runTest(
      'authenticated user without employees doc cannot read inventory',
      async () => {
        await testEnv.clearFirestore();
        const alice = testEnv.authenticatedContext('alice');
        await assertFails(
          alice.firestore().collection('inventory').doc('a').get(),
        );
      },
    );

    await runTest('inactive employee cannot read inventory', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('bob', false);
      const bob = testEnv.authenticatedContext('bob');
      await assertFails(
        bob.firestore().collection('inventory').doc('a').get(),
      );
    });

    await runTest('active employee can create and read valid inventory', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('carol', true);
      const carol = testEnv.authenticatedContext('carol');
      const ref = carol.firestore().collection('inventory').doc('item1');

      await assertSucceeds(ref.set(validIngredient));
      await assertSucceeds(ref.get());
    });

    await runTest('active employee cannot write invalid quantity', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('dave', true);
      const dave = testEnv.authenticatedContext('dave');
      const ref = dave.firestore().collection('inventory').doc('bad');

      await assertFails(
        ref.set({ ...validIngredient, quantity: -1 }),
      );
    });

    await runTest('active employee cannot write oversized name', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('eve', true);
      const eve = testEnv.authenticatedContext('eve');
      const ref = eve.firestore().collection('inventory').doc('bad2');

      await assertFails(
        ref.set({ ...validIngredient, name: 'x'.repeat(201) }),
      );
    });

    await runTest('user can create own pending employees doc', async () => {
      await testEnv.clearFirestore();
      const frank = testEnv.authenticatedContext('frank', {
        token: { email: 'frank@test.com' },
      });
      await assertSucceeds(
        frank.firestore().collection('employees').doc('frank').set(pendingEmployee),
      );
    });

    await runTest('user cannot create employees doc with active true', async () => {
      await testEnv.clearFirestore();
      const frank = testEnv.authenticatedContext('frank');
      await assertFails(
        frank.firestore().collection('employees').doc('frank').set({
          ...pendingEmployee,
          active: true,
        }),
      );
    });

    await runTest('admin can list all employees', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('emp1', true);
      await seedEmployee('emp2', false);
      const admin = adminContext();
      await assertSucceeds(admin.firestore().collection('employees').get());
    });

    await runTest('non-admin cannot list employees collection', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('grace', true);
      const grace = testEnv.authenticatedContext('grace');
      await assertFails(grace.firestore().collection('employees').get());
    });

    await runTest('admin can toggle employee active', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('pending1', false, 'pending@test.com');
      const admin = adminContext();
      await assertSucceeds(
        admin.firestore().collection('employees').doc('pending1').update({
          active: true,
        }),
      );
    });

    await runTest('non-admin cannot update another employees active', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('target', false);
      const attacker = testEnv.authenticatedContext('attacker');
      await assertFails(
        attacker.firestore().collection('employees').doc('target').update({
          active: true,
        }),
      );
    });

    await runTest('admin can read inventory without employees doc', async () => {
      await testEnv.clearFirestore();
      const admin = adminContext('adminonly');
      await assertSucceeds(
        admin.firestore().collection('inventory').doc('x').get(),
      );
    });

    await runTest('employee can read own employees doc only', async () => {
      await testEnv.clearFirestore();
      await seedEmployee('grace', true);
      const grace = testEnv.authenticatedContext('grace');
      await assertSucceeds(
        grace.firestore().collection('employees').doc('grace').get(),
      );
      await assertFails(
        grace.firestore().collection('employees').doc('other').get(),
      );
    });
  } finally {
    await testEnv.cleanup();
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
