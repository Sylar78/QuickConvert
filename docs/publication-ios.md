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

### Le profil de provisionnement

Le `.p12` est fini : range-le, tu n'y touches plus jusqu'aux secrets.

Le profil est autre chose. Le certificat prouve **qui** signe ; le profil dit
**quoi** : il lie l'app `fr.quickconvert.app`, ton certificat et ton équipe
Apple. Sans lui, un binaire signé n'est accepté nulle part.

Tout se passe dans le navigateur, sans aucune commande. Et tu **ne téléverses
pas** le `.p12` : Apple connaît déjà ton certificat, puisque c'est lui qui te
l'a délivré. Tu ne fais que le désigner dans une liste.

Portail Apple Developer → *Certificates, Identifiers & Profiles* →
*Profiles* → **+**, puis quatre écrans :

1. *Register a New Provisioning Profile*. Sous **Distribution**, coche
   **App Store Connect**. → *Continue*
2. *Select an App ID* : déroule et choisis `fr.quickconvert.app`. S'il n'y
   est pas, c'est qu'il n'a pas été enregistré à l'étape 3. → *Continue*
3. *Select Certificates* : la liste de tes certificats de distribution.
   Coche celui que tu viens de créer — s'il y en a plusieurs, c'est celui à
   la date du jour. → *Continue*
4. *Review, Name, and Generate* : le champ *Provisioning Profile Name*. Ce
   nom, **tu l'inventes**, par exemple `QuickConvert App Store`. Retiens-le
   au caractère près : c'est la valeur du secret
   `IOS_PROVISIONING_PROFILE_NAME`, et le workflow échoue si elle diffère,
   ne serait-ce que d'une majuscule. → *Generate*

Enfin *Download* : tu obtiens un `.mobileprovision`. Mets-le dans le même
dossier que le reste ; c'est lui que tu encoderas en base64 pour le secret
`IOS_PROVISIONING_PROFILE_BASE64`.

À ce stade tu as tout ce qu'il faut côté signature : `distribution.p12`, son
mot de passe, le `.mobileprovision` et son nom.

### La clé d'API App Store Connect

C'est ce qui permet au workflow de déposer la build sans ton mot de passe
Apple. Trois des huit secrets en sortent, et ils se récupèrent tous sur la
même page.

Il faut être *Account Holder* ou *Admin* du compte pour créer une clé. Si le
bouton **+** n'apparaît pas, c'est ça.

Sur **appstoreconnect.apple.com** → *Utilisateurs et accès* → onglet
*Intégrations* → dans la colonne de gauche, *Clés App Store Connect*.
Choisis bien **Team Keys** et non *Individual Keys*.

1. Bouton **+**. *Name* : ce que tu veux, par exemple `GitHub Actions` — ce
   nom ne sert qu'à t'y retrouver et n'est recopié nulle part.
2. *Access* : choisis **App Manager**. En dessous, la clé n'aura pas le droit
   de déposer sur TestFlight.
3. *Generate*. Une ligne apparaît dans le tableau.

Trois valeurs à prendre, et c'est le seul moment où la première est
disponible :

- **Download** au bout de la ligne : un fichier `AuthKey_XXXXXXXXXX.p8`. Il
  ne se télécharge **qu'une fois**, Apple ne le redonnera jamais. Range-le
  avec le reste. Son contenu entier, en-têtes `-----BEGIN PRIVATE KEY-----`
  comprises, est le secret `APP_STORE_CONNECT_PRIVATE_KEY` — tel quel, sans
  base64, contrairement aux deux autres fichiers.
- La colonne **KEY ID** de cette ligne, dix caractères : secret
  `APP_STORE_CONNECT_KEY_ID`.
- L'**Issuer ID** affiché au-dessus du tableau, un long identifiant à tirets :
  secret `APP_STORE_CONNECT_ISSUER_ID`. Il est commun à toutes tes clés, donc
  facile à confondre avec le Key ID.

Si tu perds le `.p8`, la clé est à révoquer et à recréer : ça ne casse rien
d'autre, seuls les trois secrets sont à remettre à jour.

Il te manque alors une seule valeur, le **Team ID** : portail Apple Developer
→ *Membership details*, dix caractères. C'est le secret `APPLE_TEAM_ID`.

