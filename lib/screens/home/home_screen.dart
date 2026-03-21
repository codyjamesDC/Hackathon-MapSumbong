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
    // Load user's reports when screen opens
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    if (authProvider.user?.id != null) {
      reportsProvider.loadReports(userId: authProvider.user!.id);
      reportsProvider.subscribeToReportUpdates(authProvider.user!.id);
    }
  }

  @override
  void dispose() {
    // Unsubscribe when leaving screen
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
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome section
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${authProvider.user?.displayName ?? 'Resident'}!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Report disasters and track their resolution in your community.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/reports'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Reports section
          Expanded(
            child: reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : reportsProvider.reports.isEmpty
                    ? _buildEmptyState()
                    : _buildReportsList(reportsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/reports'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No reports yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first disaster report to get started',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/reports'),
            child: const Text('Create Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(ReportsProvider reportsProvider) {
    final recentReports = reportsProvider.reports.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/reports'),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentReports.length,
            itemBuilder: (context, index) {
              final report = recentReports[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ReportCard(
                  report: report,
                  onTap: () => context.go('/reports/${report.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}