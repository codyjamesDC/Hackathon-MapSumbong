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

  List<Report> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Report? get selectedReport => _selectedReport;

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
  Future<Report> submitReport(Report report) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final submitted = await ApiService.submitReport(report);
      _reports.insert(0, submitted);
      return submitted;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Status update ─────────────────────────────────────────────────────────
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      await ApiService.updateReportStatus(
        reportId: reportId,
        status: newStatus,
      );

      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _reports[index] = _reports[index].copyWith(status: newStatus);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  // ── Select a single report ────────────────────────────────────────────────
  Future<void> selectReport(String reportId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedReport = await SupabaseService.getReportById(reportId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedReport() {
    _selectedReport = null;
    notifyListeners();
  }

  Future<void> refreshReports() => loadReports();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Real-time subscriptions ───────────────────────────────────────────────
  StreamSubscription? _reportsSubscription;

  /// Subscribe to updates for a specific user's reports.
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

  /// Subscribe to all reports (for officials / admin views).
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