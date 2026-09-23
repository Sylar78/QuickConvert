# Publier l'app iOS

Le workflow `.github/workflows/publication-testflight.yml` construit l'app
signée et la dépose sur TestFlight. Il ne publie **jamais** sur l'App Store
tout seul : depuis TestFlight, c'est toi qui soumets à la validation d'Apple.

iOS demande plus de préparation qu'Android. Ce qui suit est l'ordre dans
lequel s'y prendre.

## 1. Le compte

Un **Apple Developer Program** actif, 99 $ par an. Sans lui, rien de ce qui
suit n'est possible : ni certificat, ni profil, ni fiche d'application.

La validation du compte prend parfois un jour ou deux. C'est la seule étape
qui ne dépend pas de toi, donc c'est par là qu'il faut commencer.

## 2. L'identifiant de bundle

L'app iOS porte `fr.quickconvert.app`, le même identifiant qu'Android. C'est
sous celui-là qu'il faut l'enregistrer dans le portail Apple Developer et dans
App Store Connect.

Il portait auparavant `com.quickconvert.quickConvert`, généré automatiquement
par Flutter et jamais choisi ; il a été aligné avant toute soumission, parce
qu'il ne peut plus changer ensuite. Il vit à trois endroits, tenus cohérents :
`PRODUCT_BUNDLE_IDENTIFIER` dans `app/ios/Runner.xcodeproj/project.pbxproj`,
la clé `BUNDLE_ID` du workflow, et `app/ios/ExportOptions.plist`.

## 3. Enregistrer l'app chez Apple

Dans le **portail Apple Developer**, *Certificates, Identifiers & Profiles* :

1. *Identifiers* → **+** → *App IDs* → *App*, description libre, identifiant
   explicite `fr.quickconvert.app`.
2. Dans **App Store Connect**, *Mes apps* → **+** → *Nouvelle app*, en
   choisissant cet identifiant dans la liste.

L'identifiant n'apparaît dans App Store Connect qu'une fois enregistré à
l'étape 1 : c'est l'ordre qui compte.

### Le nom de la fiche

« QuickConvert » était déjà pris sur l'App Store. La fiche s'appelle donc
**QuickDocumentConvert**, et le nom affiché sous l'icône a été aligné dessus
dans `app/ios/Runner/Info.plist` (`CFBundleDisplayName` et `CFBundleName`),
ainsi que les textes des demandes d'autorisation.

C'est une contrainte d'Apple, pas une préférence : une fiche dont le nom ne
correspond pas à ce que voit l'utilisateur se fait refuser. Android et le
site gardent « QuickConvert », qui n'est pas concerné, et la marque reste
QuickConvert partout dans l'app — seul le nom de l'app iOS change.

L'identifiant de bundle, lui, ne bouge pas : `fr.quickconvert.app` n'est pas
visible et n'a pas à ressembler au nom de la fiche.

## 4. Le certificat et le profil, sans Mac

Apple documente cette étape depuis un Mac, avec *Trousseau d'accès*. Elle se
fait aussi bien depuis Windows avec OpenSSL, livré avec Git pour Windows.

Tous les fichiers de cette section, **tu les fabriques toi-même** : aucun ne
se télécharge d'ailleurs, sauf le `.cer` qu'Apple te rend à la fin. Ils
naissent dans le dossier où tu lances les commandes, et ils y restent.

Crée donc un dossier pour les accueillir, par exemple
`Documents\signature-ios`, clic droit dedans → *Open Git Bash here*. Tout ce
qui suit se passe dans cette fenêtre et dans ce dossier.

**La demande de signature**, qui prouve à Apple que la clé privée est à toi :

```bash
openssl genrsa -out distribution.key 2048
MSYS_NO_PATHCONV=1 openssl req -new -key distribution.key \
  -out demande.certSigningRequest \
  -subj "/emailAddress=TON_EMAIL/CN=QuickConvert/C=FR"
```

`MSYS_NO_PATHCONV=1` n'est utile que sur Windows, et il y est indispensable :
Git Bash croit que `/emailAddress=…` est un chemin de fichier et le réécrit en
`C:/Program Files/Git/emailAddress=…` avant qu'OpenSSL le voie. La demande
part alors avec un sujet absurde, ou la commande échoue. Sur macOS et Linux,
la variable est simplement ignorée.

