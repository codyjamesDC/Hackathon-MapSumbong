import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
    context.go('/create-report');
  }

  Future<void> _callHotline(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hindi mabuksan ang tawag para sa $number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
      _reportsProvider?.loadReports();
      _reportsProvider?.subscribeToAllReports();
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
          await reportsProvider.loadReports();
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
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroBanner(
                  displayName: user?.getDisplayName(),
                  reports: reportsProvider.reports,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  0,
                ),
                child: _QuickActionsCard(
                  onCreateReport: _startNewReport,
                  onOpenMap: () => context.go('/map'),
                  onOpenReports: () => context.push('/reports'),
                  onCallEmergencyHotline: () => context.push('/emergency'),
                  onCallNationalEmergency: () => _callHotline('911'),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: _AnalyticsCard(reports: reportsProvider.reports),
              ),
            ),

            // ── Recent Reports ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
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
                    subtitle:
                        'Tumulong sa iyong komunidad sa pag-uulat ng mga problema.',
                    buttonLabel: 'Lumikha ng Report',
                    onButton: _startNewReport,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  100,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
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
                  }, childCount: reportsProvider.reports.length.clamp(0, 5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String? displayName;
  final List<Report> reports;

  const _HeroBanner({this.displayName, required this.reports});

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
              if (reports.isNotEmpty) _QuickStatus(reports: reports),
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
        _QuickChip(
          label: '${reports.length} total',
          icon: Icons.list_alt_rounded,
        ),
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
        color: Colors.white.withValues(alpha: 0.15),
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
  final VoidCallback onCallEmergencyHotline;
  final VoidCallback onCallNationalEmergency;

  const _QuickActionsCard({
    required this.onCreateReport,
    required this.onOpenMap,
    required this.onOpenReports,
    required this.onCallEmergencyHotline,
    required this.onCallNationalEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.phone_in_talk_rounded,
        label: 'Call 911',
        onTap: onCallNationalEmergency,
        color: const Color(0xFFDC2626),
      ),
      _QuickActionItem(
        icon: Icons.local_hospital_rounded,
        label: 'Emergency Hotline',
        onTap: onCallEmergencyHotline,
        color: AppColors.critical,
      ),
      _QuickActionItem(
        icon: Icons.auto_awesome_rounded,
        label: 'New Report',
        onTap: onCreateReport,
        color: AppColors.primary,
      ),
      _QuickActionItem(
        icon: Icons.list_alt_rounded,
        label: 'Mga Report',
        onTap: onOpenReports,
        color: AppColors.textSecondary,
      ),
      _QuickActionItem(
        icon: Icons.map_rounded,
        label: 'Mapa',
        onTap: onOpenMap,
        color: AppColors.accent,
      ),
    ];

    final placeholderCount = actions.length >= 8 ? 0 : 8 - actions.length;
    final gridItems = <_QuickActionItem?>[
      ...actions,
      ...List<_QuickActionItem?>.filled(placeholderCount, null),
    ];

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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gridItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = gridItems[index];
              if (item == null) {
                return const _QuickActionPlaceholderTile();
              }
              return _ActionButton(
                icon: item.icon,
                label: item.label,
                onTap: item.onTap,
                color: item.color,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });
}

class _QuickActionPlaceholderTile extends StatelessWidget {
  const _QuickActionPlaceholderTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Icon(
          Icons.add_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final List<Report> reports;

  const _AnalyticsCard({required this.reports});

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
            'Analytics',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buod ng estado ng mga report sa komunidad.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _StatsRow(reports: reports),
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
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
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
