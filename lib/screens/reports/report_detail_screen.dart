import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';

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
    // Load the specific report
    Provider.of<ReportsProvider>(context, listen: false)
        .selectReport(widget.reportId);
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final report = reportsProvider.selectedReport;

    if (reportsProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Details')),
        body: const Center(
          child: Text('Report not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => context.go('/chat/${report.id}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _buildStatusBanner(report.status),

            const SizedBox(height: 16),

            // Report details
            _buildDetailSection('Description', report.description),

            if (report.category != null)
              _buildDetailSection('Category', _formatCategory(report.category!)),

            if (report.priority != null)
              _buildDetailSection('Priority', _formatPriority(report.priority!)),

            _buildDetailSection('Location',
                '${report.barangay ?? 'Unknown'}, ${report.purok ?? 'Unknown'}'),

            _buildDetailSection('Coordinates',
                '${report.latitude?.toStringAsFixed(6) ?? 'N/A'}, ${report.longitude?.toStringAsFixed(6) ?? 'N/A'}'),

            _buildDetailSection('Reported At', _formatDateTime(report.createdAt)),

            if (report.updatedAt != null)
              _buildDetailSection('Last Updated', _formatDateTime(report.updatedAt!)),

            // Images section
            if (report.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildImageGallery(report.imageUrls),
            ],

            // Action buttons
            const SizedBox(height: 32),
            _buildActionButtons(report),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending Review';
        icon = Icons.schedule;
        break;
      case 'in_progress':
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.engineering;
        break;
      case 'repair_scheduled':
        color = Colors.purple;
        label = 'Repair Scheduled';
        icon = Icons.calendar_today;
        break;
      case 'resolved':
        color = Colors.green;
        label = 'Resolved';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(imageUrls[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(Report report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.go('/chat/${report.id}'),
          icon: const Icon(Icons.chat),
          label: const Text('Chat with Authorities'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _shareReport(report),
          icon: const Icon(Icons.share),
          label: const Text('Share Report'),
        ),
      ],
    );
  }

  void _shareReport(Report report) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon!')),
    );
  }

  String _formatCategory(String category) {
    return category.split('_').map((word) =>
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _formatPriority(String priority) {
    return priority[0].toUpperCase() + priority.substring(1);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}