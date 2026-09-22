# Paiement des abonnements sur le web (Stripe)

Sur mobile, les abonnements passent par Google Play. Sur le web, Google Play
n'existe pas : le paiement passe par Stripe, via quatre fonctions serverless
déployées avec le site sur Vercel.

Aucune clé secrète ne vit dans l'app. Le navigateur ne fait qu'ouvrir une page
de paiement hébergée par Stripe, puis demander au serveur si l'abonnement
existe.

## Ce qu'il faut régler une fois

### 1. Dans le tableau de bord Stripe

1. Créer un **produit** « QuickConvert Premium ».
2. Lui ajouter deux **tarifs récurrents** : un mensuel, un annuel.
3. Noter les identifiants des deux tarifs (ils commencent par `price_`).
4. Dans *Paramètres → Facturation → Portail client*, activer le portail et
   autoriser la résiliation. Sans ça, le bouton « Gérer ou résilier mon
   abonnement » de l'app ne mènera nulle part.

### 2. Dans les variables d'environnement Vercel

| Variable | Valeur |
| --- | --- |
| `STRIPE_SECRET_KEY` | La clé secrète Stripe (`sk_live_…`, ou `sk_test_…` pour essayer) |
| `STRIPE_PRICE_MONTHLY` | L'identifiant du tarif mensuel (`price_…`) |
| `STRIPE_PRICE_YEARLY` | L'identifiant du tarif annuel (`price_…`) |

Les ajouter pour les environnements *Production* et *Preview*, puis
redéployer : les variables ne sont lues qu'au démarrage des fonctions.

Tant qu'elles manquent, l'app affiche « Le paiement ne répond pas » au lieu
d'un bouton qui échouerait.

## Les quatre fonctions

| Route | Rôle |
| --- | --- |
| `POST /api/checkout` | Crée une session de paiement et renvoie l'URL Stripe |
| `GET /api/entitlement` | Dit si cet appareil a un abonnement actif |
| `GET /api/prices` | Renvoie les montants réellement facturés |
| `POST /api/portal` | Ouvre le portail client (facture, carte, résiliation) |

Elles n'utilisent aucune dépendance npm : `vercel.json` déclare un
`installCommand` vide parce que le site est servi statiquement, et ajouter le
paquet `stripe` obligerait à réintroduire une étape d'installation. L'API de
Stripe est appelée en REST avec le `fetch` global de Node.

## Comment un abonnement est rattaché à quelqu'un

QuickConvert n'a pas de comptes utilisateurs. L'app tire donc un **code
d'appareil** (un UUID) au premier lancement, le garde en local, et le pose dans
les métadonnées de l'abonnement Stripe. C'est Stripe qui sert de base de
données : `/api/entitlement` cherche l'abonnement par ce code, il n'y a pas de
table à tenir synchronisée.

Conséquences, assumées et expliquées dans l'app :

- Effacer les données du site fait perdre l'accès.
- L'abonnement ne suit pas automatiquement d'un navigateur à l'autre.

D'où le **code d'abonnement** affiché sur l'écran Premium une fois abonné :
c'est ce code d'appareil, copiable, que l'utilisateur saisit ailleurs via
« J'ai déjà un abonnement sur un autre appareil ». C'est un secret porteur —
qui l'a, a l'abonnement.

Des comptes utilisateurs remplaceraient proprement ce mécanisme.

## Règles de décision

Deux choix guident tout le code, et il ne faut pas les défaire par mégarde :

- **Une panne n'est pas une résiliation.** Si `/api/entitlement` ne répond pas,
  l'app garde l'accès. Elle ne le retire que lorsque le serveur a répondu sans
  abonnement actif. Couper le Premium d'un client qui paie coûte plus cher que
  de le laisser un jour de trop.
- **Un paiement en retard garde l'accès.** Le statut `past_due` compte comme
  actif : Stripe est en train de relancer, et couper l'accès dès qu'une carte
  expire est le plus sûr moyen de perdre le client.

## Essayer sans encaisser

Avec une clé `sk_test_…` et des tarifs créés en mode test, la page de paiement
Stripe accepte la carte `4242 4242 4242 4242`, n'importe quelle date future et
n'importe quel CVC.

## Vérification automatique

```bash
node --test tests/*.test.js   # encodage vers Stripe, droits d'accès
cd app && flutter test        # formules, prix, abonnement persisté
```
