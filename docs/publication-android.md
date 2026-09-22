# Publier l'app Android automatiquement

Le workflow `.github/workflows/publication-play.yml` construit l'app signée et
la dépose sur une piste de la Play Console. Il ne publie rien si l'analyse ou
les tests échouent.

Tes secrets restent chez GitHub. Ils ne sont visibles ni dans les journaux
d'exécution ni par qui que ce soit d'autre que le workflow.

## Les cinq secrets à déposer

Dans le dépôt GitHub : *Settings → Secrets and variables → Actions →
New repository secret*.

| Secret | Ce que c'est |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Ton fichier `.jks` de signature, encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Le mot de passe du magasin de clés |
| `ANDROID_KEY_ALIAS` | L'alias de la clé dans ce magasin |
| `ANDROID_KEY_PASSWORD` | Le mot de passe de la clé (souvent le même que celui du magasin) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Le contenu entier du fichier JSON du compte de service Google |

### Encoder le magasin de clés

Sur ta machine, dans le dossier qui contient le `.jks` :

```powershell
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

```bash
# macOS / Linux
base64 -w0 upload-keystore.jks | pbcopy   # ou | xclip -selection clipboard
```

Colle le résultat tel quel dans `ANDROID_KEYSTORE_BASE64`, sans retour à la
ligne ajouté.

C'est la **même clé** que celle qui a servi aux versions déjà publiées. Google
refuse un dépôt signé avec une autre.

### Créer le compte de service Google

1. Dans la **Play Console** : *Configuration → Accès à l'API*, puis suivre le
   lien vers Google Cloud pour créer un compte de service.
2. Dans **Google Cloud** : créer une clé de type JSON pour ce compte, et
   télécharger le fichier.
3. Retour dans la Play Console : *Utilisateurs et autorisations → Inviter*,
   ajouter l'adresse du compte de service, et lui donner sur QuickConvert au
   minimum *Publier sur les pistes de test fermées* et *Gérer les versions de
   production* si tu veux aussi viser la production.
4. Coller le contenu **entier** du fichier JSON dans
   `PLAY_SERVICE_ACCOUNT_JSON`.

Les autorisations mettent parfois quelques minutes à se propager côté Google.

## Déclencher une publication

**Par étiquette**, pour livrer une version :

```bash
git tag v1.0.2
git push origin v1.0.2
```

Le bundle part sur la **piste de test interne**.

**À la main**, pour choisir la piste : onglet *Actions* du dépôt →
*Publier sur Google Play* → *Run workflow*. Tu choisis la piste, et
éventuellement un `versionCode` si tu ne veux pas celui de `pubspec.yaml`.

Une publication visant la **production** part en **brouillon** : c'est toi qui
la rends visible depuis la Console. Les pistes de test, elles, sont livrées
directement.

## Ce qui peut coincer la première fois

- **L'app doit déjà exister dans la Console**, avec au moins une version
  déposée à la main. L'API ne crée pas une fiche d'application.
- **Le `versionCode` doit être strictement supérieur** à tous ceux déjà
  déposés, y compris ceux des pistes de test. Il vaut aujourd'hui `4`, réglé
  par la ligne `version: 1.0.1+4` de `app/pubspec.yaml`.
- **Les abonnements doivent être créés dans la Console** sous
  `quickconvert_premium_monthly` et `quickconvert_premium_yearly`, sinon l'app
  affichera « offres indisponibles ». Voir `docs/paiement-stripe.md` pour
  l'équivalent côté web.

Si le dépôt sur Play échoue pour une de ces raisons, le bundle construit reste
téléchargeable pendant trente jours depuis la page de l'exécution, sous
*Artifacts* : tu peux le déposer à la main sans reconstruire.
