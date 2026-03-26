import 'package:flutter/material.dart';
import '../models/report.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback? onTap;
  final bool compact;

  const ReportCard({
    super.key,
    required this.report,
    this.onTap,
    this.compact = false,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d nakaraon';
    if (diff.inHours > 0) return '${diff.inHours}h nakaraon';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m nakaraon';
    return 'Ngayon lang';
  }

  String _formatIssueType(String type) => type
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top colored strip based on urgency
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: report.urgency.urgencyColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        // Issue type icon
                        IssueTypeIcon(
                          issueType: report.issueType,
                          size: compact ? 36 : 42,
                        ),
                        const SizedBox(width: 12),

                        // Title + time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatIssueType(report.issueType),
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: compact ? 13 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _timeAgo(report.createdAt),
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(status: report.status, small: compact),
                            if (report.isResolutionPendingProof) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.35),
                                  ),
                                ),
                                child: const Text(
                                  'pending proof',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9A6B00),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Description
                    Text(
                      report.description,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: compact ? 12 : 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Footer row
                    Row(
                      children: [
                        // Location
                        if (report.locationText != null || report.barangay.isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    report.locationText ?? report.barangay,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Spacer(),

                        // Urgency badge
                        UrgencyBadge(urgency: report.urgency, small: true),

                        // Photo indicator
                        if (report.imageUrls.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_rounded,
                                  size: 10,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${report.imageUrls.length}',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Resolution note preview
                    if (report.resolutionNote != null && !compact) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lowLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.low.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.low,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                report.resolutionNote!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  color: AppColors.low,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}