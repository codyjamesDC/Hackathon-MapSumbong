import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/report.dart';

// Default center: Los Baños, Laguna, Philippines
const _defaultCenter = LatLng(14.1698, 121.2430);
const _defaultZoom = 13.0;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  Report? _selectedReport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
      final reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);
      final id = authProvider.user?.anonymousId;
      if (id != null && reportsProvider.reports.isEmpty) {
        reportsProvider.loadReports(userId: id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final reports = reportsProvider.reports
        .where((r) => !r.isDeleted)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Reset view',
            onPressed: () {
              _mapController.move(_defaultCenter, _defaultZoom);
              setState(() => _selectedReport = null);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final id = authProvider.user?.anonymousId;
              if (id != null) {
                reportsProvider.loadReports(userId: id);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              onTap: (_, __) => setState(() => _selectedReport = null),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mapsumbong',
              ),

              // Report markers
              MarkerLayer(
                markers: reports
                    .map((report) => _buildMarker(report))
                    .toList(),
              ),
            ],
          ),

          // Loading overlay
          if (reportsProvider.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Legend
          Positioned(
            top: 12,
            right: 12,
            child: _MapLegend(),
          ),

          // Selected report card
          if (_selectedReport != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _ReportPopup(
                report: _selectedReport!,
                onClose: () => setState(() => _selectedReport = null),
                onViewDetail: () {
                  final id = _selectedReport!.id;
                  setState(() => _selectedReport = null);
                  context.push('/reports/$id');
                },
                onChat: () {
                  final id = _selectedReport!.id;
                  setState(() => _selectedReport = null);
                  context.push('/chat/$id');
                },
              ),
            ),

          // Report count badge
          if (reports.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  '${reports.length} report${reports.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(Report report) {
    return Marker(
      point: LatLng(report.latitude, report.longitude),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedReport = report);
          _mapController.move(
              LatLng(report.latitude, report.longitude), 15);
        },
        child: _MarkerPin(
          color: report.urgencyColor,
          selected: _selectedReport?.id == report.id,
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MarkerPin extends StatelessWidget {
  final Color color;
  final bool selected;
  const _MarkerPin({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: selected ? 8 : 4,
            spreadRadius: selected ? 2 : 0,
          ),
        ],
      ),
      child: Icon(
        Icons.warning_rounded,
        color: Colors.white,
        size: selected ? 20 : 16,
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (color: Color(0xFFEF4444), label: 'Critical'),
      (color: Color(0xFFF59E0B), label: 'High'),
      (color: Color(0xFFFBBF24), label: 'Medium'),
      (color: Color(0xFF10B981), label: 'Low'),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: item.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(item.label,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ReportPopup extends StatelessWidget {
  final Report report;
  final VoidCallback onClose;
  final VoidCallback onViewDetail;
  final VoidCallback onChat;

  const _ReportPopup({
    required this.report,
    required this.onClose,
    required this.onViewDetail,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatIssueType(report.issueType),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: report.urgencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.urgencyLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: report.urgencyColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              report.description,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.locationText ?? report.barangay,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetail,
                    icon: const Icon(Icons.info_outline, size: 14),
                    label: const Text('Details',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(Icons.chat, size: 14),
                    label:
                        const Text('Chat', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatIssueType(String type) => type
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}