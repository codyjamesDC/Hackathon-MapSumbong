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

  // Get reports by status
  List<Report> getReportsByStatus(String status) {
    return _reports.where((report) => report.status == status).toList();
  }

  // Get user's reports
  List<Report> getUserReports(String userId) {
    return _reports.where((report) => report.userId == userId).toList();
  }

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

  Future<Report> submitReport(Report report) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final submittedReport = await ApiService.submitReport(report);
      _reports.insert(0, submittedReport);
      notifyListeners();
      return submittedReport;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      await ApiService.updateReportStatus(
        reportId: reportId,
        status: newStatus,
      );

      // Update local report
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

  Future<void> refreshReports() async {
    await loadReports();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Real-time subscription methods
  StreamSubscription? _reportsSubscription;

  void subscribeToReportUpdates(String userId) {
    _reportsSubscription?.cancel();
    _reportsSubscription = SupabaseService.subscribeToAllReports().listen((data) {
      final allReports = data.map((json) => Report.fromJson(json)).toList();
      _reports = allReports.where((report) => report.userId == userId).toList();
      notifyListeners();
    });
  }

  void subscribeToAllReports() {
    _reportsSubscription?.cancel();
    _reportsSubscription = SupabaseService.subscribeToAllReports().listen((data) {
      _reports = data.map((json) => Report.fromJson(json)).toList();
      notifyListeners();
    });
  }

  void unsubscribeFromReports() {
    _reportsSubscription?.cancel();
    _reportsSubscription = null;
  }
}