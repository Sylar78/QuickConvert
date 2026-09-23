# Publier une app Flutter sur Google Play et l'App Store

Ce document est un mode d'emploi réutilisable, tiré de la mise en production
de QuickConvert en septembre 2026. Il n'est propre à aucun projet : partout
où il écrit `<app>`, `<bundle-id>` ou `<compte>`, mets les tiens.

Il suppose une app **Flutter**, un dépôt **GitHub**, et une publication
automatisée par **GitHub Actions**. Il ne suppose rien d'autre, et surtout pas
un Mac : toute la partie iOS se prépare depuis Windows.

Ce qui suit n'est pas une redite de la documentation d'Apple et de Google.
C'est la liste de ce qui a réellement bloqué, dans l'ordre où ça a bloqué,
avec la cause et le remède. Chaque piège décrit ici a coûté au moins une
exécution de CI.

---

## 1. Les décisions irréversibles, à prendre d'abord

Trois choix ne peuvent plus changer une fois la première version soumise.
Les trancher avant d'ouvrir quoi que ce soit chez Apple ou Google.

**L'identifiant de l'app.** `applicationId` côté Android,
`PRODUCT_BUNDLE_IDENTIFIER` côté iOS. Prends **le même des deux côtés**, en
notation inverse de domaine : `fr.<monapp>.app`. Flutter en génère un
automatiquement, du genre `com.<monapp>.<monApp>` — ne le garde pas par
défaut, personne ne l'a choisi. Il vit à trois endroits côté iOS : le
`project.pbxproj`, l'`ExportOptions.plist`, et la variable `BUNDLE_ID` du
workflow.

**Le nom de la fiche.** Il peut être déjà pris, et tu ne le sauras qu'en
essayant de créer l'app. S'il l'est, le nom que tu choisis à la place doit
aussi devenir le nom affiché sous l'icône : Apple refuse une fiche dont le nom
ne correspond pas à ce que voit l'utilisateur. Cela veut dire
`CFBundleDisplayName` et `CFBundleName` dans `ios/Runner/Info.plist`, et les
textes des demandes d'autorisation, qui citent souvent l'ancien nom. Android
et le site web, eux, ne sont pas concernés et peuvent garder l'autre nom.

**Les identifiants des produits d'abonnement.** Les mêmes chaînes exactes
dans la Play Console et dans App Store Connect, parce que le code n'en
connaît qu'un jeu. Par exemple `<app>_premium_monthly` et
`<app>_premium_yearly`. Une faute de frappe ne lève aucune erreur : l'app dira
simplement que les offres sont indisponibles.

---

## 2. Vérifier l'état du dépôt avant tout

Deux choses à regarder, qui font perdre des journées si on les découvre tard.

**Un seul arbre Flutter.** Un dépôt qui traîne depuis des essais successifs
peut en contenir deux — par exemple `lib/` à la racine *et* `app/lib/`. Les
modifications faites dans le mauvais sont invisibles. Vérifie avec
`git ls-files` où se trouve le `pubspec.yaml` que les workflows construisent,
et supprime l'autre arbre.

**Le dossier iOS et la version de Flutter doivent concorder.** Un
`flutter create` lancé avec une version récente réécrit `ios/Runner/` au
modèle de cette version-là. Si le projet est resté sur une version plus
ancienne, la compilation iOS échoue sur des types Swift introuvables —
typiquement `FlutterSceneDelegate` ou `FlutterImplicitEngineDelegate`. Le
symptôme n'apparaît qu'à la première compilation iOS, souvent des mois après.

Le remède est de comparer avec le modèle du SDK réellement utilisé, qui est
sur le disque :

```
<sdk-flutter>/packages/flutter_tools/templates/app_shared/ios-swift.tmpl/Runner/AppDelegate.swift
```

Aligne `AppDelegate.swift` dessus et supprime ce que ce modèle ne contient
pas. Ne devine pas : lis le fichier.

---

## 3. Publier sur Google Play

