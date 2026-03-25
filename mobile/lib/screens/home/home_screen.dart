import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/report_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ReportsProvider? _reportsProvider;

  void _startNewReport() {
    context.push('/create-report');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
      final anonymousId = authProvider.user?.anonymousId;
      if (anonymousId != null) {
        _reportsProvider?.loadReports(userId: anonymousId);
        _reportsProvider?.subscribeToReportUpdates(anonymousId);
      }
    });
  }

  @override
  void dispose() {
    _reportsProvider?.unsubscribeFromReports();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final id = user?.anonymousId;
          if (id != null) await reportsProvider.loadReports(userId: id);
        },
        child: CustomScrollView(
          slivers: [
            // ── Custom App Bar ─────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 248,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.push('/map'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.push('/profile'),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroBanner(
                  displayName: user?.getDisplayName(),
                  reports: reportsProvider.reports,
                  onQuickReport: _startNewReport,
                ),
              ),
            ),

            // ── Stats Row ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                child: _StatsRow(reports: reportsProvider.reports),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _QuickActionsCard(
                  onCreateReport: _startNewReport,
                  onOpenMap: () => context.push('/map'),
                  onOpenReports: () => context.push('/reports'),
                ),
              ),
            ),

            // ── Recent Reports ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                child: SectionHeader(
                  title: 'Mga Kamakailang Report',
                  action: 'Tingnan lahat',
                  onAction: () => context.push('/reports'),
                ),
              ),
            ),

            if (reportsProvider.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppLoader(message: 'Nilo-load ang mga report...'),
                ),
              )
            else if (reportsProvider.reports.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: EmptyStateView(
                    icon: Icons.report_problem_outlined,
                    title: 'Wala pang mga report',
                    subtitle: 'Tumulong sa iyong komunidad sa pag-uulat ng mga problema.',
                    buttonLabel: 'Lumikha ng Report',
                    onButton: _startNewReport,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final report = reportsProvider.reports
                          .take(5)
                          .toList()[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ReportCard(
                          report: report,
                          onTap: () => context.push('/reports/${report.id}'),
                        ),
                      );
                    },
                    childCount: reportsProvider.reports.length.clamp(0, 5),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewReport,
        backgroundColor: AppColors.primary,
        elevation: 0,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Mag-ulat',
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
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String? displayName;
  final List<Report> reports;
  final VoidCallback onQuickReport;

  const _HeroBanner({
    this.displayName,
    required this.reports,
    required this.onQuickReport,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Magandang umaga';
    if (hour < 17) return 'Magandang hapon';
    return 'Magandang gabi';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1340B0), Color(0xFF1B4FD8), Color(0xFF2E63E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Greeting
              Text(
                '$_greeting!',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName ?? 'Residente',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Quick status row
              if (reports.isNotEmpty)
                _QuickStatus(reports: reports),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onQuickReport,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text(
                  'Bagong report sa AI chat',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatus extends StatelessWidget {
  final List<Report> reports;

  const _QuickStatus({required this.reports});

  @override
  Widget build(BuildContext context) {
    final pending = reports.where((r) => r.status == 'received').length;
    final resolved = reports.where((r) => r.status == 'resolved').length;

    return Row(
      children: [
        _QuickChip(label: '${reports.length} total', icon: Icons.list_alt_rounded),
        const SizedBox(width: 8),
        if (pending > 0)
          _QuickChip(
            label: '$pending nakabinbin',
            icon: Icons.pending_outlined,
            color: Colors.amber.shade300,
          ),
        if (pending > 0) const SizedBox(width: 8),
        _QuickChip(
          label: '$resolved nalutas',
          icon: Icons.check_circle_outline,
          color: Colors.green.shade300,
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _QuickChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<Report> reports;

  const _StatsRow({required this.reports});

  @override
  Widget build(BuildContext context) {
    final critical = reports.where((r) => r.urgency == 'critical').length;
    final pending = reports.where((r) => r.status == 'received').length;
    final resolved = reports.where((r) => r.status == 'resolved').length;

    return Row(
      children: [
        StatCard(
          label: 'Lahat',
          value: reports.length.toString(),
          color: AppColors.primary,
          icon: Icons.folder_open_rounded,
        ),
        const SizedBox(width: 8),
        StatCard(
          label: 'Kritikal',
          value: critical.toString(),
          color: AppColors.critical,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(width: 8),
        StatCard(
          label: 'Aktibo',
          value: pending.toString(),
          color: AppColors.medium,
          icon: Icons.hourglass_top_rounded,
        ),
        const SizedBox(width: 8),
        StatCard(
          label: 'Nalutas',
          value: resolved.toString(),
          color: AppColors.low,
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onCreateReport;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenReports;

  const _QuickActionsCard({
    required this.onCreateReport,
    required this.onOpenMap,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mabilisang Aksyon',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Report',
                  onTap: onCreateReport,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.map_rounded,
                  label: 'Mapa',
                  onTap: onOpenMap,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.list_alt_rounded,
                  label: 'Mga Report',
                  onTap: onOpenReports,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Ink(
        height: 88,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}