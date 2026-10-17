import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';

class BigActionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color iconBgColor;
  final VoidCallback onTap;
  final String? badgeText;
  final bool isPrimary;

  const BigActionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.color = AppTheme.indigo,
    this.iconBgColor = AppTheme.indigoLight,
    required this.onTap,
    this.badgeText,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.terracotta : AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary ? AppTheme.terracottaDark : AppTheme.borderWarm,
              width: isPrimary ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? AppTheme.terracotta.withOpacity(0.25)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isPrimary ? Colors.white.withOpacity(0.2) : iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isPrimary ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isPrimary ? Colors.white : AppTheme.textCharcoal,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isPrimary ? Colors.white70 : AppTheme.textMuted,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.turmeric,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      color: AppTheme.textCharcoal,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: isPrimary ? Colors.white70 : AppTheme.textMuted,
              )
            ],
          ),
        ),
      ),
    );
  }
}
