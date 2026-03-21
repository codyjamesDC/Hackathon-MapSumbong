import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    final anonymousId = authProvider.user?.anonymousId;
    if (anonymousId != null) {
      reportsProvider.loadReports(userId: anonymousId);
      reportsProvider.subscribeToReportUpdates(anonymousId);
    }
  }

  @override
  void dispose() {
    Provider.of<ReportsProvider>(context, listen: false).unsubscribeFromReports();
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${authProvider.user?.displayName ?? 'Resident'}!',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Report disasters and track their resolution in your community.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/reports'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create new report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Reports list
          Expanded(
            child: reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : reportsProvider.reports.isEmpty
                    ? _EmptyState(onCreateTap: () => context.go('/reports'))
                    : _RecentReportsList(
                        reports: reportsProvider.reports,
                        onViewAll: () => context.go('/reports'),
                        onTap: (id) => context.go('/reports/$id'),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/reports'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.report_problem_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No reports yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Create your first disaster report to get started',
              style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: onCreateTap, child: const Text('Create report')),
        ],
      ),
    );
  }
}

class _RecentReportsList extends StatelessWidget {
  final List reports;
  final VoidCallback onViewAll;
  final void Function(String reportId) onTap;

  const _RecentReportsList({
    required this.reports,
    required this.onViewAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recent = reports.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent reports',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final report = recent[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ReportCard(
                  report: report,
                  onTap: () => onTap(report.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}