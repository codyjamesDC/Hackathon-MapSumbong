import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class ReportsProvider with ChangeNotifier {
  List<Report> _reports = [];
  bool _isLoading = false;
  String? _error;
  Report? _selectedReport;
  String? _selectError;

  List<Report> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Report? get selectedReport => _selectedReport;
  String? get selectError => _selectError;

  // ── Filtered views ────────────────────────────────────────────────────────
  List<Report> getReportsByStatus(String status) =>
      _reports.where((r) => r.status == status).toList();

  List<Report> getReportsByUser(String reporterAnonymousId) =>
      _reports.where((r) => r.reporterAnonymousId == reporterAnonymousId).toList();

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> loadReports({String? userId, String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (userId != null) {
        _reports = await SupabaseService.getUserReports(userId);
      } else if (status != null) {
        _reports = await SupabaseService.getReportsByStatus(status);
      } else {
        _reports = await SupabaseService.getAllReports();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  // Uses ApiService.submitReport which takes named params and returns
  // Map<String, dynamic> — then re-fetches the full Report from Supabase.
  Future<Report?> submitReport(Report report) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.submitReport(
        reportData: report.toJson(),
        reporterAnonymousId: report.reporterAnonymousId,
      );

      final reportId = result['report_id'] as String?;
      if (reportId == null) throw Exception('No report_id in response');

      // Re-fetch the saved report so we have all server-generated fields
      final saved = await SupabaseService.getReportById(reportId);
      _reports.insert(0, saved);
      return saved;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Status update ─────────────────────────────────────────────────────────
  Future<void> updateReportStatus(
    String reportId,
    String newStatus, {
    String? resolutionNote,
    String? updatedBy,
  }) async {
    try {
      await ApiService.updateReportStatus(
        reportId: reportId,
        status: newStatus,
        resolutionNote: resolutionNote,
        updatedBy: updatedBy,
      );

      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _reports[index] = _reports[index].copyWith(status: newStatus);
      }
      if (_selectedReport?.id == reportId) {
        _selectedReport = _selectedReport!.copyWith(status: newStatus);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  // ── Select a single report ────────────────────────────────────────────────
  Future<void> selectReport(String reportId) async {
    _isLoading = true;
    _selectError = null;
    notifyListeners();

    try {
      _selectedReport = await SupabaseService.getReportById(reportId);
      _selectError = null;
    } catch (e) {
      _selectError = e.toString();
      _selectedReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedReport() {
    _selectedReport = null;
    _selectError = null;
    notifyListeners();
  }

  Future<void> refreshReports() => loadReports();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Real-time subscriptions ───────────────────────────────────────────────
  StreamSubscription? _reportsSubscription;

  void subscribeToReportUpdates(String reporterAnonymousId) {
    _reportsSubscription?.cancel();
    _reportsSubscription =
        SupabaseService.subscribeToAllReports().listen((data) {
      _reports = data
          .map((json) => Report.fromJson(json))
          .where((r) => r.reporterAnonymousId == reporterAnonymousId)
          .toList();
      notifyListeners();
    });
  }

  void subscribeToAllReports() {
    _reportsSubscription?.cancel();
    _reportsSubscription =
        SupabaseService.subscribeToAllReports().listen((data) {
      _reports = data.map((json) => Report.fromJson(json)).toList();
      notifyListeners();
    });
  }

  void unsubscribeFromReports() {
    _reportsSubscription?.cancel();
    _reportsSubscription = null;
  }
}