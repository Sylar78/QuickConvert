import '../core/constants.dart';

class UserModel {
  final String? id;
  final String? email;
  final bool isPremium;

  /// Conversions réussies aujourd'hui, relues depuis l'historique persisté
  /// par `AuthProvider.refreshQuota()`.
  final int conversionsToday;

  /// Conversions gagnées aujourd'hui en regardant une vidéo, relues par
  /// `AuthProvider.refreshQuota()` depuis `BonusService`.
  final int bonusConversions;

  final DateTime? premiumExpiresAt;
  final DateTime createdAt;

  const UserModel({
    this.id,
    this.email,
    this.isPremium = false,
    this.conversionsToday = 0,
    this.bonusConversions = 0,
    this.premiumExpiresAt,
    required this.createdAt,
  });

  /// Conversions gratuites permises aujourd'hui, vidéos comprises.
  int get dailyLimit => AppConstants.freeConversionsPerDay + bonusConversions;

  bool get canConvert => isPremium || conversionsToday < dailyLimit;

  /// Conversions gratuites restantes. `-1` pour un compte Premium, qui n'a
  /// pas de limite.
  int get remainingConversions =>
      isPremium ? -1 : (dailyLimit - conversionsToday).clamp(0, dailyLimit);

  UserModel copyWith({
    String? id,
    String? email,
    bool? isPremium,
    int? conversionsToday,
    int? bonusConversions,
    DateTime? premiumExpiresAt,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      isPremium: isPremium ?? this.isPremium,
      conversionsToday: conversionsToday ?? this.conversionsToday,
      bonusConversions: bonusConversions ?? this.bonusConversions,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.guest() => UserModel(createdAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'is_premium': isPremium,
        'conversions_today': conversionsToday,
        'premium_expires_at': premiumExpiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String?,
        email: json['email'] as String?,
        isPremium: json['is_premium'] as bool? ?? false,
        conversionsToday: json['conversions_today'] as int? ?? 0,
        premiumExpiresAt: json['premium_expires_at'] != null
            ? DateTime.parse(json['premium_expires_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}
