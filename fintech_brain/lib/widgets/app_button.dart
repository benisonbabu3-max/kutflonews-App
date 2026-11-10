import 'package:flutter/material.dart';
import '../utils/theme.dart';

// ─── DESIGN SYSTEM — button radius tokens ──────────────────────────────────
// All interactive buttons share the same radius so the UI feels consistent.
// Large standalone buttons (save settings, etc): radius 12
// Small inline / pill buttons: radius 10
// Chip/filter pills: radius 20 (fully rounded — intentionally different)
// ───────────────────────────────────────────────────────────────────────────

const _kLargeBtnRadius = 12.0;
const _kSmallBtnRadius = 10.0;
const _kPillRadius     = 20.0;

/// Full-width primary action — dark bg, light text
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool small;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 16 : 20,
          vertical: small ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.nearBlack,
          borderRadius:
              BorderRadius.circular(small ? _kSmallBtnRadius : _kLargeBtnRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: small ? 14 : 16, color: AppColors.base),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: small ? 12 : 14,
                fontWeight: FontWeight.w800,
                color: AppColors.base,
                letterSpacing: .01,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined secondary — dark border + dark text, transparent bg
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool small;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 20,
          vertical: small ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.base,
          border: Border.all(color: AppColors.nearBlack, width: 1.5),
          borderRadius:
              BorderRadius.circular(small ? _kSmallBtnRadius : _kLargeBtnRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: small ? 12 : 14,
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
      ),
    );
  }
}

/// Accent-coloured button — for destructive / highlight actions
class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool small;

  const AccentButton({
    super.key,
    required this.label,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 20,
          vertical: small ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius:
              BorderRadius.circular(small ? _kSmallBtnRadius : _kLargeBtnRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: small ? 12 : 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Filter / category pill — fully rounded
class PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const PillButton({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.nearBlack : Colors.transparent,
          border: Border.all(color: AppColors.nearBlack, width: 1.5),
          borderRadius: BorderRadius.circular(_kPillRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.base : AppColors.nearBlack,
          ),
        ),
      ),
    );
  }
}
