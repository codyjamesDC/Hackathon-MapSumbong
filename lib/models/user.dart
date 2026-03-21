import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class User {
  final String id;
  final String? phoneHash;
  final String anonymousId;
  final String accountType;
  final String? displayName;
  final bool isAnonymous;
  final String? barangay;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.phoneHash,
    required this.anonymousId,
    required this.accountType,
    this.displayName,
    required this.isAnonymous,
    this.barangay,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneHash: json['phone_hash'],
      anonymousId: json['anonymous_id'],
      accountType: json['account_type'],
      displayName: json['display_name'],
      isAnonymous: json['is_anonymous'] ?? true,
      barangay: json['barangay'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  factory User.fromSupabaseUser(supabase.User supabaseUser) {
    return User(
      id: supabaseUser.id,
      phoneHash: supabaseUser.phone,
      anonymousId: supabaseUser.id, // Use user ID as anonymous ID for now
      accountType: 'resident',
      displayName: supabaseUser.userMetadata?['display_name'],
      isAnonymous: false,
      barangay: supabaseUser.userMetadata?['barangay'],
      createdAt: supabaseUser.createdAt != null ? DateTime.parse(supabaseUser.createdAt!) : DateTime.now(),
      updatedAt: supabaseUser.updatedAt != null ? DateTime.parse(supabaseUser.updatedAt!) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_hash': phoneHash,
      'anonymous_id': anonymousId,
      'account_type': accountType,
      'display_name': displayName,
      'is_anonymous': isAnonymous,
      'barangay': barangay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String getDisplayName() {
    if (!isAnonymous && displayName != null) {
      return displayName!;
    }
    return 'Anonymous User';
  }
}