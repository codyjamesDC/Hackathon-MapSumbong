import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportsProvider>(context, listen: false)
          .selectReport(widget.reportId);
    });
  }

  Future<void> _refreshReport() {
    return Provider.of<ReportsProvider>(context, listen: false)
        .selectReport(widget.reportId);
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final report = reportsProvider.selectedReport;

    final appBar = AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
        color: AppColors.textPrimary,
        onPressed: () =>
            Navigator.of(context).canPop() ? context.pop() : context.go('/reports'),
      ),
      title: Text(
        report != null ? 'Report ${report.id}' : 'Report',
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (report != null)
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: AppColors.primary),
            tooltip: 'Chat with authorities',
            onPressed: () => context.push('/chat/${report.id}'),
          ),
      ],
    );

    if (reportsProvider.isLoading && report == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const AppLoader(message: 'Nilo-load ang report...'),
      );
    }

    if (reportsProvider.selectError != null && report == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Hindi ma-load ang report',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reportsProvider.selectError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _refreshReport,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Subukan ulit'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  child: const Text('Bumalik sa listahan'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (report == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Hindi natagpuan ang report',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/reports'),
                child: const Text('Bumalik sa listahan'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshReport,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _HeaderCard(report: report),
            const SizedBox(height: 14),

            // Status banner
            _StatusBanner(status: report.status),
            const SizedBox(height: 20),

            // Issue type + urgency row
            Row(
              children: [
                _InfoChip(
                  label: _formatIssueType(report.issueType),
                  color: Colors.blue,
                  icon: _issueIcon(report.issueType),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  label: report.urgencyLabel,
                  color: report.urgencyColor,
                  icon: Icons.warning_amber,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Description
            _SectionLabel('Description'),
            const SizedBox(height: 6),
            Text(report.description, style: const TextStyle(fontSize: 15)),

            const SizedBox(height: 20),

            // Location
            _SectionLabel('Location'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (report.locationText != null) report.locationText!,
                      report.barangay,
                      if (report.purok != null) 'Purok ${report.purok}',
                    ].join(', '),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'GPS: ${report.latitude.toStringAsFixed(6)}, '
              '${report.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Timestamps
            _SectionLabel('Timeline'),
            const SizedBox(height: 10),
            _TimelineCard(report: report),

            // SDG tag
            if (report.sdgTag != null) ...[
              const SizedBox(height: 20),
              _SectionLabel('SDG Tag'),
              const SizedBox(height: 6),
              _InfoChip(
                label: report.sdgTag!,
                color: Colors.green,
                icon: Icons.public,
              ),
            ],

            // Photos
            if (report.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionLabel('Photos'),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: report.imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: report.imageUrls[i],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                            child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Resolution
            if (report.resolutionNote != null) ...[
              const SizedBox(height: 24),
              _SectionLabel('Resolution'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          report.resolvedBy ?? 'Barangay officials',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(report.resolutionNote!),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/chat/${report.id}'),
                icon: const Icon(Icons.chat),
                label: const Text('Chat with Authorities'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),

            if (report.isResolved) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReopenDialog(context, report),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Issue Still Exists? Reopen'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareReport(context, report),
                icon: const Icon(Icons.share),
                label: const Text('Share Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReopenDialog(BuildContext context, Report report) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe why the issue still exists:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Baha pa rin sa kanto namin...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final provider =
                  Provider.of<ReportsProvider>(context, listen: false);
              final anon = Provider.of<AuthProvider>(context, listen: false)
                  .user
                  ?.anonymousId;
              try {
                await provider.updateReportStatus(
                  report.id,
                  'reopened',
                  resolutionNote: reasonCtrl.text.trim(),
                  updatedBy: anon,
                );
                await provider.selectReport(report.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report reopened.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'Hindi na-reopen.'),
                      backgroundColor: AppColors.critical,
                    ),
                  );
                }
              }
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
  }

  void _shareReport(BuildContext context, Report report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report ID: ${report.id} — share this with your neighbors'),
      ),
    );
  }

  String _formatIssueType(String type) => type
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  IconData _issueIcon(String type) {
    switch (type) {
      case 'flood':
        return Icons.water;
      case 'fire':
        return Icons.local_fire_department;
      case 'road':
      case 'pothole':
        return Icons.construction;
      case 'power':
      case 'broken_streetlight':
        return Icons.bolt;
      case 'waste':
      case 'garbage':
        return Icons.delete;
      case 'water':
        return Icons.water_drop;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.report_problem;
    }
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status.toLowerCase()) {
      'received' => (Colors.blue, 'Received — awaiting review', Icons.inbox),
      'in_progress' => (
          Colors.orange,
          'In Progress — being handled',
          Icons.engineering
        ),
      'repair_scheduled' => (
          Colors.purple,
          'Repair Scheduled',
          Icons.calendar_today
        ),
      'resolved' => (Colors.green, 'Resolved ✓', Icons.check_circle),
      'reopened' => (Colors.red, 'Reopened — under review', Icons.refresh),
      _ => (Colors.grey, status, Icons.info),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _InfoChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final DateTime dt;
  const _TimelineRow(this.label, this.dt);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Text(
            '${dt.day}/${dt.month}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Report report;

  const _HeaderCard({required this.report});

  String _formatIssueType(String type) => type
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  IconData _issueIcon(String type) {
    switch (type) {
      case 'flood':
        return Icons.water;
      case 'fire':
        return Icons.local_fire_department;
      case 'road':
      case 'pothole':
        return Icons.construction;
      case 'power':
      case 'broken_streetlight':
        return Icons.bolt;
      case 'waste':
      case 'garbage':
        return Icons.delete;
      case 'water':
        return Icons.water_drop;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.report_problem;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InfoChip(
                label: report.statusLabel,
                color: report.urgencyColor,
                icon: Icons.flag_rounded,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                label: _formatIssueType(report.issueType),
                color: AppColors.primary,
                icon: _issueIcon(report.issueType),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.locationText?.isNotEmpty == true
                      ? '${report.locationText}, ${report.barangay}'
                      : report.barangay,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Nireport noong ${_formatDate(report.createdAt)}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Report report;

  const _TimelineCard({required this.report});

  List<({String title, String subtitle, DateTime time})> get _events {
    final events = <({String title, String subtitle, DateTime time})>[
      (
        title: 'Report submitted',
        subtitle: 'Natanggap ng system ang ulat mo.',
        time: report.createdAt,
      ),
      (
        title: 'Current status: ${report.statusLabel}',
        subtitle: 'Huling update sa report status.',
        time: report.updatedAt,
      ),
    ];

    if (report.resolvedAt != null) {
      events.add((
        title: 'Marked resolved',
        subtitle: report.resolutionNote?.isNotEmpty == true
            ? report.resolutionNote!
            : 'Tinarkahang resolved ng barangay.',
        time: report.resolvedAt!,
      ));
    }

    events.sort((a, b) => b.time.compareTo(a.time));
    return events;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(events.length, (index) {
          final event = events[index];
          final isLatest = index == 0;
          final hasNext = index < events.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isLatest ? AppColors.primary : AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (hasNext)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: AppColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color:
                                isLatest ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.subtitle,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(event.time),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}