## 5. Les huit secrets

Sur **github.com/Sylar78/QuickConvert** → *Settings* → dans la colonne de
gauche, *Secrets and variables* → *Actions* → onglet *Secrets* → bouton
**New repository secret**. Un nom, une valeur, *Add secret*, et on
recommence : huit fois.

Le nom doit être recopié au caractère près, en majuscules, tel qu'il figure
dans le tableau ci-dessous. Un secret mal nommé n'est pas une erreur pour
GitHub : il est simplement vide côté workflow, et la première étape s'arrête
en disant lequel manque.

Une valeur déposée n'est plus relisible, même par toi : GitHub ne sait que la
remplacer. C'est normal, et c'est pour ça qu'il faut garder le dossier de
travail jusqu'à la première exécution réussie.

Trois d'entre eux sont des valeurs que **tu as choisies** toi-même, et c'est
ce qui déroute : ne les cherche pas sur un écran d'Apple.

| Secret | D'où il vient |
| --- | --- |
| `APPLE_TEAM_ID` | Relevé : portail Apple Developer → *Membership details* |
| `IOS_DIST_CERT_P12_BASE64` | Fabriqué : `distribution.p12`, encodé en base64 |
| `IOS_DIST_CERT_PASSWORD` | **Choisi** : le mot de passe tapé à l'export du `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Téléchargé : le `.mobileprovision`, encodé en base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | **Choisi** : le nom donné au profil, au caractère près |
| `APP_STORE_CONNECT_KEY_ID` | Relevé : colonne *KEY ID* de la clé créée |
| `APP_STORE_CONNECT_ISSUER_ID` | Relevé : au-dessus du tableau des clés |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Téléchargé : le contenu entier du `.p8` |

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

Une fois les huit déposés, il ne reste rien à préparer : passe à l'étape
suivante et déclenche une première exécution.

## 6. Déclencher la construction

### D'abord : le numéro de version ne vient pas de l'étiquette

C'est le piège de cette étape. La version de l'app est **une seule ligne**,
dans `app/pubspec.yaml` :

```yaml
version: 1.0.1+4
```

`1.0.1` est la version affichée sur l'App Store, `4` le numéro de build.
L'étiquette `ios-v…` ne fait que **déclencher** le workflow : poser
`ios-v1.0.2` sur un dépôt resté en `1.0.1+4` produit une app 1.0.1, pas 1.0.2.

Apple refuse un build dont le numéro a déjà été déposé pour la même version.
Donc à chaque envoi, au minimum, ce numéro doit augmenter.

**Pour la toute première exécution, il n'y a rien à changer** : aucune app
iOS n'a jamais été déposée depuis ce dépôt, donc le build `4` est libre chez
Apple. Ensuite seulement, à chaque envoi :

- **Simple correction, même version publique** : passe `1.0.1+4` à `1.0.1+5`.
- **Nouvelle version publique** : passe à `1.0.2+5`.

Puis commite et pousse cette ligne, avant de poser l'étiquette.

### Par étiquette

```bash
git tag ios-v1.0.2
git push origin ios-v1.0.2
```

Le nom de l'étiquette est libre tant qu'il commence par `ios-v`. Donne-lui
la même valeur que `pubspec.yaml`, sinon l'historique devient illisible.

### À la main

Le plus court est d'aller droit à la page du workflow :

<https://github.com/Sylar78/QuickConvert/actions/workflows/publication-testflight.yml>

Sinon, depuis le dépôt : onglet **Actions**, dans la barre du haut, entre
*Pull requests* et *Projects*. La colonne de gauche liste les workflows ;
clique sur *Publier sur TestFlight*.

Un bandeau apparaît alors à droite, *This workflow has a workflow_dispatch
event trigger*, avec un bouton **Run workflow**. Il ouvre un petit panneau :
la branche `main`, et le champ *Numéro de build*, facultatif. Laisse-le vide,
puis clique sur le bouton vert *Run workflow*.

Ce champ, quand il est rempli, l'emporte sur `pubspec.yaml` le temps de cette
exécution : pratique pour renvoyer un build sans toucher au dépôt.

