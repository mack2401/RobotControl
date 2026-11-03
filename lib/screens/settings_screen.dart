import 'package:flutter/material.dart';
import '../core/state/robot_state.dart';
import '../core/theme/app_theme.dart';
import 'profile_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final RobotState state = RobotState();
  bool _darkMode = false;
  bool _voiceControl = true;

  @override
  void initState() {
    super.initState();
    _darkMode = AppTheme.isDarkMode;
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _darkMode = AppTheme.isDarkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _darkMode = isDark;

    final scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final rowTitleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final rowSubColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE60F172A) : const Color(0xE6FFFFFF),
            border: Border(
              bottom: BorderSide(color: cardBorder, width: 1),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Scaffold.of(context).openDrawer();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            size: 24,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFE0F2FE)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A0284C7), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: const Icon(Icons.person, color: Color(0xFF0284C7), size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
        child: Column(
          children: [
            // Settings Group Card matching Stitch HTML 1:1
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 1. Profile
                  _buildNavigationRow(
                    icon: Icons.person,
                    iconBg: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                    iconBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: "Profile",
                    subtitle: "User profile information and picture",
                    rowTitleColor: rowTitleColor,
                    rowSubColor: rowSubColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // 2. Theme (Toggle: Dark Mode)
                  _buildToggleRow(
                    icon: isDark ? Icons.dark_mode : Icons.light_mode,
                    iconBg: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    iconBorder: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    iconColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                    title: "Theme",
                    subtitle: _darkMode ? "Dark Mode (Enabled)" : "Dark Mode (Disabled)",
                    value: _darkMode,
                    rowTitleColor: rowTitleColor,
                    rowSubColor: rowSubColor,
                    isDark: isDark,
                    onChanged: (val) {
                      AppTheme.setDarkMode(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                val ? Icons.dark_mode : Icons.light_mode,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(val ? "Dark Mode activated" : "Light Mode activated"),
                            ],
                          ),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: val ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // 3. Voice Control (Toggle: Voice recognition)
                  _buildToggleRow(
                    icon: Icons.mic,
                    iconBg: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                    iconBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: "Voice Control",
                    subtitle: "Enable or disable voice command recognition",
                    value: _voiceControl,
                    rowTitleColor: rowTitleColor,
                    rowSubColor: rowSubColor,
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _voiceControl = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_voiceControl
                              ? "Voice command recognition enabled"
                              : "Voice command recognition disabled"),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // 4. Help & Support
                  _buildNavigationRow(
                    icon: Icons.help_outline,
                    iconBg: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                    iconBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: "Help & Support",
                    subtitle: "Access help and troubleshooting information",
                    rowTitleColor: rowTitleColor,
                    rowSubColor: rowSubColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // 5. About App
                  _buildNavigationRow(
                    icon: Icons.info_outline,
                    iconBg: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    iconBorder: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    title: "About App",
                    subtitle: "Version 2.4.0 • Build 4899",
                    rowTitleColor: rowTitleColor,
                    rowSubColor: rowSubColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconBg,
    required Color iconBorder,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color rowTitleColor,
    required Color rowSubColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconBorder),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: rowTitleColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: rowSubColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconBg,
    required Color iconBorder,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color rowTitleColor,
    required Color rowSubColor,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    final trackInactive = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconBorder),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: rowTitleColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: rowSubColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Custom Pill Toggle matching Stitch HTML
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                color: value ? const Color(0xFF0284C7) : trackInactive,
                boxShadow: value
                    ? const [BoxShadow(color: Color(0x330284C7), blurRadius: 6, offset: Offset(0, 2))]
                    : null,
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color(0x1A0F172A), blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
