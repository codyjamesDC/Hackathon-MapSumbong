import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
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
    (label: 'Lahat', status: ''),
    (label: 'Nakabinbin', status: 'received'),
    (label: 'Ginagawa', status: 'in_progress'),
    (label: 'Nalutas', status: 'resolved'),
    (label: 'Binuksan', status: 'reopened'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
  }

  void _loadReports() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reports = Provider.of<ReportsProvider>(context, listen: false);
    final id = auth.user?.anonymousId;
    if (id != null) reports.loadReports(userId: id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startNewReport() async {
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;

    if (picked != null) {
      Provider.of<MessagesProvider>(context, listen: false)
          .setGpsCoordinates(picked.latitude, picked.longitude);
    }

    context.go('/chat/new');
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Aking mga Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadReports,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.textSecondary),
            onPressed: () => context.go('/map'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: _tabs.map((t) {
                final count = _countFor(reportsProvider.reports, t.status);
                return Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          _CountBadge(count: count, active: true),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _ReportTabView(
          statusFilter: t.status,
          reportsProvider: reportsProvider,
          onRefresh: _loadReports,
          onTap: (id) => context.go('/reports/$id'),
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewReport,
        backgroundColor: AppColors.primary,
        elevation: 0,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Bagong Report',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  int _countFor(List<Report> reports, String status) {
    if (status.isEmpty) return reports.length;
    return reports.where((r) => r.status == status).length;
  }
}

// ── Tab View ──────────────────────────────────────────────────────────────────

class _ReportTabView extends StatelessWidget {
  final String statusFilter;
  final ReportsProvider reportsProvider;
  final VoidCallback onRefresh;
  final void Function(String) onTap;

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
      return const AppLoader(message: 'Nilo-load...');
    }

    final items = _filtered;

    if (items.isEmpty) {
      return EmptyStateView(
        icon: statusFilter.isEmpty
            ? Icons.report_problem_outlined
            : Icons.inbox_outlined,
        title: statusFilter.isEmpty
            ? 'Wala pang mga report'
            : 'Walang ${statusFilter.replaceAll('_', ' ')} na reports',
        subtitle: statusFilter.isEmpty
            ? 'Pindutin ang + para lumikha ng iyong unang report'
            : 'Ang mga report na may status na ito ay makikita dito',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
  final bool active;

  const _CountBadge({required this.count, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}