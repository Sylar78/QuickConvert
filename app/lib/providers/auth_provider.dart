import 'package:flutter/foundation.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // AUTH DÉSACTIVÉE

import '../models/models.dart';
import '../services/services.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  // final SupabaseService _supabase = SupabaseService(); // AUTH DÉSACTIVÉE
  final HistoryService _historyService = HistoryService();

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

  void activatePremium(DateTime expiresAt) {
    _user = _user.copyWith(isPremium: true, premiumExpiresAt: expiresAt);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
