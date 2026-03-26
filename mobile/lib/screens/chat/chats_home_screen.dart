import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_theme.dart';

class ChatsHomeScreen extends StatefulWidget {
  const ChatsHomeScreen({super.key});

  @override
  State<ChatsHomeScreen> createState() => _ChatsHomeScreenState();
}

class _ChatsHomeScreenState extends State<ChatsHomeScreen> {
  Future<void> _loadReportHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reports = Provider.of<ReportsProvider>(context, listen: false);
    final id = auth.user?.anonymousId;
    if (id != null) {
      await reports.loadReports(userId: id);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final anonymousId = authProvider.user?.anonymousId;
    final reports =
        reportsProvider.reports
            .where(
              (r) =>
                  anonymousId != null && r.reporterAnonymousId == anonymousId,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chats')),
      body: RefreshIndicator(
        onRefresh: _loadReportHistory,
        child: reportsProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : reports.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 36),
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 52,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Wala pang chat history',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ang chat history ay nakabase sa mga report na naisumite mo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/create-report'),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Add New Report'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return ListTile(
                    tileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primarySurface,
                      child: Icon(Icons.chat_rounded, color: AppColors.primary),
                    ),
                    title: Text(
                      report.issueType
                          .split('_')
                          .map(
                            (w) => w.isEmpty
                                ? w
                                : '${w[0].toUpperCase()}${w.substring(1)}',
                          )
                          .join(' '),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Report ${report.id} • ${report.statusLabel}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/chat/${report.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
        label: const Text(
          'New Chat',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
