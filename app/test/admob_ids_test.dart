import 'package:flutter_test/flutter_test.dart';
import 'package:quick_convert/core/constants.dart';
import 'package:quick_convert/services/admob_service.dart';

/// Deux pannes publicitaires sont nées de la même confusion : un identifiant
/// d'application, à tilde, posé là où le SDK attend un bloc d'annonces, à
/// barre oblique. Le chargement échoue alors en silence, et rien ne le dit.
/// Ces tests rendent la confusion impossible à recommiter.
void main() {
  const blocs = {
    'admobBannerIdAndroid': AppConstants.admobBannerIdAndroid,
    'admobInterstitialIdAndroid': AppConstants.admobInterstitialIdAndroid,
    'admobBannerIdIos': AppConstants.admobBannerIdIos,
    'admobInterstitialIdIos': AppConstants.admobInterstitialIdIos,
  };

  blocs.forEach((nom, valeur) {
    test('$nom est un bloc d\'annonces, pas un identifiant d\'application', () {
      expect(
        valeur,
        matches(RegExp(r'^ca-app-pub-\d+/\d+$')),
        reason: 'Un tilde ici veut dire que c\'est l\'ID de l\'application.',
      );
    });
  });

  test('les quatre blocs sont ceux du compte, pas ceux de test', () {
    const compte = 'ca-app-pub-6336563192834287/';
    blocs.forEach((nom, valeur) {
      expect(valeur, startsWith(compte), reason: '$nom est reste un bloc de test.');
    });
  });

  // Les blocs avec recompense restent vides tant qu'ils n'existent pas dans
  // AdMob (la fonction est alors masquee) ; une fois remplis, ce sont des
  // blocs du compte, jamais ceux de test de Google.
  test('les blocs avec recompense sont vides ou ceux du compte', () {
    for (final valeur in [
      AppConstants.admobRewardedIdAndroid,
      AppConstants.admobRewardedIdIos,
    ]) {
      if (valeur.isEmpty) continue;
      expect(valeur, matches(RegExp(r'^ca-app-pub-6336563192834287/\d+$')));
    }
  });

  // Les annonces non personnalisees sont ce qui dispense l'app de la demande
  // d'autorisation de suivi d'iOS. Repasser en personnalisee sans ajouter
  // cette demande ferait rejeter la soumission.
  test('les annonces sont non personnalisees', () {
    expect(AdmobService.adRequest.nonPersonalizedAds, isTrue);
  });
}
