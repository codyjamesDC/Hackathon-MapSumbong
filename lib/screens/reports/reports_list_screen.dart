import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';
import '../../widgets/report_card.dart';
import '../../screens/location/location_picker_screen.dart';

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
    (label: 'Pending', status: 'received'),
    (label: 'In Progress', status: 'in_progress'),
    (label: 'Resolved', status: 'resolved'),
    (label: 'Reopened', status: 'reopened'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
  }

  void _loadReports() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider =
        Provider.of<ReportsProvider>(context, listen: false);
    final id = authProvider.user?.anonymousId;
    if (id != null) {
      reportsProvider.loadReports(userId: id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── New report flow ───────────────────────────────────────────────────────
  // 1. Open location picker → user drops pin
  // 2. Store GPS in MessagesProvider
  // 3. Navigate to chat/new

  Future<void> _startNewReport() async {
    // Push location picker and wait for the result (a LatLng or null)
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    // Store coordinates (even if null — chat will still work via geocoding)
    if (picked != null) {
      Provider.of<MessagesProvider>(context, listen: false)
          .setGpsCoordinates(picked.latitude, picked.longitude);
    }

    // Navigate to new report chat
    context.go('/chat/new');
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => context.go('/map'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map((t) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label),
                        if (_countFor(reportsProvider.reports, t.status) > 0)
                          ...[
                          const SizedBox(width: 6),
                          _CountBadge(
                            count: _countFor(
                                reportsProvider.reports, t.status),
                          ),
                        ],
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((t) => _ReportTabView(
                  statusFilter: t.status,
                  reportsProvider: reportsProvider,
                  onRefresh: _loadReports,
                  onTap: (id) => context.go('/reports/$id'),
                ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewReport,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Report'),
      ),
    );
  }

  int _countFor(List<Report> reports, String status) {
    if (status.isEmpty) return reports.length;
    return reports.where((r) => r.status == status).length;
  }
}

// ── Tab view ──────────────────────────────────────────────────────────────────

class _ReportTabView extends StatelessWidget {
  final String statusFilter;
  final ReportsProvider reportsProvider;
  final VoidCallback onRefresh;
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
            Icon(
              statusFilter.isEmpty
                  ? Icons.report_problem_outlined
                  : Icons.inbox_outlined,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              statusFilter.isEmpty
                  ? 'No reports yet'
                  : 'No ${statusFilter.replaceAll('_', ' ')} reports',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              statusFilter.isEmpty
                  ? 'Tap the + button to create your first report'
                  : 'Reports with this status will appear here',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
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

// ── Badge ─────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}