Deux fichiers apparaissent dans le dossier : `distribution.key`, ta clé
privée, et `demande.certSigningRequest`, la demande à remettre à Apple.

Garde `distribution.key` précieusement : sans elle, le certificat téléchargé
ensuite ne sert à rien, et il faut tout recommencer.

**Le certificat** : portail Apple Developer → *Certificates* → **+** →
*Apple Distribution* → *Choose File*, et c'est là que tu vas chercher
`demande.certSigningRequest` dans ton dossier, avec l'explorateur Windows
habituel → *Continue* → *Download*. Apple te rend un `.cer` — déplace-le dans
le même dossier, et renomme-le `distribution.cer` s'il porte un autre nom. Puis, pour le convertir au format qu'attend le workflow :

```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem
openssl pkcs12 -export -legacy \
  -inkey distribution.key -in distribution.pem -out distribution.p12
```

La deuxième commande demande `Enter Export Password`. **Ce mot de passe, tu
l'inventes maintenant** : il ne vient d'Apple ni de nulle part ailleurs, il
protège seulement le `.p12`. C'est lui, et lui seul, que tu recopies dans le
secret `IOS_DIST_CERT_PASSWORD`.

Deux pièges : Git Bash n'affiche rien pendant que tu tapes, pas même des
étoiles, et un mot de passe vide ne convient pas, parce qu'un secret GitHub
ne peut pas l'être. Si tu préfères l'écrire dans la commande plutôt que le
taper à l'aveugle, ajoute `-passout pass:TON_MOT_DE_PASSE`.

Tu peux le vérifier tout de suite — si la commande ne dit rien, il est bon :

```bash
openssl pkcs12 -in distribution.p12 -legacy -nokeys -noout
```

En cas de doute, refaire le `.p12` avec un autre mot de passe ne coûte rien :
c'est la dernière commande à relancer, ni la demande de signature ni le
certificat ne sont à refaire.

`-legacy` n'est pas un détail : sans lui, OpenSSL 3 chiffre le `.p12` d'une
façon que l'outil de signature de macOS refuse, et le workflow échoue à
l'import du certificat sans dire pourquoi.

**Le profil** : portail → *Profiles* → **+** → *App Store Connect* →
l'identifiant `fr.quickconvert.app` → le certificat que tu viens de créer →
donne-lui un nom, que tu recopieras **exactement** dans le secret
`IOS_PROVISIONING_PROFILE_NAME` → télécharge le `.mobileprovision`.

**La clé d'API** : App Store Connect → *Utilisateurs et accès* →
*Intégrations* → *Clés App Store Connect* → **+**, rôle *App Manager*. Le
`.p8` ne se télécharge **qu'une fois**.

## 5. Les huit secrets

Dans le dépôt GitHub : *Settings → Secrets and variables → Actions*.

| Secret | Où le trouver |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer → Membership (dix caractères) |
| `IOS_DIST_CERT_P12_BASE64` | Ton certificat *Apple Distribution* exporté en `.p12`, encodé en base64 |
| `IOS_DIST_CERT_PASSWORD` | Le mot de passe choisi à l'export du `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Le profil *App Store* du bundle, encodé en base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | Le nom exact du profil, tel qu'il apparaît dans le portail |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_ISSUER_ID` | Même page, en haut |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Le contenu entier du fichier `.p8` téléchargé, en-têtes comprises |

La clé `.p8` ne se télécharge **qu'une fois**. Garde-la.

Pour encoder un fichier en base64 :

```powershell
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Clipboard
```

```bash
base64 -i distribution.p12 | pbcopy    # macOS
base64 -w0 distribution.p12            # Linux
```

Le même geste vaut pour le `.mobileprovision`. Le `.p8`, lui, se colle tel
quel, sans encodage, en-têtes `-----BEGIN PRIVATE KEY-----` comprises.

## 6. Déclencher

**Par étiquette** :

```bash
git tag ios-v1.0.2
git push origin ios-v1.0.2
```

**À la main** : onglet *Actions* → *Publier sur TestFlight* → *Run workflow*,
avec au besoin un numéro de build.

L'archive `.ipa` est conservée trente jours comme artefact : si le dépôt
échoue, tu peux la déposer à la main avec Transporter sans reconstruire.

## 7. Les abonnements dans App Store Connect

À créer sous **exactement** les mêmes identifiants que Google Play, parce que
le code n'en connaît qu'un jeu :

- `quickconvert_premium_monthly`
- `quickconvert_premium_yearly`

Ils doivent appartenir au **même groupe d'abonnements**, sans quoi un
utilisateur pourrait souscrire les deux en même temps. Apple exige aussi une
capture d'écran de l'écran Premium et une description pour la validation.

## 8. Soumettre à l'App Store

Le workflow s'arrête à TestFlight. La suite est manuelle, et c'est voulu :
une soumission déclenche une validation humaine chez Apple.

1. La version apparaît dans App Store Connect, onglet *TestFlight*, après
   quelques minutes de traitement.
2. Remplis la fiche : captures d'écran, description, mots-clés, catégorie,
   URL de confidentialité (`https://quickconvert.app/privacy`), et le
   questionnaire de confidentialité. L'app ne fait pas de suivi publicitaire,
   donc réponds non au suivi — voir la décision sur les annonces non
   personnalisées plus bas.