L'exécution apparaît dans la liste après quelques secondes — rafraîchis si
elle tarde. Clique dessus, puis sur le job, pour dérouler les étapes en
direct.

Le bouton n'apparaît que si le fichier du workflow est sur la branche par
défaut, ce qui est le cas ici. Sur l'interface mobile de GitHub il est
souvent absent : fais-le depuis un navigateur d'ordinateur.

### Ce qui se passe, et où regarder

Le workflow vérifie d'abord que les huit secrets sont là, puis analyse et
teste le code. Il échoue à ce moment-là si quelque chose ne va pas,
c'est-à-dire **avant** d'avoir touché à la signature — un échec précoce ne
consomme presque rien.

Suis l'exécution dans l'onglet *Actions*. Un runner macOS est lent : la
compilation d'une app Flutter iOS prend un bon moment, sans rien afficher
d'inquiétant.

L'archive `.ipa` porte le nom de l'app, qui peut changer ; le workflow la
cherche dans son dossier plutôt que de l'écrire en dur, parce que l'outil de
dépôt d'Apple veut le fichier et non le dossier. Reçu un dossier, il répond
« Could not determine the package's bundle ID », ce qui laisse croire à tort
à une archive corrompue.

Elle est conservée trente jours, sous *Artifacts* sur la page de
l'exécution. Si seule la dernière étape échoue, le dépôt sur TestFlight, tu
peux la télécharger et la déposer à la main avec Transporter sans tout
reconstruire.

Quand le workflow est vert, Apple prend encore quelques minutes à traiter le
build avant qu'il n'apparaisse dans l'onglet *TestFlight*. Un refus à ce
stade arrive par courriel, et ne vient jamais du workflow.

### La version minimale d'iOS

L'app demande **iOS 15.0 au minimum**. Apple n'accepte plus aucun dépôt en
dessous à partir du printemps 2027, et le prévient par l'avertissement
ITMS-90068 d'ici là.

Cette valeur est écrite à trois endroits, qui doivent rester d'accord :

- `app/ios/Flutter/AppFrameworkInfo.plist`, clé `MinimumOSVersion`
- `app/ios/Podfile`, la ligne `platform :ios` et le `post_install`
- `app/ios/Runner.xcodeproj/project.pbxproj`, `IPHONEOS_DEPLOYMENT_TARGET`

Leur désaccord ne se voit qu'au moment du dépôt, dans un message d'Apple qui
n'aide pas. Le workflow les compare donc avant de construire, et s'arrête si
elles divergent.

### Si Apple refuse le dépôt pour cause de SDK

Apple impose un SDK iOS minimum pour tout dépôt, et ce minimum monte chaque
année. Le workflow tourne donc sur `macos-latest` et sélectionne le Xcode le
plus récent de l'image, en vérifiant ce point dès la deuxième étape.

Si elle échoue en disant que le SDK est trop ancien, c'est que l'image de
GitHub a pris du retard sur l'exigence d'Apple. Deux leviers, dans cet ordre :
passer `runs-on` à l'image macOS la plus récente que GitHub propose, et, si
cela ne suffit pas, monter la version de Flutter — une version ancienne finit
par ne plus compiler avec un Xcode très récent.

## 7. Les abonnements dans App Store Connect

### Un préalable qui bloque tout

*Accords, taxes et virements bancaires* : le contrat **Paid Applications**
doit être signé, et les informations bancaires et fiscales complètes. Tant
que ce n'est pas fait, les abonnements restent indisponibles et l'app
affichera « offres indisponibles » sans autre explication. C'est le blocage
le plus fréquent, et il n'a rien à voir avec le code.

### Créer le groupe, puis les deux abonnements

*Monétisation* → *Abonnements* → commence par créer un **groupe
d'abonnements**, par exemple `Premium`.

Le groupe compte autant que les abonnements : deux abonnements du même groupe
s'excluent, l'utilisateur ne peut en avoir qu'un à la fois et passe de l'un à
l'autre proprement. Dans deux groupes différents, il pourrait payer les deux.

Dans ce groupe, crée deux abonnements sous **exactement** ces identifiants,
qui sont ceux que le code demande et ceux déjà créés sur Google Play :

- `quickconvert_premium_monthly`, durée un mois
- `quickconvert_premium_yearly`, durée un an

