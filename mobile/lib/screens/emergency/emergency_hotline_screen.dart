import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

class EmergencyHotlineScreen extends StatelessWidget {
  const EmergencyHotlineScreen({super.key});

  Future<void> _callHotline(
    BuildContext context, {
    required String number,
    required String contactName,
  }) async {
    final uri = Uri(scheme: 'tel', path: number);
    final opened = await launchUrl(uri);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hindi matawagan ang $contactName sa ngayon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = <_EmergencyContactItem>[
      const _EmergencyContactItem(
        title: 'If kidnap',
        subtitle: 'Press to contact Anti-Kidnapping Task Force',
        icon: Icons.gpp_good_rounded,
        color: Color(0xFFB91C1C),
        hotlineNumber: '117',
        contactName: 'Anti-Kidnapping Task Force',
      ),
      const _EmergencyContactItem(
        title: 'Social services',
        subtitle: 'Press to contact DSWD',
        icon: Icons.volunteer_activism_rounded,
        color: Color(0xFF0F766E),
        hotlineNumber: '8888',
        contactName: 'DSWD',
      ),
      const _EmergencyContactItem(
        title: 'PNP',
        subtitle: 'Press to contact Law enforcement hotline',
        icon: Icons.local_police_rounded,
        color: Color(0xFF1D4ED8),
        hotlineNumber: '911',
        contactName: 'Law enforcement hotline',
      ),
      const _EmergencyContactItem(
        title: 'VAWC',
        subtitle: 'Press to contact VAWC (Violence Against Women and Children)',
        icon: Icons.health_and_safety_rounded,
        color: Color(0xFF7C3AED),
        hotlineNumber: '09197777377',
        contactName: 'VAWC',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: contacts.length,
        separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = contacts[index];
          return _EmergencyContactTile(
            item: item,
            onTap: () => _callHotline(
              context,
              number: item.hotlineNumber,
              contactName: item.contactName,
            ),
          );
        },
      ),
    );
  }
}

class _EmergencyContactItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String hotlineNumber;
  final String contactName;

  const _EmergencyContactItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.hotlineNumber,
    required this.contactName,
  });
}

class _EmergencyContactTile extends StatelessWidget {
  final _EmergencyContactItem item;
  final VoidCallback onTap;

  const _EmergencyContactTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.call_rounded, color: item.color),
            ],
          ),
        ),
      ),
    );
  }
}
