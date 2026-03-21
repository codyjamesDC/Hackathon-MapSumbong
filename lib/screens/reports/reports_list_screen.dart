import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/report_card.dart';
import '../../models/report.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: 'All', status: ''),
    (label: 'Received', status: 'received'),
    (label: 'In Progress', status: 'in_progress'),
    (label: 'Resolved', status: 'resolved'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    // Use anonymousId — the key stored in the reports table
    final anonymousId = authProvider.user?.anonymousId;
    if (anonymousId != null) {
      reportsProvider.loadReports(userId: anonymousId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final id = authProvider.user?.anonymousId;
              if (id != null) reportsProvider.loadReports(userId: id);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((t) => _ReportTabView(
                  statusFilter: t.status,
                  reportsProvider: reportsProvider,
                  onRefresh: () {
                    final id = authProvider.user?.anonymousId;
                    if (id != null) reportsProvider.loadReports(userId: id);
                  },
                  onTap: (id) => context.go('/reports/$id'),
                ))
            .toList(),
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────────────────────

class _ReportTabView extends StatelessWidget {
  final String statusFilter;
  final ReportsProvider reportsProvider;
  final Future<void> Function() onRefresh;
  final void Function(String reportId) onTap;

  const _ReportTabView({
    required this.statusFilter,
    required this.reportsProvider,
    required this.onRefresh,
    required this.onTap,
  });

  List<Report> get _filtered {
    if (statusFilter.isEmpty) return reportsProvider.reports;
    return reportsProvider.getReportsByStatus(statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.report_problem_outlined,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              statusFilter.isEmpty ? 'No reports yet' : 'No $statusFilter reports',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ReportCard(
            report: items[index],
            onTap: () => onTap(items[index].id),
          ),
        ),
      ),
    );
  }
}