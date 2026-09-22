// Ouvre le portail client Stripe, où l'utilisateur voit ses factures, change
// de carte et résilie.
//
// Vendre un abonnement sans chemin de résiliation n'est pas une option : c'est
// l'équivalent web du lien « Gérer mon abonnement » qu'exige le Play Store.

const {
  stripe,
  StripeError,
  originOf,
  isValidDeviceId,
  sendJson,
} = require('./_stripe');

/// Un abonnement résilié reste consultable : on inclut donc aussi les statuts
/// terminés, pour que l'utilisateur puisse voir ses factures après coup.
const KNOWN_STATUSES = new Set([
  'active', 'trialing', 'past_due', 'unpaid', 'canceled', 'paused',
]);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return sendJson(res, 405, { error: 'method_not_allowed' });
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const { deviceId } = body;

    if (!isValidDeviceId(deviceId)) {
      return sendJson(res, 400, { error: 'invalid_device_id' });
    }

    const found = await stripe.searchSubscriptions(
      `metadata['device_id']:'${deviceId}'`,
    );
    const subscription = (found.data || []).find((s) =>
      KNOWN_STATUSES.has(s.status),
    );

    if (!subscription?.customer) {
      return sendJson(res, 404, { error: 'no_subscription' });
    }

    const customer = typeof subscription.customer === 'object'
        ? subscription.customer.id
        : subscription.customer;

    const session = await stripe.createPortalSession({
      customer,
      return_url: `${originOf(req)}/`,
    });

    return sendJson(res, 200, { url: session.url });
  } catch (error) {
    const status = error instanceof StripeError ? error.status : 500;
    console.error('portal:', error.message);
    return sendJson(res, status >= 500 ? 502 : status, { error: 'portal_failed' });
  }
};
