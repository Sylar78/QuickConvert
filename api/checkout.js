// Ouvre une page de paiement Stripe pour un abonnement QuickConvert.
//
// L'app web appelle cette fonction, puis envoie l'utilisateur sur l'URL
// renvoyée. Rien de sensible ne transite par le navigateur : la clé secrète
// reste ici, côté serveur.

const {
  stripe,
  StripeError,
  originOf,
  isValidDeviceId,
  sendJson,
} = require('./_stripe');

const PRICE_ENV = {
  monthly: 'STRIPE_PRICE_MONTHLY',
  yearly: 'STRIPE_PRICE_YEARLY',
};

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return sendJson(res, 405, { error: 'method_not_allowed' });
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const { plan, deviceId } = body;

    if (!PRICE_ENV[plan]) {
      return sendJson(res, 400, { error: 'unknown_plan' });
    }
    if (!isValidDeviceId(deviceId)) {
      return sendJson(res, 400, { error: 'invalid_device_id' });
    }

    const price = process.env[PRICE_ENV[plan]];
    if (!price) {
      return sendJson(res, 503, {
        error: 'price_not_configured',
        detail: `${PRICE_ENV[plan]} absente des variables d'environnement.`,
      });
    }

    const origin = originOf(req);

    const session = await stripe.createCheckoutSession({
      mode: 'subscription',
      line_items: [{ price, quantity: 1 }],
      // `{CHECKOUT_SESSION_ID}` est remplacé par Stripe au moment de la
      // redirection. L'app s'en sert pour constater l'abonnement tout de
      // suite, sans attendre que l'index de recherche de Stripe rattrape.
      success_url: `${origin}/?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/?checkout=cancel`,
      client_reference_id: deviceId,
      // Posée sur l'abonnement lui-même, et pas seulement sur la session :
      // c'est ce que `api/entitlement.js` interroge aux lancements suivants.
      subscription_data: { metadata: { device_id: deviceId } },
      metadata: { device_id: deviceId },
      allow_promotion_codes: true,
    });

    return sendJson(res, 200, { url: session.url });
  } catch (error) {
    const status = error instanceof StripeError ? error.status : 500;
    console.error('checkout:', error.message);
    // Le détail de Stripe reste dans les journaux : l'app n'a besoin que de
    // savoir que ça a échoué.
    return sendJson(res, status >= 500 ? 502 : status, { error: 'checkout_failed' });
  }
};
