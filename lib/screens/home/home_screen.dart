import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';
import '../../widgets/report_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);
      final anonymousId = authProvider.user?.anonymousId;
      if (anonymousId != null) {
        reportsProvider.loadReports(userId: anonymousId);
        reportsProvider.subscribeToReportUpdates(anonymousId);
      }
    });
  }

  @override
  void dispose() {
    Provider.of<ReportsProvider>(context, listen: false)
        .unsubscribeFromReports();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reportsProvider = Provider.of<ReportsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MapSumbong'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View map',
            onPressed: () => context.go('/map'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = authProvider.user?.anonymousId;
          if (id != null) {
            await reportsProvider.loadReports(userId: id);
          }
        },
        child: CustomScrollView(
          slivers: [
            // Welcome banner
            SliverToBoxAdapter(
              child: _WelcomeBanner(
                displayName: authProvider.user?.getDisplayName(),
                onReport: () => context.go('/reports'),
              ),
            ),

            // Stats row
            if (reportsProvider.reports.isNotEmpty)
              SliverToBoxAdapter(
                child: _StatsRow(reports: reportsProvider.reports),
              ),

            // Recent reports header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Reports',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
            ),

            // Report list or empty state
            if (reportsProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reportsProvider.reports.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                    onCreateTap: () => context.go('/reports')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final report =
                          reportsProvider.reports.take(5).toList()[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ReportCard(
                          report: report,
                          onTap: () =>
                              context.go('/reports/${report.id}'),
                        ),
                      );
                    },
                    childCount: reportsProvider.reports.length
                        .clamp(0, 5),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/reports'),
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String? displayName;
  final VoidCallback onReport;
  const _WelcomeBanner({this.displayName, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${displayName ?? 'Resident'}!',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Report issues in your community and track their resolution.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.add),
            label: const Text('Create Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Report> reports;
  const _StatsRow({required this.reports});

  @override
  Widget build(BuildContext context) {
    final critical =
        reports.where((r) => r.urgency == 'critical').length;
    final pending =
        reports.where((r) => r.status == 'received').length;
    final resolved =
        reports.where((r) => r.status == 'resolved').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(
              label: 'Total', value: reports.length, color: Colors.blue),
          const SizedBox(width: 8),
          _StatCard(
              label: 'Critical', value: critical, color: Colors.red),
          const SizedBox(width: 8),
          _StatCard(
              label: 'Pending', value: pending, color: Colors.orange),
          const SizedBox(width: 8),
          _StatCard(
              label: 'Resolved', value: resolved, color: Colors.green),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.report_problem_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No reports yet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            const Text(
              'Help your community by reporting issues like floods, road damage, or waste.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create your first report'),
            ),
          ],
        ),
      ),
    );
  }
}