Le workflow construit un `.aab` signé et le dépose sur une piste. Il se
déclenche sur une étiquette `v*` ou à la main.

**Cinq secrets GitHub** : le magasin de clés `.jks` encodé en base64, son mot
de passe, l'alias de la clé, le mot de passe de la clé, et le contenu entier
du JSON d'un compte de service Google.

Le compte de service se crée dans la Play Console (*Configuration → Accès à
l'API*), puis il faut l'**inviter** comme utilisateur du compte et lui donner
les droits de publication. Les autorisations mettent quelques minutes à se
propager.

**Ce qui bloque la première fois** : l'app doit déjà exister dans la Console
avec au moins une version déposée à la main — l'API ne crée pas une fiche. Et
le `versionCode` doit être strictement supérieur à tous ceux déjà déposés,
pistes de test comprises.

---

## 4. Publier sur l'App Store, depuis Windows

### Le compte et l'enregistrement

Un **Apple Developer Program** actif, 99 $ par an, dont la validation prend
parfois un jour ou deux : commence par là, c'est la seule étape qui ne dépend
pas de toi.

Puis, dans cet ordre, parce que chacune débloque la suivante : enregistrer
l'**App ID** dans le portail Apple Developer, puis créer l'app dans **App
Store Connect** en choisissant cet identifiant dans la liste. Il n'y apparaît
pas avant d'être enregistré.

### Le certificat, sans Trousseau d'accès

Apple documente cette étape depuis un Mac. Elle se fait aussi bien avec
OpenSSL, livré avec Git pour Windows. Ouvre *Git Bash* dans un dossier de
travail — **tous ces fichiers, tu les fabriques**, aucun ne se télécharge
sauf le `.cer` qu'Apple rend à la fin.

```bash
openssl genrsa -out distribution.key 2048

MSYS_NO_PATHCONV=1 openssl req -new -key distribution.key \
  -out demande.certSigningRequest \
  -subj "/emailAddress=<ton-email>/CN=<app>/C=FR"
```

`MSYS_NO_PATHCONV=1` est indispensable sous Windows : sans lui, Git Bash prend
`/emailAddress=…` pour un chemin de fichier et le réécrit en
`C:/Program Files/Git/emailAddress=…`. Selon les versions la commande échoue,
ou — bien pire — réussit avec un sujet absurde que tu ne découvriras qu'en
lisant le certificat rendu par Apple. Vérifie avant d'envoyer :

```bash
openssl req -in demande.certSigningRequest -noout -subject
```

Dépose la demande sur le portail (*Certificates* → **+** →
*Apple Distribution*), télécharge le `.cer`, puis :

```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem

openssl pkcs12 -export -legacy \
  -inkey distribution.key -in distribution.pem -out distribution.p12
```

`-legacy` n'est pas décoratif : sans lui, OpenSSL 3 chiffre le `.p12` d'une
façon que l'outil de signature de macOS refuse, et le workflow échoue à
l'import du certificat sans motif lisible.

Le mot de passe demandé à l'export, **tu l'inventes** : c'est la valeur du
secret correspondant. Git Bash n'affiche rien pendant la saisie, et un mot de
passe vide ne convient pas puisqu'un secret GitHub ne peut pas l'être.

Garde `distribution.key` : le certificat seul ne sert à rien sans elle.

### Le profil de provisionnement

Le certificat prouve **qui** signe ; le profil dit **quoi** : il lie l'app,
le certificat et l'équipe. Tout se passe dans le navigateur, et tu ne
téléverses **pas** le `.p12` — Apple connaît déjà ton certificat, tu ne fais
que le désigner dans une liste.

*Profiles* → **+** → *App Store Connect* → l'App ID → le certificat → un nom
que **tu choisis** et que tu recopieras au caractère près dans le secret
correspondant → *Generate* → *Download*.

### La clé d'API

*Utilisateurs et accès* → *Intégrations* → *Clés App Store Connect*, onglet
**Team Keys**. Il faut être *Account Holder* ou *Admin* pour voir le bouton.
Rôle **App Manager** au minimum, sans quoi la clé ne pourra pas déposer.

Trois valeurs en sortent : le fichier `.p8`, qui ne se télécharge **qu'une
fois** ; le *KEY ID* de la ligne ; et l'*Issuer ID* affiché au-dessus du
tableau, commun à toutes les clés — c'est le piège de cette page, on le
confond avec le Key ID.

Le `.p8` se colle **tel quel** dans son secret, en-têtes
`-----BEGIN PRIVATE KEY-----` comprises, sans base64, contrairement au `.p12`
et au `.mobileprovision`.

### Encoder en base64 sous Windows

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Clipboard
```

### Les huit secrets, et d'où ils viennent

Trois d'entre eux sont des valeurs que **tu as choisies** : ne les cherche pas
sur un écran d'Apple. C'est la confusion la plus coûteuse de toute la mise en
place.

| Secret | Origine |
| --- | --- |
| Team ID | Relevé : *Membership details* |
| Certificat `.p12` | Fabriqué, puis encodé en base64 |
| Mot de passe du `.p12` | **Choisi** à l'export |
| Profil `.mobileprovision` | Téléchargé, puis encodé en base64 |
| Nom du profil | **Choisi** à sa création |
| Key ID | Relevé sur la ligne de la clé |
| Issuer ID | Relevé au-dessus du tableau |
| Clé `.p8` | Téléchargée, collée telle quelle |

---

## 5. Les pièges du workflow iOS, tous vérifiés

**`flutter analyze` peut sortir en erreur sur une simple info.** Si le projet
en porte une, connue et acceptée, le workflow est rouge dès le premier
passage. Utiliser `--no-fatal-infos` ; avertissements et erreurs restent
bloquants.

**La signature automatique ne marche pas sur un runner.** Le projet Xcode est
en signature automatique par défaut, ce qui suppose une session Apple. Bascule
la configuration Release en manuel en ajoutant à `ios/Flutter/Release.xcconfig` :

```
CODE_SIGN_STYLE=Manual
DEVELOPMENT_TEAM=<team-id>
PROVISIONING_PROFILE_SPECIFIER=<nom-du-profil>
CODE_SIGN_IDENTITY=Apple Distribution
```

C'est moins invasif que de modifier le `.pbxproj`.

**`ExportOptions.plist` doit être écrit par le workflow**, pas lu depuis le
dépôt : il contient le Team ID, et un modèle rempli de valeurs d'exemple
produit une archive mal signée sans le dire.

**L'outil de dépôt d'Apple veut le fichier `.ipa`, pas son dossier.** Reçu un
dossier, `altool` répond *« Could not determine the package's bundle ID. The
package is missing an Info.plist »* — un message qui accuse l'archive alors
qu'elle est saine. Cherche l'archive plutôt que d'écrire son nom en dur, car
Flutter la nomme d'après l'app :

```bash
chemin="$(find "$IPA_DIR" -maxdepth 1 -name '*.ipa' | head -n 1)"
```

**`MinimumOSVersion` doit exister et concorder en trois endroits** :
`ios/Flutter/AppFrameworkInfo.plist`, la ligne `platform :ios` **et** le
`post_install` du `Podfile` — sans le second, les pods gardent leur propre
cible, plus basse, et c'est elle qu'Apple regarde —, et
`IPHONEOS_DEPLOYMENT_TARGET` dans le `project.pbxproj`.

Cette clé disparaît facilement du plist, et son absence ne se voit qu'au
moment du dépôt. Compare les trois valeurs dans le workflow, avant de
construire.

Apple relève ce minimum régulièrement : **15.0 à partir du printemps 2027**.

**Apple impose un SDK iOS minimum qui monte chaque année.** Une image de
runner figée finit donc par être refusée au dépôt, avec le message *« This app
was built with the iOS X SDK… must be built with the iOS Y SDK or later »*.
Utilise `macos-latest`, sélectionne le Xcode le plus récent de l'image, et
vérifie son SDK **dès le début** plutôt que d'attendre le dépôt :

```bash
recent="$(ls -d /Applications/Xcode*.app | sort -V | tail -n 1)"
sudo xcode-select -s "$recent/Contents/Developer"
sdk="$(xcrun --sdk iphoneos --show-sdk-version)"
```

Attention : une version de Flutter ancienne peut ne plus compiler avec un
Xcode très récent. Si cela arrive, la montée de Flutter devient le passage
obligé.

---

## 6. Déclencher, et lire les résultats

**L'étiquette ne fixe pas la version.** La version vient de la ligne
`version: 1.0.1+4` du `pubspec.yaml` : la partie avant le `+` est la version
publique, celle après est le numéro de build. Poser une étiquette `v1.0.2`
sur un dépôt resté en `1.0.1+4` produit une app 1.0.1. Modifie cette ligne,
pousse, **puis** pose l'étiquette.

**Le numéro de build doit monter à chaque envoi.** Apple comme Google
refusent un numéro déjà déposé.

**« Re-run jobs » rejoue exactement le même commit.** C'est le piège qui fait
croire qu'un correctif ne marche pas : le re-run ne va jamais chercher les
nouveautés. Repasse toujours par *Run workflow*, et vérifie le commit affiché
sur la page de l'exécution.

**Tous les messages d'Apple ne sont pas des refus.** `ITMS-90068` et ses
semblables sont des **avertissements**, envoyés par courriel *après* un dépôt
réussi. Avant de corriger dans l'urgence, va voir si le build est arrivé dans
TestFlight.

---

## 7. Essayer sur un appareil avant de soumettre

À faire avant la soumission, jamais après. Une compilation réussie ne dit
rien du lancement, et un plantage découvert par l'examinateur d'Apple coûte
plusieurs jours quand il t'en coûte dix minutes.

Le **test interne** TestFlight ne demande aucune validation d'Apple : crée un
groupe, ajoute-toi, ajoute le build. Regarde en priorité ce qui n'a jamais été
exécuté sur iOS : le lancement, chaque autorisation déclarée dans
`Info.plist`, et l'écran de paiement.

---

## 8. Les abonnements

**Le contrat *Paid Applications* bloque tout.** Tant qu'il n'est pas signé et
les informations bancaires et fiscales complètes, les produits restent
indisponibles et l'app annonce « offres indisponibles » sans autre
explication. On cherche alors longtemps dans le code un problème qui n'y est
pas. C'est le premier point à régler, des deux côtés.

**Les deux abonnements doivent être dans le même groupe** côté Apple : sinon
un utilisateur peut souscrire les deux à la fois, et les changements de
formule ne fonctionnent pas. Ils sont examinés **avec la première version**
de l'app, jamais séparément.

**Teste en bac à sable** : un compte de test créé dans *Utilisateurs et
accès*, avec une adresse qui n'est pas ton identifiant Apple. Les achats y
sont gratuits et les durées raccourcies.

### Trois règles de code qui évitent des débits sans contrepartie

**L'abonnement s'écrit sur le disque avant de dire au store que l'achat est
traité.** Dans l'autre ordre, une app qui meurt entre les deux laisse le store
croire l'achat livré, et l'utilisateur a payé pour rien.

**Une panne n'est jamais une résiliation.** Ne retire l'accès que si le store
**a répondu** sans abonnement actif. Une erreur réseau, un store injoignable,
un délai : l'accès reste.

**Un écran de paiement qui ne peut rien vendre doit le dire.** Quand le store
ne renvoie aucune offre, montrer un bouton grisé et muet est la pire des
réponses : l'utilisateur conclut que l'app est cassée. Affiche un encart qui
explique que les offres sont indisponibles et que cela ne vient pas de son
appareil.

Apple exige enfin que l'écran d'un abonnement reconductible mène aux
**conditions d'utilisation et à la politique de confidentialité** (règle
3.1.2). Leur absence fait refuser la soumission.

---

## 9. AdMob

**Deux formes d'identifiants, qu'on confond une fois sur deux.** Un **bloc
d'annonces** s'écrit avec une barre oblique, `ca-app-pub-<éditeur>/<bloc>`. Un
**identifiant d'application** s'écrit avec un tilde,
`ca-app-pub-<éditeur>~<app>`. Le premier va dans le code, le second dans
`AndroidManifest.xml` et `Info.plist`, et jamais l'inverse.

Poser un identifiant d'application là où le SDK attend un bloc fait échouer le
chargement **en silence**. Un test qui refuse un tilde dans les constantes de
blocs coûte cinq lignes et évite de chercher pendant des heures.

**Les identifiants de test de Google rapportent zéro.** Ils traînent souvent
dans les manifestes longtemps après la mise en production, et rien ne le
signale. Vérifie-les avant la première publication.

**Un bloc neuf ne sert pas d'annonces tout de suite**, et AdMob ne sert
généralement rien à une app qui n'est pas encore publiée sur le store. Ne
conclus pas à un bug avant que l'app soit en ligne depuis un jour.

**Charge les bannières sur les rappels du SDK, jamais sur une attente fixe.**
Un code qui patiente deux secondes puis renonce n'affichera pratiquement
jamais rien, et aucun rappel ne pourra plus rattraper l'annonce ensuite. Une
bannière appartient au widget qui l'affiche — deux écrans peuvent en montrer
une en même temps, or une annonce ne s'attache qu'à un seul emplacement — et
doit être libérée à la destruction du widget.

**Annonces personnalisées ou non, c'est une décision, pas un réglage.** Les
annonces personnalisées imposent sur iOS la demande d'autorisation de suivi
(ATT) et la clé `NSUserTrackingUsageDescription` ; sans elles, Apple refuse.
Les annonces non personnalisées n'exigent ni l'une ni l'autre et rapportent
moins — mais la plupart des utilisateurs refusent le suivi de toute façon, ce
qui réduit l'écart.

---

## 10. Les motifs de rejet à vérifier dans `Info.plist`

Passer ce fichier en revue **avant** la première soumission évite les
refus les plus bêtes :

- **Aucune autorisation déclarée qui ne serve pas.** Une clé
  `NS…UsageDescription` pour une fonction que l'app n'a pas fait refuser la
  soumission (règle 5.1.1), surtout si son texte admet qu'elle est inutile.
- **Aucun `UIBackgroundModes` non utilisé** (règle 2.5.4).
- **`ITSAppUsesNonExemptEncryption`** doit être présente. Sans elle, chaque
  téléversement s'arrête sur la question du chiffrement à l'export et attend
  une réponse humaine, ce qui interdit toute publication automatique. Une app
  qui n'utilise que HTTPS est exemptée.
- **Aucune exception de transport (ATS) vers un service abandonné.**
- **Les orientations déclarées doivent correspondre à ce que le code
  demande.** C'est `Info.plist` qui tranche : une orientation absente d'ici
  est ignorée, même si le code la réclame.

---

## 11. L'ordre de marche

1. Trancher les trois décisions irréversibles.
2. Vérifier l'état du dépôt : un seul arbre, dossier iOS aligné sur Flutter.
3. Passer `Info.plist` en revue.
4. Ouvrir le compte Apple Developer, enregistrer l'App ID, créer les fiches.
5. Signer les contrats, dont *Paid Applications*.
6. Fabriquer certificat, profil et clé d'API ; déposer les secrets.
7. Lancer le workflow à la main, corriger, recommencer jusqu'au vert.
8. Essayer sur un appareil réel via TestFlight et une piste de test fermée.
9. Créer les abonnements, les tester en bac à sable.
10. Remplir les fiches, soumettre.

Les étapes 1 à 3 se font dans le code et ne coûtent rien. Les sauter coûte
des jours plus tard.