Une faute de frappe ici ne se voit pas : l'app dira simplement que l'offre
est indisponible.

Pour chacun, il faut ensuite un prix, et une localisation française avec un
nom affiché et une description — c'est ce que l'utilisateur lit dans la
fenêtre d'achat, pas ce que montre l'écran Premium de l'app.

### Ce qu'Apple demande pour la validation

Une capture d'écran de l'écran Premium de l'app, et une note pour
l'examinateur. Les abonnements sont examinés **avec la première version** de
l'app : ils ne peuvent pas être validés séparément.

### Tester avant de publier

*Utilisateurs et accès* → *Testeurs Sandbox* : crée un compte de test avec
une adresse qui n'est **pas** ton identifiant Apple. Sur l'iPhone,
*Réglages* → *Développeur* → *Compte Sandbox*. Les achats y sont gratuits et
les durées raccourcies, un abonnement annuel s'y renouvelle en une heure.

## 7 bis. Essayer le build sur ton iPhone

À faire **avant** de soumettre, et pas après : l'app n'a jamais tourné sur un
appareil iOS. Une compilation réussie ne dit rien de ce qui se passe au
lancement. Un plantage découvert par l'examinateur d'Apple coûte plusieurs
jours ; découvert par toi, dix minutes.

Le test interne ne demande **aucune validation d'Apple**, contrairement au
test externe. C'est immédiat.

1. Onglet *TestFlight* → *TESTS INTERNES* → **+** → nomme le groupe, par
   exemple `Interne`.
2. Ajoute-toi comme testeur. Un testeur interne doit être un utilisateur du
   compte App Store Connect ; c'est ton cas.
3. Dans le groupe, ajoute le build.
4. Installe l'app **TestFlight** sur l'iPhone, depuis l'App Store, et accepte
   l'invitation reçue par courriel.

Ce qu'il faut regarder en priorité, parce que ce sont les parties qui n'ont
jamais été exécutées sur iOS : le lancement, une conversion de chaque type,
l'enregistrement dans la galerie et le partage — les trois autorisations
déclarées dans `Info.plist` —, l'affichage des annonces, et l'écran Premium.

Les abonnements ne pourront s'acheter que lorsqu'ils existeront dans App
Store Connect et que le contrat Paid Applications sera signé. Dans TestFlight
les achats passent par le bac à sable, donc sans être débités.

## 8. Soumettre à l'App Store

Le workflow s'arrête à TestFlight, et c'est voulu : une soumission déclenche
un examen humain chez Apple, qui ne doit pas partir sur une étiquette posée
par mégarde.

### Remplir la fiche

Dans App Store Connect, la version qui attend :

- **Nom** : QuickDocumentConvert, sous-titre, catégorie.
- **Captures d'écran** : au format iPhone 6,7 pouces, et iPad si tu
  distribues sur iPad — le projet déclare les deux, donc les deux jeux sont
  demandés.
- **Description, mots-clés, URL d'assistance**, et l'URL de confidentialité
  `https://quickconvert.app/privacy`.
- **Classification par âge** : un questionnaire à remplir.

### Le questionnaire de confidentialité

Il demande ce que l'app collecte. Réponds d'après **AdMob**, qui est le seul
à collecter quelque chose ici : Google publie la liste de ce que son SDK
récupère, et c'est elle qui fait foi, pas une intuition.

Un point est déjà tranché : l'app ne fait **pas** de suivi au sens d'Apple,
parce que les annonces sont non personnalisées. La question « suivez-vous les
utilisateurs ? » se répond donc non, et c'est aussi pourquoi il n'y a pas de
fenêtre d'autorisation de suivi au lancement.

La conformité à l'export, elle, ne sera pas demandée : `Info.plist` y répond
déjà.

### Envoyer

Onglet de la version → choisis le build arrivé par TestFlight →
*Ajouter pour examen*.

Le premier examen prend généralement un à trois jours. Un refus arrive avec
son motif dans le *Resolution Center*.

Et un refus ne se rattrape pas à la main : tu corriges le code, tu montes le
numéro de build dans `pubspec.yaml`, tu poses une nouvelle étiquette, et tu
resélectionnes le build dans la fiche. Le reste est déjà en place.

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
