import 'package:flutter/foundation.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // AUTH DÉSACTIVÉE

import '../core/constants.dart';
import '../models/models.dart';
import '../services/services.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  // final SupabaseService _supabase = SupabaseService(); // AUTH DÉSACTIVÉE
  final HistoryService _historyService = HistoryService();
  final EntitlementService _entitlements = EntitlementService();

  AuthState _authState = AuthState.unknown;
  UserModel _user = UserModel.guest();
  String? _error;

  AuthState get authState => _authState;
  UserModel get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Auth temporairement désactivée — l'utilisateur démarre en mode invité.
    _authState = AuthState.unauthenticated;
    _user = UserModel.guest();
    syncEntitlement();
    refreshQuota();

    // TODO: réactiver quand Supabase est correctement configuré,
    // et repasser AppConstants.authEnabled à true.
  }

  /// Relit le quota du jour depuis l'historique persisté.
  ///
  /// C'est la seule source de vérité : c'est elle que
  /// [ConversionProvider] consulte pour autoriser ou refuser une conversion.
  /// Avant, l'écran d'accueil affichait un compteur gardé uniquement en
  /// mémoire, qui repartait à zéro au lancement pendant que la limite réelle,
  /// elle, tenait toujours — l'app annonçait « 5 conversions restantes » puis
  /// refusait de convertir.
  void refreshQuota() {
    final used = _historyService.todayCount;
    if (used == _user.conversionsToday) return;
    _user = _user.copyWith(conversionsToday: used);
    notifyListeners();
  }

  // AUTH DÉSACTIVÉE — les méthodes de compte sont des no-ops.

  Future<bool> signUp(String email, String password) async {
    _error = 'La création de compte arrive bientôt.';
    notifyListeners();
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    _error = 'La connexion arrive bientôt.';
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _authState = AuthState.unauthenticated;
    _user = UserModel.guest();
    refreshQuota();
    notifyListeners();
  }

  /// Relit l'abonnement persisté et l'applique à l'utilisateur courant.
  ///
  /// C'est le seul chemin par lequel `isPremium` change. `SubscriptionProvider`
  /// l'appelle dès que le store accorde ou retire un abonnement, et `_init`
  /// au lancement — sans quoi un achat payé la veille serait oublié au
  /// redémarrage de l'app.
  void syncEntitlement() {
    final entitlement = _entitlements.read();
    if (entitlement.isActive == _user.isPremium &&
        entitlement.expiresAt == _user.premiumExpiresAt) {
      return;
    }

    // Construit explicitement plutôt que par `copyWith` : il faut pouvoir
    // remettre `premiumExpiresAt` à null quand l'abonnement est retiré.
    _user = UserModel(
      id: _user.id,
      email: _user.email,
      isPremium: entitlement.isActive,
      conversionsToday: _user.conversionsToday,
      premiumExpiresAt: entitlement.expiresAt,
      createdAt: _user.createdAt,
    );
    notifyListeners();
  }

  /// Active le Premium sans passer par un store. Réservé au mode débogage :
  /// `PremiumScreen` ne l'appelle que sous `kDebugMode`.
  Future<void> activateDebugPremium(Duration duration) async {
    await _entitlements.grant(
      productId: AppConstants.premiumMonthlyId,
      source: EntitlementSource.debug,
      expiresAt: DateTime.now().add(duration),
    );
    syncEntitlement();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
