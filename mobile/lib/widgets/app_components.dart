import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Urgency Badge ─────────────────────────────────────────────────────────────

class UrgencyBadge extends StatelessWidget {
  final String urgency;
  final bool small;

  const UrgencyBadge({super.key, required this.urgency, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: urgency.urgencyBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: BoxDecoration(
              color: urgency.urgencyColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            urgency.urgencyLabel,
            style: TextStyle(
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: urgency.urgencyColor,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.statusBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: status.statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        status.statusLabel,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: status.statusColor,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}

// ── Issue Type Icon ───────────────────────────────────────────────────────────

class IssueTypeIcon extends StatelessWidget {
  final String issueType;
  final double size;

  const IssueTypeIcon({super.key, required this.issueType, this.size = 40});

  static const Map<String, (IconData, Color)> _icons = {
    'flood': (Icons.water, Color(0xFF3B82F6)),
    'waste': (Icons.delete_rounded, Color(0xFF6B7280)),
    'road': (Icons.construction_rounded, Color(0xFF78716C)),
    'pothole': (Icons.warning_amber_rounded, Color(0xFFF59E0B)),
    'power': (Icons.bolt_rounded, Color(0xFFF59E0B)),
    'broken_streetlight': (Icons.lightbulb_outline_rounded, Color(0xFFF59E0B)),
    'water': (Icons.water_drop_rounded, Color(0xFF0EA5E9)),
    'emergency': (Icons.emergency_rounded, Color(0xFFEF4444)),
    'fire': (Icons.local_fire_department_rounded, Color(0xFFEF4444)),
    'crime': (Icons.shield_rounded, Color(0xFF8B5CF6)),
    'other': (Icons.report_problem_rounded, Color(0xFF6B7280)),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _icons[issueType] ?? _icons['other']!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── App Loading Indicator ─────────────────────────────────────────────────────

class AppLoader extends StatelessWidget {
  final String? message;

  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
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
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onButton,
                icon: const Icon(Icons.add, size: 18),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gradient Banner ───────────────────────────────────────────────────────────

class GradientBanner extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientBanner({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? [
            AppColors.primary,
            const Color(0xFF3B6FE8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

// ── Divider with label ────────────────────────────────────────────────────────

class LabelDivider extends StatelessWidget {
  final String label;

  const LabelDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}