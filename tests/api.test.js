// Tests des fonctions de paiement. `node --test tests/`
//
// Ils couvrent ce qui décide qui est abonné et ce qui part chez Stripe : le
// reste (les appels réseau eux-mêmes) ne se teste pas sans clé.

const test = require('node:test');
const assert = require('node:assert');

process.env.STRIPE_PRICE_MONTHLY = 'price_monthly_test';
process.env.STRIPE_PRICE_YEARLY = 'price_yearly_test';

const { toForm, isValidDeviceId } = require('../api/_stripe');
const { describe: describeSub, planOf } = require('../api/entitlement');

const subscription = (overrides = {}) => ({
  status: 'active',
  current_period_end: 1790000000,
  items: { data: [{ price: { id: 'price_yearly_test' } }] },
  ...overrides,
});

test('toForm encode les tableaux et objets imbriqués comme Stripe les attend', () => {
  const encoded = toForm({
    mode: 'subscription',
    line_items: [{ price: 'price_123', quantity: 1 }],
    subscription_data: { metadata: { device_id: 'abc' } },
  }).toString();

  assert.match(encoded, /mode=subscription/);
  assert.match(encoded, /line_items%5B0%5D%5Bprice%5D=price_123/);
  assert.match(encoded, /line_items%5B0%5D%5Bquantity%5D=1/);
  assert.match(encoded, /subscription_data%5Bmetadata%5D%5Bdevice_id%5D=abc/);
});

test('toForm omet les valeurs nulles au lieu de les envoyer vides', () => {
  const encoded = toForm({ a: 1, b: null, c: undefined }).toString();
  assert.strictEqual(encoded, 'a=1');
});

test('isValidDeviceId n\'accepte que la forme qu\'on génère', () => {
  assert.ok(isValidDeviceId('123e4567-e89b-12d3-a456-426614174000'));

  // Un identifiant part dans une requête de recherche Stripe : tout ce qui
  // pourrait s'en échapper doit être refusé avant.
  assert.ok(!isValidDeviceId("' OR status:'active"));
  assert.ok(!isValidDeviceId('123e4567-e89b-12d3-a456-42661417400'), 'trop court');
  assert.ok(!isValidDeviceId('123E4567-E89B-12D3-A456-426614174000'), 'majuscules');
  assert.ok(!isValidDeviceId(''));
  assert.ok(!isValidDeviceId(null));
  assert.ok(!isValidDeviceId(42));
});

test('un abonnement actif donne l\'accès, avec sa formule', () => {
  const result = describeSub(subscription());
  assert.strictEqual(result.active, true);
  assert.strictEqual(result.plan, 'yearly');
  assert.strictEqual(result.currentPeriodEnd, new Date(1790000000000).toISOString());
});

test('un essai en cours donne l\'accès', () => {
  assert.strictEqual(describeSub(subscription({ status: 'trialing' })).active, true);
});

test('un paiement en retard garde l\'accès pendant les relances', () => {
  // Couper l'accès dès qu'une carte expire est le plus sûr moyen de perdre
  // un client que Stripe est en train de relancer.
  assert.strictEqual(describeSub(subscription({ status: 'past_due' })).active, true);
});

test('un abonnement résilié ou impayé ne donne plus l\'accès', () => {
  assert.strictEqual(describeSub(subscription({ status: 'canceled' })).active, false);
  assert.strictEqual(describeSub(subscription({ status: 'unpaid' })).active, false);
  assert.strictEqual(describeSub(subscription({ status: 'incomplete' })).active, false);
});

test('aucun abonnement du tout ne donne pas l\'accès', () => {
  const result = describeSub(null);
  assert.strictEqual(result.active, false);
  assert.strictEqual(result.status, null);
});

test('la formule se déduit du tarif facturé', () => {
  assert.strictEqual(
    planOf(subscription({ items: { data: [{ price: { id: 'price_monthly_test' } }] } })),
    'monthly',
  );
  // Un tarif inconnu (ancien prix, promo) ne doit pas faire planter la
  // réponse : l'abonnement reste actif, la formule est simplement ignorée.
  assert.strictEqual(
    planOf(subscription({ items: { data: [{ price: { id: 'price_autre' } }] } })),
    null,
  );
  assert.strictEqual(planOf(subscription({ items: { data: [] } })), null);
});
