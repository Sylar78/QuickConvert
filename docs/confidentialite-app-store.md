# Confidentialité de l'app (App Store Connect)

Réponses au questionnaire **App Store Connect > QuickDocumentConvert >
Confidentialité de l'app**. Elles décrivent ce que l'app collecte réellement
et doivent rester d'accord avec deux fichiers du dépôt :

- `app/ios/Runner/PrivacyInfo.xcprivacy`, le manifeste embarqué dans l'app ;
- `app/web/privacy/index.html`, la politique publiée sur
  https://quickconvert.app/privacy.

Toute nouvelle collecte (analytics, compte, conversion en ligne, autre régie
publicitaire) oblige à mettre à jour les trois.

## Politique de confidentialité

- URL : `https://quickconvert.app/privacy`

## Collecte de données

**Collectez-vous des données à partir de cette app ?** Oui.

Seul le kit Google AdMob collecte des données, dans la version gratuite. Les
fichiers convertis, l'historique, les réglages et l'état de l'abonnement
restent sur l'appareil : pour Apple, ce ne sont pas des données collectées.
Les achats passent par l'App Store sans que l'app n'envoie rien à un serveur.

Types à cocher :

| Catégorie | Type | Utilisations |
| --- | --- | --- |
| Localisation | Position approximative | Publicité tierce, Analyses |
| Identifiants | Identifiant de l'appareil | Publicité tierce, Analyses, Fonctionnalités de l'app |
| Données d'utilisation | Interactions avec le produit | Publicité tierce, Analyses |
| Données d'utilisation | Données publicitaires | Publicité tierce |
| Diagnostics | Données de plantage | Analyses |
| Diagnostics | Données de performance | Analyses |
| Diagnostics | Autres données de diagnostic | Analyses |

Pour **chacun** de ces types :

- **Associées à l'identité de l'utilisateur ?** Non. L'app n'a pas de compte
  et ne relie rien à une personne.
- **Utilisées à des fins de suivi ?** Non. Les annonces sont non
  personnalisées (`AdmobService.adRequest`) et l'app ne demande pas
  l'autorisation de suivi (ATT) ; l'IDFA n'est donc jamais lu.

Ne rien cocher d'autre : pas de coordonnées, pas de contenu utilisateur (les
fichiers ne quittent pas l'appareil), pas d'historique d'achats, pas de
données de santé ou financières.

## Pourquoi « Identifiant de l'appareil » sans suivi

AdMob lit l'IDFV (identifiant propre à l'éditeur) pour limiter la fréquence
des annonces et détecter la fraude. Ce n'est pas du suivi au sens d'Apple tant
qu'il n'est pas croisé avec les données d'autres entreprises, ce que les
annonces non personnalisées excluent.

## Si les annonces deviennent personnalisées un jour

Il faudra alors, ensemble : la clé `NSUserTrackingUsageDescription` et la
demande ATT dans l'app, « Utilisé pour le suivi : Oui » sur les types
publicitaires ici, `NSPrivacyTracking` à vrai et les domaines de suivi de
Google dans le manifeste, et la mise à jour de la politique.
