import 'package:flutter/material.dart';

/// A premium, distinctive "Custom Commands" button designed for controller headers & AppBars.
/// Features a cyber-capsule silhouette, radiant icon pod, subtle ambient glow, and an active override indicator.
class CustomCommandsButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Color? accentColor;
  final bool isCustomized;
  final bool compact;

  const CustomCommandsButton({
    super.key,
    required this.onTap,
    this.label = 'CUSTOM CMDS',
    this.icon = Icons.tune_rounded,
    this.accentColor,
    this.isCustomized = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = accentColor ?? const Color(0xFF0284C7);
    final secondary = isDark ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9);

    final double height = compact ? 28 : 34;
    final double iconSize = compact ? 12 : 14;
    final double fontSize = compact ? 9.5 : 11;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: primary.withOpacity(0.2),
        highlightColor: primary.withOpacity(0.1),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // Distinctive gradient fill: sleek dark glass in dark mode, radiant crystal in light mode
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1E293B).withOpacity(0.95),
                      const Color(0xFF0F172A).withOpacity(0.95),
                    ]
                  : [
                      Colors.white,
                      primary.withOpacity(0.08),
                    ],
            ),
            // Glowing border with gradient accents
            border: Border.all(
              color: isCustomized
                  ? const Color(0xFF10B981)
                  : primary.withOpacity(isDark ? 0.6 : 0.4),
              width: 1.2,
            ),
            // Atmospheric ambient glow
            boxShadow: [
              BoxShadow(
                color: (isCustomized ? const Color(0xFF10B981) : primary)
                    .withOpacity(isDark ? 0.28 : 0.15),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Radiant Left Icon Pod
              Container(
                width: compact ? 18 : 22,
                height: compact ? 18 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isCustomized
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [primary, secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isCustomized ? const Color(0xFF10B981) : primary)
                          .withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Button Label with high-tech micro-typography
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 5),
              // Active override status badge or chevron
              if (isCustomized) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'CUSTOM',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: compact ? 12 : 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
