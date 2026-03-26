import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../theme/app_theme.dart';
import '../location/location_picker_screen.dart';

class ManualReportFormScreen extends StatefulWidget {
  const ManualReportFormScreen({super.key});

  @override
  State<ManualReportFormScreen> createState() => _ManualReportFormScreenState();
}

class _ManualReportFormScreenState extends State<ManualReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _barangayController = TextEditingController();
  final _purokController = TextEditingController();

  String _issueType = 'other';
  String _urgency = 'medium';
  LatLng? _pickedLocation;
  bool _isSubmitting = false;

  static const _issueTypes = [
    ('flood', 'Baha'),
    ('road_hazard', 'Lubak / Sirang Kalsada'),
    ('power_outage', 'Walang Kuryente / Sirang Streetlight'),
    ('waste', 'Basura'),
    ('water_supply', 'Problema sa Tubig'),
    ('medical', 'Medical Emergency'),
    ('landslide', 'Pagguho ng Lupa'),
    ('earthquake_damage', 'Pinsala ng Lindol'),
    ('fire', 'Sunog'),
    ('emergency', 'Emergency'),
    ('other', 'Iba pa'),
  ];

  static const _urgencies = [
    ('critical', 'Kritikal'),
    ('high', 'Mataas'),
    ('medium', 'Katamtaman'),
    ('low', 'Mababa'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationTextController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _pickedLocation = picked;
      if (_locationTextController.text.trim().isEmpty) {
        _locationTextController.text =
            'Lat ${picked.latitude.toStringAsFixed(5)}, Lng ${picked.longitude.toStringAsFixed(5)}';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pumili muna ng lokasyon sa mapa.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reports = Provider.of<ReportsProvider>(context, listen: false);
    final anonymousId = auth.user?.anonymousId;

    if (anonymousId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kailangan mag-sign in bago mag-report.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final payload = Report(
      id: 'temp-${now.millisecondsSinceEpoch}',
      reporterAnonymousId: anonymousId,
      issueType: _issueType,
      description: _descriptionController.text.trim(),
      latitude: _pickedLocation!.latitude,
      longitude: _pickedLocation!.longitude,
      locationText: _locationTextController.text.trim(),
      barangay: _barangayController.text.trim(),
      purok: _purokController.text.trim().isEmpty
          ? null
          : _purokController.text.trim(),
      urgency: _urgency,
      sdgTag: null,
      status: 'received',
      resolutionNote: null,
      resolutionPhotoUrl: null,
      residentConfirmed: null,
      resolvedAt: null,
      resolvedBy: null,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await reports.submitReport(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reports.error ?? 'Hindi naisumite ang report.'),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Naisumite ang report. Report ID: ${saved.id}'),
        backgroundColor: AppColors.low,
      ),
    );
    context.go('/reports/${saved.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manual Report Form'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Ilagay ang detalye ng insidente',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kumpletuhin ang fields sa ibaba para maisumite ang report.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Label(text: 'Uri ng Isyu'),
            DropdownButtonFormField<String>(
              initialValue: _issueType,
              items: _issueTypes
                  .map(
                    (it) => DropdownMenuItem<String>(
                      value: it.$1,
                      child: Text(it.$2),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _issueType = value);
              },
            ),
            const SizedBox(height: 12),
            _Label(text: 'Urgency'),
            DropdownButtonFormField<String>(
              initialValue: _urgency,
              items: _urgencies
                  .map(
                    (it) => DropdownMenuItem<String>(
                      value: it.$1,
                      child: Text(it.$2),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _urgency = value);
              },
            ),
            const SizedBox(height: 12),
            _Label(text: 'Paglalarawan'),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Ano ang problema? Kailan ito napansin?',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Kailangan ang paglalarawan.';
                if (text.length < 12) return 'Dagdagan pa ang detalye ng report.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Label(text: 'Barangay'),
            TextFormField(
              controller: _barangayController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Hal. Batong Malake'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Kailangan ang barangay.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Label(text: 'Purok (optional)'),
            TextFormField(
              controller: _purokController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Hal. Purok 3'),
            ),
            const SizedBox(height: 12),
            _Label(text: 'Location Text (optional)'),
            TextFormField(
              controller: _locationTextController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Hal. Tapat ng covered court',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickLocation,
              icon: const Icon(Icons.pin_drop_outlined),
              label: Text(
                _pickedLocation == null
                    ? 'Pumili ng Lokasyon sa Mapa'
                    : 'Baguhin ang Lokasyon',
              ),
            ),
            if (_pickedLocation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Napiling coordinates: '
                '${_pickedLocation!.latitude.toStringAsFixed(5)}, '
                '${_pickedLocation!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Isumite ang Report'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}