import 'package:flutter/material.dart';

/// Shows an info dialog explaining Wi-Fi Mode 1 (Local Network) or Mode 2 (ESP Hotspot).
void showWifiModeInfoDialog(BuildContext context, {required int mode}) {
  showDialog(
    context: context,
    builder: (ctx) => WifiModeInfoDialog(mode: mode),
  );
}

class WifiModeInfoDialog extends StatelessWidget {
  /// 0 = Mode 1 (Local Network / Station Mode)
  /// 1 = Mode 2 (ESP Hotspot / SoftAP Mode)
  final int mode;

  const WifiModeInfoDialog({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMode1 = mode == 0;
    final primaryColor = isMode1 ? const Color(0xFF059669) : const Color(0xFF0284C7);
    final lightBgColor = isDark
        ? (isMode1 ? const Color(0xFF064E3B).withAlpha(120) : const Color(0xFF0C4A6E).withAlpha(120))
        : (isMode1 ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF));
    final borderColor = isDark
        ? (isMode1 ? const Color(0xFF065F46) : const Color(0xFF0369A1))
        : (isMode1 ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE));
    final iconBgColor = isDark
        ? (isMode1 ? const Color(0xFF064E3B) : const Color(0xFF075985))
        : (isMode1 ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent),
      ),
      elevation: 10,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row with Icon, Title, and Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isMode1 ? Icons.router : Icons.wifi_tethering,
                        color: isDark ? (isMode1 ? const Color(0xFF34D399) : const Color(0xFF38BDF8)) : primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMode1 ? "Mode 1: Wi-Fi — Local Network" : "Mode 2: ESP32 Hotspot (SoftAP)",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isMode1
                                ? "Connect through your home / office Wi-Fi router"
                                : "Direct point-to-point Wi-Fi connection without a router",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: lightBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMode1
                            ? "The ESP32 and phone connect to the same Wi-Fi router. The app communicates with the ESP32 using its local IP address."
                            : "The ESP32 creates its own Wi-Fi network, and the phone connects directly to it.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isMode1 ? "Best for Local Control" : "Key Highlights",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? (isMode1 ? const Color(0xFF34D399) : const Color(0xFF38BDF8)) : primaryColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isMode1) ...[
                        _buildBulletItem("Control hardware and monitor sensors in real-time.", isDark),
                        _buildBulletItem("No cloud server required.", isDark),
                        _buildBulletItem("Internet access is not necessary once local network is set up.", isDark),
                      ] else ...[
                        _buildBulletItem("Works anywhere without a Wi-Fi router.", isDark),
                        _buildBulletItem("Useful for initial device configuration.", isDark),
                        _buildBulletItem("Direct standalone control outdoors or in the field.", isDark),
                      ],
                    ],
                  ),
                ),

                // Mode 2 Warning Banner
                if (!isMode1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "The phone may lose internet access while connected to the ESP32 hotspot.",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Got It button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Got it",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
