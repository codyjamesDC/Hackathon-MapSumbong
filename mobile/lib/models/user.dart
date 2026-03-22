import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class User {
  final String id;
  final String? phoneHash;
  final String anonymousId;
  final String accountType;
  final String? displayName;
  final bool isAnonymous;
  final String? barangay;
  final String? purok;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    this.phoneHash,
    required this.anonymousId,
    required this.accountType,
    this.displayName,
    required this.isAnonymous,
    this.barangay,
    this.purok,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phoneHash: json['phone_hash'] as String?,
      anonymousId: json['anonymous_id'] as String,
      accountType: json['account_type'] as String? ?? 'resident',
      displayName: json['display_name'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? true,
      barangay: json['barangay'] as String?,
      purok: json['purok'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  /// Build a lightweight User from a Supabase auth user.
  /// The full profile (anonymous_id, barangay, etc.) lives in the `users` table
  /// and should be fetched separately; this just captures auth-level fields.
  factory User.fromSupabaseUser(supabase.User supabaseUser) {
    final meta = supabaseUser.userMetadata ?? {};
    return User(
      id: supabaseUser.id,
      phoneHash: supabaseUser.phone,
      // Anonymous ID is stored in user_metadata after first sign-in,
      // or falls back to the Supabase UID until the DB profile loads.
      anonymousId: meta['anonymous_id'] as String? ?? supabaseUser.id,
      accountType: meta['account_type'] as String? ?? 'resident',
      displayName: meta['display_name'] as String?,
      isAnonymous: meta['is_anonymous'] as bool? ?? true,
      barangay: meta['barangay'] as String?,
      purok: meta['purok'] as String?,
      createdAt: _parseDate(supabaseUser.createdAt),
      updatedAt: _parseDate(supabaseUser.updatedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_hash': phoneHash,
        'anonymous_id': anonymousId,
        'account_type': accountType,
        'display_name': displayName,
        'is_anonymous': isAnonymous,
        'barangay': barangay,
        'purok': purok,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String getDisplayName() {
    if (!isAnonymous && displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    return 'Anonymous Resident';
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}