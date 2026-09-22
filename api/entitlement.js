// Dit à l'app web si cet appareil a un abonnement Stripe actif.
//
// C'est l'équivalent, côté navigateur, de la réconciliation que
// `SubscriptionProvider` fait avec Google Play : l'app ne décide jamais
// elle-même qu'elle est Premium, elle le demande. Stripe sert aussi de base de
// données — l'abonnement porte l'identifiant de l'appareil dans ses
// métadonnées — ce qui évite un stockage de plus à tenir synchronisé.

const {
  stripe,
  StripeError,
  isValidDeviceId,
  sendJson,
} = require('./_stripe');

/// Les statuts qui donnent droit à l'accès.
///
/// `past_due` en fait partie volontairement : Stripe est en train de relancer
/// le paiement, et couper l'accès d'un client dont la carte vient d'expirer
/// est le plus sûr moyen de le perdre. `unpaid` et `canceled`, eux, marquent
/// la fin des relances.
const ACTIVE_STATUSES = new Set(['active', 'trialing', 'past_due']);

function planOf(subscription) {
  const priceId = subscription?.items?.data?.[0]?.price?.id;
  if (!priceId) return null;
  if (priceId === process.env.STRIPE_PRICE_YEARLY) return 'yearly';
  if (priceId === process.env.STRIPE_PRICE_MONTHLY) return 'monthly';
  return null;
}

function describe(subscription) {
  if (!subscription || !ACTIVE_STATUSES.has(subscription.status)) {
    return { active: false, plan: null, status: subscription?.status ?? null };
  }
  return {
    active: true,
    plan: planOf(subscription),
    status: subscription.status,
    currentPeriodEnd: subscription.current_period_end
      ? new Date(subscription.current_period_end * 1000).toISOString()
      : null,
  };
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return sendJson(res, 405, { error: 'method_not_allowed' });
  }

  const deviceId = req.query?.device;
  const sessionId = req.query?.session;

  if (!isValidDeviceId(deviceId)) {
    return sendJson(res, 400, { error: 'invalid_device_id' });
  }

  try {
    // ── Retour immédiat du paiement ─────────────────────────────────────
    // L'index de recherche de Stripe met jusqu'à une minute à voir un
    // abonnement tout neuf. Au retour de la page de paiement, l'app passe
    // donc l'identifiant de session, qui lui est lisible tout de suite.
    if (typeof sessionId === 'string' && sessionId.startsWith('cs_')) {
      const session = await stripe.retrieveCheckoutSession(sessionId);

      // Une session n'ouvre de droits que pour l'appareil qui l'a demandée :
      // sans ce contrôle, un identifiant de session récupéré ailleurs
      // rendrait n'importe quel navigateur Premium.
      if (session?.metadata?.device_id !== deviceId) {
        return sendJson(res, 403, { error: 'device_mismatch' });
      }

      const subscription = typeof session.subscription === 'object'
          ? session.subscription
          : null;
      return sendJson(res, 200, describe(subscription));
    }

    // ── Vérification ordinaire, à chaque lancement ──────────────────────
    const found = await stripe.searchSubscriptions(
      `metadata['device_id']:'${deviceId}'`,
    );

    // Un appareil peut avoir plusieurs abonnements dans l'historique (un
    // résilié puis un repris) : on garde le premier qui donne encore droit.
    const live = (found.data || []).find((s) => ACTIVE_STATUSES.has(s.status));
    return sendJson(res, 200, describe(live));
  } catch (error) {
    const status = error instanceof StripeError ? error.status : 500;
    console.error('entitlement:', error.message);
    // Surtout ne pas répondre « pas d'abonnement » quand c'est Stripe qui est
    // en panne : l'app garde alors l'accès plutôt que de le couper à tort.
    return sendJson(res, status >= 500 ? 502 : status, { error: 'lookup_failed' });
  }
};

// Exposés pour les tests : ce sont eux qui décident qui a droit à quoi.
module.exports.describe = describe;
module.exports.planOf = planOf;
module.exports.ACTIVE_STATUSES = ACTIVE_STATUSES;
