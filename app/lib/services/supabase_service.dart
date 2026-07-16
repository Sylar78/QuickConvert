import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  // ─── User profile ─────────────────────────────────────────────────────────

  Future<UserModel?> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> upsertUserProfile(UserModel user) async {
    await _client.from('profiles').upsert(user.toJson());
  }

  Future<void> incrementConversions(String userId) async {
    await _client.rpc('increment_conversions_today', params: {'user_id': userId});
  }

  Future<void> resetDailyConversions(String userId) async {
    await _client
        .from('profiles')
        .update({'conversions_today': 0, 'last_reset': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  // ─── Premium ──────────────────────────────────────────────────────────────

  Future<bool> validatePremium(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('is_premium, premium_expires_at')
          .eq('id', userId)
          .single();

      final isPremium = data['is_premium'] as bool? ?? false;
      final expiresAt = data['premium_expires_at'];

      if (!isPremium) return false;
      if (expiresAt == null) return true; // lifetime
      return DateTime.parse(expiresAt as String).isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Future<void> activatePremium(String userId, DateTime expiresAt) async {
    await _client.from('profiles').update({
      'is_premium': true,
      'premium_expires_at': expiresAt.toIso8601String(),
    }).eq('id', userId);
  }

  // ─── Analytics ────────────────────────────────────────────────────────────

  Future<void> logConversion({
    required String userId,
    required String conversionType,
    required bool success,
    required int inputSizeBytes,
    required int? outputSizeBytes,
  }) async {
    try {
      await _client.from('conversion_logs').insert({
        'user_id': userId,
        'type': conversionType,
        'success': success,
        'input_size': inputSizeBytes,
        'output_size': outputSizeBytes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── Storage ──────────────────────────────────────────────────────────────

  Future<String?> uploadConvertedFile(String localPath, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}';
      final storagePath = '$userId/$fileName';

      await _client.storage
          .from('converted-files')
          .upload(storagePath, Uri.file(localPath) as dynamic);

      return _client.storage
          .from('converted-files')
          .getPublicUrl(storagePath);
    } catch (e) {
      return null;
    }
  }
}
