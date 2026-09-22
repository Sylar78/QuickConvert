# Publier l'app iOS

Le workflow `.github/workflows/publication-testflight.yml` construit l'app
signée et la dépose sur TestFlight. Il ne publie **jamais** sur l'App Store
tout seul : depuis TestFlight, c'est toi qui soumets à la validation d'Apple.

iOS demande plus de préparation qu'Android. Ce qui suit est l'ordre dans
lequel s'y prendre.

## 1. Le compte

- Un **Apple Developer Program** actif : 99 $ par an. Sans lui, rien de ce
  qui suit n'est possible.
- L'app créée dans **App Store Connect**, avec le même identifiant de bundle
  que le projet.

## 2. Décider de l'identifiant de bundle

Le projet Xcode porte aujourd'hui `com.quickconvert.quickConvert` — un
identifiant généré automatiquement par Flutter, jamais choisi. Android, lui,
utilise `fr.quickconvert.app`.

**À trancher avant d'enregistrer quoi que ce soit chez Apple** : cet
identifiant ne peut plus changer une fois l'app soumise. Pour rester cohérent
avec Android, `fr.quickconvert.app` serait plus propre. Si tu le changes, il
faut le changer à trois endroits : `PRODUCT_BUNDLE_IDENTIFIER` dans
`app/ios/Runner.xcodeproj/project.pbxproj`, la clé `BUNDLE_ID` du workflow, et
`app/ios/ExportOptions.plist`.

## 3. Les huit secrets

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

```bash
base64 -i certificat.p12 | pbcopy      # macOS
base64 -w0 certificat.p12              # Linux
```

## 4. Déclencher

**Par étiquette** :

```bash
git tag ios-v1.0.2
git push origin ios-v1.0.2
```

**À la main** : onglet *Actions* → *Publier sur TestFlight* → *Run workflow*,
avec au besoin un numéro de build.

L'archive `.ipa` est conservée trente jours comme artefact : si le dépôt
échoue, tu peux la déposer à la main avec Transporter sans reconstruire.

## 5. Les abonnements dans App Store Connect

À créer sous **exactement** les mêmes identifiants que Google Play, parce que
le code n'en connaît qu'un jeu :

- `quickconvert_premium_monthly`
- `quickconvert_premium_yearly`

Ils doivent appartenir au **même groupe d'abonnements**, sans quoi un
utilisateur pourrait souscrire les deux en même temps. Apple exige aussi une
capture d'écran de l'écran Premium et une description pour la validation.

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

## Ce qui reste à traiter avant une vraie soumission

- **Les identifiants AdMob iOS sont ceux de test de Google**
  (`ca-app-pub-3940256099942544…`), dans `Info.plist` comme dans
  `app/lib/core/constants.dart`. Les laisser signifie zéro revenu, et c'est
  contraire aux règles d'AdMob. Les identifiants Android, eux, sont réels.
- **Le suivi publicitaire.** Si tu veux des publicités personnalisées, iOS
  impose la demande d'autorisation de suivi (ATT) et la clé
  `NSUserTrackingUsageDescription`. Sans elle, il faut configurer AdMob en
  publicités non personnalisées. En l'état, ni l'une ni l'autre n'est faite.
- **L'orientation.** `Info.plist` limite l'iPhone au portrait alors que
  `main.dart` demande aussi le paysage et que la mise en page s'y adapte
  depuis la refonte. À aligner dans un sens ou dans l'autre.
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
