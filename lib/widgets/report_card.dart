import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportCard extends StatelessWidget {
  final Report report;
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
              // Status + timestamp row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusChip(status: report.status),
                  Text(
                    _formatTimestamp(report.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                report.description,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Location
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [report.barangay, report.purok]
                          .whereType<String>()
                          .join(', '),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Issue type + urgency chips
              Wrap(
                spacing: 8,
                children: [
                  _CategoryChip(issueType: report.issueType),
                  _UrgencyChip(urgency: report.urgency, label: report.urgencyLabel),
                ],
              ),

              // Photo count
              if (report.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.photo, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${report.imageUrls.length} '
                      'photo${report.imageUrls.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Small private chips ───────────────────────────────────────────────────────

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String issueType;
  const _CategoryChip({required this.issueType});

  static Color _colorFor(String type) => switch (type.toLowerCase()) {
        'flood' => Colors.blue,
        'fire' => Colors.red,
        'road' || 'pothole' => Colors.grey,
        'power' || 'broken_streetlight' => Colors.amber,
        'waste' || 'garbage' => Colors.brown,
        'water' => Colors.cyan,
        'emergency' => Colors.red,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(issueType);
    final label = issueType
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String urgency;
  final String label;
  const _UrgencyChip({required this.urgency, required this.label});

  static Color _colorFor(String u) => switch (u) {
        'critical' => const Color(0xFFEF4444),
        'high' => const Color(0xFFF59E0B),
        'medium' => const Color(0xFFFBBF24),
        'low' => const Color(0xFF10B981),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}