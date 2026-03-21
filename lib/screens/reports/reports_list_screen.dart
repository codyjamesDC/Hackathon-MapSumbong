import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/report_card.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = ['all', 'pending', 'in_progress', 'resolved'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);

    // Load reports
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    if (authProvider.user?.id != null) {
      reportsProvider.loadReports(userId: authProvider.user!.id);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.user?.id != null) {
                reportsProvider.loadReports(userId: authProvider.user!.id);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusFilters.map((status) => _buildReportsList(status)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateReportDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReportsList(String statusFilter) {
    final reportsProvider = Provider.of<ReportsProvider>(context);

    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredReports = statusFilter == 'all'
        ? reportsProvider.reports
        : reportsProvider.getReportsByStatus(statusFilter);

    if (filteredReports.isEmpty) {
      return _buildEmptyState(statusFilter);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.user?.id != null) {
          await reportsProvider.loadReports(userId: authProvider.user!.id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReports.length,
        itemBuilder: (context, index) {
          final report = filteredReports[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ReportCard(
              report: report,
              onTap: () => context.go('/reports/${report.id}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String statusFilter) {
    String message;
    String subMessage;

    switch (statusFilter) {
      case 'pending':
        message = 'No pending reports';
        subMessage = 'Your submitted reports will appear here';
        break;
      case 'in_progress':
        message = 'No reports in progress';
        subMessage = 'Reports being worked on will appear here';
        break;
      case 'resolved':
        message = 'No resolved reports';
        subMessage = 'Completed reports will appear here';
        break;
      default:
        message = 'No reports yet';
        subMessage = 'Create your first disaster report';
    }

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
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (statusFilter == 'all')
            ElevatedButton(
              onPressed: () => _showCreateReportDialog(context),
              child: const Text('Create Report'),
            ),
        ],
      ),
    );
  }

  void _showCreateReportDialog(BuildContext context) {
    // This will be implemented when we create the report creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report creation coming soon!')),
    );
  }
}