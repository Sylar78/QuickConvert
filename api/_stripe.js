// Appels à l'API Stripe en REST pur.
//
// Pas de paquet `stripe` : `vercel.json` déclare un `installCommand` vide
// parce que le site est servi statiquement depuis `app/build/web`. Ajouter une
// dépendance npm obligerait à réintroduire une étape d'installation dans le
// déploiement. `fetch` est global sur le runtime Node de Vercel, et l'API de
// Stripe est du form-urlencoded : ça suffit largement pour ce qu'on en fait.

const STRIPE_API = 'https://api.stripe.com/v1';

/**
 * Encode un objet au format attendu par Stripe : `a[b][c]=v`, `a[0][b]=v`.
 * Les valeurs nulles ou indéfinies sont omises plutôt qu'envoyées vides, que
 * Stripe refuserait sur certains champs.
 */
function toForm(value, prefix = '', out = new URLSearchParams()) {
  if (value === null || value === undefined) return out;

  if (Array.isArray(value)) {
    value.forEach((item, index) => toForm(item, `${prefix}[${index}]`, out));
    return out;
  }

  if (typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      toForm(item, prefix ? `${prefix}[${key}]` : key, out);
    }
    return out;
  }

  out.append(prefix, String(value));
  return out;
}

class StripeError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'StripeError';
    this.status = status;
  }
}

/** La clé secrète, ou une erreur explicite si elle n'est pas configurée. */
function secretKey() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new StripeError(
      'STRIPE_SECRET_KEY absente des variables d\'environnement Vercel.',
      503,
    );
  }
  return key;
}

async function stripeRequest(method, path, { body, query } = {}) {
  const url = new URL(`${STRIPE_API}${path}`);
  if (query) {
    for (const [key, value] of toForm(query).entries()) {
      url.searchParams.append(key, value);
    }
  }

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey()}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body ? toForm(body).toString() : undefined,
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    // Le message de Stripe est destiné au développeur, pas à l'utilisateur :
    // il est journalisé ici, et l'appelant décide de ce qu'il affiche.
    const detail = payload?.error?.message || response.statusText;
    throw new StripeError(detail, response.status);
  }

  return payload;
}

const stripe = {
  createCheckoutSession: (params) =>
    stripeRequest('POST', '/checkout/sessions', { body: params }),

  retrieveCheckoutSession: (id) =>
    stripeRequest('GET', `/checkout/sessions/${encodeURIComponent(id)}`, {
      query: { 'expand[0]': 'subscription' },
    }),

  retrievePrice: (id) =>
    stripeRequest('GET', `/prices/${encodeURIComponent(id)}`),

  createPortalSession: (params) =>
    stripeRequest('POST', '/billing_portal/sessions', { body: params }),

  searchSubscriptions: (query) =>
    stripeRequest('GET', '/subscriptions/search', {
      query: { query, limit: 10 },
    }),
};

/** L'origine réellement servie, pour que les URL de retour marchent aussi sur
 * les déploiements de prévisualisation de Vercel. */
function originOf(req) {
  const proto = req.headers['x-forwarded-proto'] || 'https';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  return `${proto}://${host}`;
}

/**
 * Un identifiant d'appareil est un secret porteur : c'est lui qui rend
 * l'abonnement au navigateur qui l'a acheté. On n'accepte donc que la forme
 * qu'on génère nous-mêmes, pour ne pas laisser injecter n'importe quoi dans
 * une requête de recherche Stripe ni dans les métadonnées.
 */
function isValidDeviceId(value) {
  return typeof value === 'string' && /^[0-9a-f-]{36}$/.test(value);
}

function sendJson(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json');
  // Ces réponses dépendent de l'appareil qui demande : jamais de cache
  // partagé, sinon un visiteur hériterait de l'abonnement d'un autre.
  res.setHeader('Cache-Control', 'no-store');
  res.send(JSON.stringify(body));
}

module.exports = {
  stripe,
  StripeError,
  toForm,
  originOf,
  isValidDeviceId,
  sendJson,
};
