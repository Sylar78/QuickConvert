import 'package:flutter/foundation.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // AUTH DÉSACTIVÉE
import '../models/models.dart';
// import '../services/services.dart'; // AUTH DÉSACTIVÉE

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  // final SupabaseService _supabase = SupabaseService(); // AUTH DÉSACTIVÉE

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
    // Auth temporairement désactivée — l'utilisateur démarre en mode invité
    _authState = AuthState.unauthenticated;
    _user = UserModel.guest();

    // TODO: réactiver quand Supabase est correctement configuré
    // try {
    //   _supabase.authStateChanges.listen((data) async {
    //     final supaUser = data.session?.user;
    //     if (supaUser != null) {
    //       _authState = AuthState.authenticated;
    //       final profile = await _supabase.getUserProfile();
    //       _user = profile ?? UserModel(
    //         id: supaUser.id,
    //         email: supaUser.email,
    //         createdAt: DateTime.now(),
    //       );
    //     } else {
    //       _authState = AuthState.unauthenticated;
    //       _user = UserModel.guest();
    //     }
    //     notifyListeners();
    //   });
    // } catch (e) {
    //   debugPrint('Auth init error: $e');
    //   _authState = AuthState.unauthenticated;
    // }
  }

  // AUTH DÉSACTIVÉE — toutes les méthodes sont des no-ops pour les tests

  Future<bool> signUp(String email, String password) async {
    // TODO: réactiver avec Supabase
    _error = 'Inscription désactivée en mode test';
    notifyListeners();
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    // TODO: réactiver avec Supabase
    _error = 'Connexion désactivée en mode test';
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    // TODO: réactiver avec Supabase
  }

  void incrementConversions() {
    _user = _user.copyWith(conversionsToday: _user.conversionsToday + 1);
    notifyListeners();
  }

  void activatePremium(DateTime expiresAt) {
    _user = _user.copyWith(isPremium: true, premiumExpiresAt: expiresAt);
    // TODO: réactiver avec Supabase
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