3. Onglet *Distribution*, choisis la version construite, puis
   *Ajouter pour examen*.

Le premier examen prend généralement un à trois jours. Un refus arrive avec
son motif dans *Resolution Center*, et se corrige par une nouvelle étiquette
`ios-v…` : rien à refaire à la main.

## Ce qui a été corrigé dans le projet

L'inspection du projet iOS a trouvé plusieurs motifs de rejet, traités :

- **`NSMicrophoneUsageDescription` disait « QuickConvert n'utilise pas le
  microphone ».** Déclarer une autorisation dont on n'a pas l'usage, avec un
  texte qui l'admet, fait refuser la soumission (règle 5.1.1). La clé est
  supprimée.
- **`UIBackgroundModes` déclarait `fetch` et `remote-notification`.** L'app
  n'a ni notifications push ni rafraîchissement en arrière-plan, et Apple
  refuse les modes non utilisés (règle 2.5.4). Supprimés.
- **L'écran d'abonnement ne menait ni aux conditions ni à la
  confidentialité**, ce qu'exige la règle 3.1.2 pour un abonnement
  reconductible. Les deux liens y sont désormais, vers les pages déjà servies
  par le site.
- **`ITSAppUsesNonExemptEncryption` était absente.** Sans elle, chaque
  téléversement s'arrête sur la question du chiffrement à l'export et attend
  une réponse humaine — ce qui rend toute publication automatique impossible.
  L'app n'utilise que HTTPS, qui est exempté.
- **Une exception de transport pointait vers un projet Supabase** qui n'est
  plus utilisé. Supprimée.
- **La publicité tournait sur les identifiants de test de Google**, côté iOS
  comme dans le manifeste Android : zéro revenu, sans rien pour le signaler.
  Les six identifiants réels du compte `pub-6336563192834287` sont en place,
  et un test refuse désormais qu'un identifiant de test ou un identifiant
  d'application revienne dans une constante de bloc.
- **Le suivi publicitaire est tranché : annonces non personnalisées.**
  `AdmobService.adRequest` porte `nonPersonalizedAds: true`, ce qui dispense
  l'app de la demande d'autorisation de suivi (ATT) et de la clé
  `NSUserTrackingUsageDescription`. Repasser un jour en personnalisé oblige à
  ajouter les deux, sans quoi Apple rejette la soumission ; un test garde ce
  choix.
- **L'iPhone était bloqué en portrait.** `Info.plist` ne déclarait que le
  portrait alors que `main.dart` demande aussi le paysage et que la mise en
  page s'y adapte depuis la refonte : iOS ignorait la demande. Les deux
  orientations paysage sont ajoutées, comme sur iPad.

## Ce qui reste à traiter avant une vraie soumission

- **Aucune compilation iOS n'a jamais eu lieu** dans ce dépôt : il n'y a pas
  de `Podfile.lock`. La première exécution du workflow est donc aussi le
  premier vrai test de compilation, et peut demander des ajustements.

## Une alternative à considérer

**Xcode Cloud**, le service d'Apple, se configure directement dans App Store
Connect : aucun secret à déposer dans GitHub, aucun certificat à exporter. Il
offre 25 heures de calcul par mois. Les runners macOS de GitHub Actions, eux,
comptent dix fois plus de minutes qu'un runner Linux sur un dépôt privé.

Si la publication iOS reste occasionnelle, Xcode Cloud demandera moins
d'entretien que ce workflow.
