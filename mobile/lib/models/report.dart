import 'package:flutter/material.dart';

class Report {
  final String id;
  final String reporterAnonymousId;
  final String issueType;
  final String description;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final String? locationText;
  final String barangay;
  final String? purok;
  final String urgency;
  final String? sdgTag;
  final String status;
  final String? resolutionNote;
  final String? resolutionPhotoUrl;
  final bool? residentConfirmed;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Report({
    required this.id,
    required this.reporterAnonymousId,
    required this.issueType,
    required this.description,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.locationText,
    required this.barangay,
    this.purok,
    required this.urgency,
    this.sdgTag,
    required this.status,
    this.resolutionNote,
    this.resolutionPhotoUrl,
    this.residentConfirmed,
    this.resolvedAt,
    this.resolvedBy,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _asDate(dynamic value, DateTime fallback) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Report(
      id: (json['id'] ?? '').toString(),
      reporterAnonymousId: (json['reporter_anonymous_id'] ?? 'ANON-UNKNOWN').toString(),
      issueType: (json['issue_type'] ?? 'other').toString(),
      description: (json['description'] ?? '').toString(),
      photoUrl: json['photo_url'] as String?,
      latitude: _asDouble(json['latitude'], 14.6942),
      longitude: _asDouble(json['longitude'], 120.9834),
      locationText: json['location_text'] as String?,
      barangay: (json['barangay'] ?? 'unknown').toString(),
      purok: json['purok'] as String?,
      urgency: (json['urgency'] ?? 'medium').toString(),
      sdgTag: json['sdg_tag'] as String?,
      status: (json['status'] ?? 'received').toString(),
      resolutionNote: json['resolution_note'] as String?,
      resolutionPhotoUrl: json['resolution_photo_url'] as String?,
      residentConfirmed: json['resident_confirmed'] as bool?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      resolvedBy: json['resolved_by'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: _asDate(json['created_at'], now),
      updatedAt: _asDate(json['updated_at'], now),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter_anonymous_id': reporterAnonymousId,
        'issue_type': issueType,
        'description': description,
        'photo_url': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'location_text': locationText,
        'barangay': barangay,
        'purok': purok,
        'urgency': urgency,
        'sdg_tag': sdgTag,
        'status': status,
        'resolution_note': resolutionNote,
        'resolution_photo_url': resolutionPhotoUrl,
        'resident_confirmed': residentConfirmed,
        'resolved_at': resolvedAt?.toIso8601String(),
        'resolved_by': resolvedBy,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // ── Status helpers ────────────────────────────────────────────────────────
  bool get isResolved => status == 'resolved';
  bool get isInProgress => status == 'in_progress';
  bool get isCritical => urgency == 'critical';

  // ── Display helpers ───────────────────────────────────────────────────────
  String get urgencyLabel {
    const labels = {
      'critical': 'Kritikal',
      'high': 'Mataas',
      'medium': 'Katamtaman',
      'low': 'Mababa',
    };
    return labels[urgency] ?? urgency;
  }

  String get statusLabel {
    const labels = {
      'received': 'Natanggap',
      'in_progress': 'Pinoproseso',
      'repair_scheduled': 'Nakaiskedyul',
      'resolved': 'Nalutas',
      'reopened': 'Muling Binuka',
    };
    return labels[status] ?? status;
  }

  Color get urgencyColor {
    const colors = {
      'critical': Color(0xFFEF4444),
      'high': Color(0xFFF59E0B),
      'medium': Color(0xFFFBBF24),
      'low': Color(0xFF10B981),
    };
    return colors[urgency] ?? Colors.grey;
  }

  /// All photo URLs as a list (supports future multi-photo expansion).
  List<String> get imageUrls => photoUrl != null ? [photoUrl!] : [];

  // ── copyWith ──────────────────────────────────────────────────────────────
  Report copyWith({
    String? id,
    String? reporterAnonymousId,
    String? issueType,
    String? description,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? locationText,
    String? barangay,
    String? purok,
    String? urgency,
    String? sdgTag,
    String? status,
    String? resolutionNote,
    String? resolutionPhotoUrl,
    bool? residentConfirmed,
    DateTime? resolvedAt,
    String? resolvedBy,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id ?? this.id,
      reporterAnonymousId: reporterAnonymousId ?? this.reporterAnonymousId,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationText: locationText ?? this.locationText,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      urgency: urgency ?? this.urgency,
      sdgTag: sdgTag ?? this.sdgTag,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolutionPhotoUrl: resolutionPhotoUrl ?? this.resolutionPhotoUrl,
      residentConfirmed: residentConfirmed ?? this.residentConfirmed,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}