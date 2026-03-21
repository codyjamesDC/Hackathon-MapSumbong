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

  final String? purok;

  Report({
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

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      reporterAnonymousId: json['reporter_anonymous_id'],
      issueType: json['issue_type'],
      description: json['description'],
      photoUrl: json['photo_url'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      locationText: json['location_text'],
      barangay: json['barangay'],
      purok: json['purok'],
      urgency: json['urgency'],
      sdgTag: json['sdg_tag'],
      status: json['status'],
      resolutionNote: json['resolution_note'],
      resolutionPhotoUrl: json['resolution_photo_url'],
      residentConfirmed: json['resident_confirmed'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      resolvedBy: json['resolved_by'],
      isDeleted: json['is_deleted'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
  }

  // Helper methods
  String getUrgencyLabel() {
    const urgencyLabels = {
      'critical': 'Kritikal',
      'high': 'Mataas',
      'medium': 'Katamtaman',
      'low': 'Mababa'
    };
    return urgencyLabels[urgency] ?? urgency;
  }

  String getStatusLabel() {
    const statusLabels = {
      'received': 'Natanggap',
      'in_progress': 'Pinoproseso',
      'repair_scheduled': 'Nakaiskedyul',
      'resolved': 'Nalutas',
      'reopened': 'Muling Binuka'
    };
    return statusLabels[status] ?? status;
  }

  Color getUrgencyColor() {
    const urgencyColors = {
      'critical': Color(0xFFEF4444),  // Red
      'high': Color(0xFFF59E0B),     // Orange
      'medium': Color(0xFFFBBF24),   // Yellow
      'low': Color(0xFF10B981),      // Green
    };
    return urgencyColors[urgency] ?? Colors.grey;
  }

  bool get isResolved => status == 'resolved';
  bool get isInProgress => status == 'in_progress';
  bool get isCritical => urgency == 'critical';

  // Getters for compatibility with UI
  String get userId => reporterAnonymousId;
  String? get category => issueType;
  String? get priority => urgency;
  List<String> get imageUrls => photoUrl != null ? [photoUrl!] : [];

  // CopyWith method
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