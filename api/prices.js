// Renvoie les prix réellement facturés par Stripe.
//
// Sans ça, l'app afficherait les montants codés dans `AppConstants`, qui
// peuvent diverger de ce que Stripe encaisse le jour où les tarifs changent —
// annoncer un prix et en prélever un autre n'est pas une petite erreur.

const { stripe, StripeError, sendJson } = require('./_stripe');

const PLANS = [
  { plan: 'monthly', env: 'STRIPE_PRICE_MONTHLY' },
  { plan: 'yearly', env: 'STRIPE_PRICE_YEARLY' },
];

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return sendJson(res, 405, { error: 'method_not_allowed' });
  }

  try {
    const prices = {};

    for (const { plan, env } of PLANS) {
      const id = process.env[env];
      if (!id) continue;

      const price = await stripe.retrievePrice(id);
      prices[plan] = {
        // En centimes, comme Stripe les donne : c'est l'app qui met en forme,
        // elle seule connaît la locale de l'utilisateur.
        amount: price.unit_amount,
        currency: price.currency,
        interval: price.recurring?.interval ?? null,
      };
    }

    return sendJson(res, 200, { prices });
  } catch (error) {
    const status = error instanceof StripeError ? error.status : 500;
    console.error('prices:', error.message);
    return sendJson(res, status >= 500 ? 502 : status, { error: 'prices_failed' });
  }
};
