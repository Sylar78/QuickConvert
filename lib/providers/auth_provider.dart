import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/services.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

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
    _supabase.authStateChanges.listen((data) async {
      final supaUser = data.session?.user;
      if (supaUser != null) {
        _authState = AuthState.authenticated;
        final profile = await _supabase.getUserProfile();
        _user = profile ?? UserModel(
          id: supaUser.id,
          email: supaUser.email,
          createdAt: DateTime.now(),
        );
      } else {
        _authState = AuthState.unauthenticated;
        _user = UserModel.guest();
      }
      notifyListeners();
    });
  }

  Future<bool> signUp(String email, String password) async {
    _error = null;
    try {
      final response = await _supabase.signUpWithEmail(email, password);
      if (response.user != null) {
        final newUser = UserModel(
          id: response.user!.id,
          email: response.user!.email,
          createdAt: DateTime.now(),
        );
        await _supabase.upsertUserProfile(newUser);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Une erreur est survenue';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    try {
      final response = await _supabase.signInWithEmail(email, password);
      return response.user != null;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Une erreur est survenue';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
  }

  void incrementConversions() {
    _user = _user.copyWith(conversionsToday: _user.conversionsToday + 1);
    notifyListeners();
  }

  void activatePremium(DateTime expiresAt) {
    _user = _user.copyWith(isPremium: true, premiumExpiresAt: expiresAt);
    if (_user.id != null) {
      _supabase.activatePremium(_user.id!, expiresAt);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
