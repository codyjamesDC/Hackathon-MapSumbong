import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/messages_provider.dart';
import '../../theme/app_theme.dart';
import '../location/location_picker_screen.dart';

class CreateReportOptionsScreen extends StatelessWidget {
  const CreateReportOptionsScreen({super.key});

  Future<void> _startAiChatFlow(BuildContext context) async {
    Provider.of<MessagesProvider>(context, listen: false).clearGpsCoordinates();

    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
        fullscreenDialog: true,
      ),
    );

    if (!context.mounted) return;

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pumili muna ng lokasyon bago magsimula ng report.'),
        ),
      );
      return;
    }

    Provider.of<MessagesProvider>(context, listen: false)
        .setGpsCoordinates(picked.latitude, picked.longitude);

    context.push('/chat/new');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gumawa ng Report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Pumili kung paano ka mag-uulat',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mas mabilis sa AI chat, o mas detalyado sa manual form.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _OptionCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Report via AI Chat',
            subtitle: 'May gabay na tanong at mabilis na pag-fill ng detalye.',
            points: const [
              'Guided conversation sa Filipino',
              'Auto-extract ng issue type at urgency',
              'Pin location bago magsimula',
            ],
            accent: AppColors.primary,
            buttonLabel: 'Simulan ang AI Chat',
            onTap: () => _startAiChatFlow(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionCard(
            icon: Icons.description_outlined,
            title: 'Manual Form',
            subtitle: 'Ikaw mismo ang maglalagay ng lahat ng detalye.',
            points: const [
              'Structured fields para sa incident data',
              'Mas kontrolado ang input',
              'Best para sa kumpletong impormasyon',
            ],
            accent: AppColors.accent,
            buttonLabel: 'Gamitin ang Manual Form',
            onTap: () => context.push('/create-report/manual'),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;
  final Color accent;
  final String buttonLabel;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.accent,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle, size: 6, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
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
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size(0, 44),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}