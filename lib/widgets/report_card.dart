import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportCard extends StatelessWidget {
  final Report report;

  /// Called when the card is tapped. Typically navigates to the detail screen.
  final VoidCallback? onTap;

  const ReportCard({
    super.key,
    required this.report,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: status chip + timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusChip(status: report.status),
                  Text(
                    _formatTimestamp(report.createdAt),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                report.description,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Location
              if (report.locationText != null ||
                  report.barangay.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [
                          if (report.locationText != null)
                            report.locationText!,
                          report.barangay,
                        ].join(', '),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Chips row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _CategoryChip(issueType: report.issueType),
                  _UrgencyChip(
                    urgency: report.urgency,
                    label: report.urgencyLabel,
                    color: report.urgencyColor,
                  ),
                ],
              ),

              // Photo indicator
              if (report.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.photo_library,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${report.imageUrls.length} photo'
                      '${report.imageUrls.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],

              // Resolution note preview
              if (report.resolutionNote != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 13, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.resolutionNote!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.green),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.toLowerCase()) {
      'received' => (Colors.blue, 'Received'),
      'in_progress' => (Colors.orange, 'In Progress'),
      'repair_scheduled' => (Colors.purple, 'Scheduled'),
      'resolved' => (Colors.green, 'Resolved'),
      'reopened' => (Colors.red, 'Reopened'),
      _ => (Colors.grey, status),
    };
    return _Chip(label: label, color: color);
  }
}

class _CategoryChip extends StatelessWidget {
  final String issueType;
  const _CategoryChip({required this.issueType});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'flood': Colors.blue,
      'fire': Colors.red,
      'road': Colors.blueGrey,
      'pothole': Colors.blueGrey,
      'power': Colors.amber,
      'broken_streetlight': Colors.amber,
      'waste': Colors.brown,
      'garbage': Colors.brown,
      'water': Colors.cyan,
      'emergency': Colors.red,
    };
    final color = colors[issueType] ?? Colors.blueGrey;
    final label = issueType
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return _Chip(label: label, color: color);
  }
}

class _UrgencyChip extends StatelessWidget {
  final String urgency;
  final String label;
  final Color color;
  const _UrgencyChip(
      {required this.urgency, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => _Chip(label: label, color: color);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}