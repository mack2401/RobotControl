import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';
import '../widgets/custom_commands_button.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  final RobotState state = RobotState();
  String currentBuffer = "";
  final int maxBufferLength = 16;
  String? toastMessage;
  IconData toastIcon = Icons.info;
  String? lastTransmitted;
  bool instantSend = true;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
  Color get appBarBg => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1E293B);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get subBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get chipBg => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  void _showToast(String msg, {IconData icon = Icons.info}) {
    setState(() {
      toastMessage = msg;
      toastIcon = icon;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          if (toastMessage == msg) toastMessage = null;
        });
      }
    });
  }

  void _appendKey(String val) {
    if (currentBuffer.length >= maxBufferLength) {
      _showToast('Buffer full (16 bytes maximum)', icon: Icons.warning_amber_rounded);
      return;
    }
    
    HapticFeedback.lightImpact();

    final activeCmd = state.commandManager.getKeypadCommand(val);

    setState(() {
      currentBuffer += val;
      lastTransmitted = activeCmd;
    });

    if (instantSend) {
      // Transmit resolved key command immediately over active link (Wi-Fi or Bluetooth)
      state.sendPayload(activeCmd.endsWith('\n') ? activeCmd : "$activeCmd\n");
      state.addTerminalLog(">>> KEYPAD_TX: '$activeCmd'", LogType.tx);
      state.addLog(LogType.cmd, 'KEYPAD: $val -> $activeCmd');
      
      final bool isDevConnected = state.isConnected || state.wifiService.isConnected;
      if (!isDevConnected) {
        _showToast('Key "$val" ($activeCmd) queued (Device not connected)', icon: Icons.sensors_off);
      }
    } else {
      state.addLog(LogType.cmd, 'BUFFER: $val (CMD: $activeCmd)');
    }
  }

  void _showKeypadCommandConfigDialog() {
    final keys = ['1', '2', '3', 'A', '4', '5', '6', 'B', '7', '8', '9', 'C', '*', '0', '#', 'D'];
    final controllers = {
      for (final k in keys) k: TextEditingController(text: state.commandManager.getKeypadCustomOverride(k) ?? '')
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 8),
                    Text('Keypad Commands', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    state.commandManager.resetAllKeypadCommands();
                    for (final k in keys) {
                      controllers[k]?.clear();
                    }
                    setDialogState(() {});
                    setState(() {});
                    _showToast('All keypad commands reset to default');
                  },
                  child: const Text('Reset All', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              height: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure the exact character or payload transmitted when pressing each key. Supports raw characters or HTTP endpoints (e.g. /keypad?k=1).',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ...keys.map((k) {
                      final activeCmd = state.commandManager.getKeypadCommand(k);
                      final isCustom = state.commandManager.isKeypadCustomized(k);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: subBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Center(
                                child: Text(
                                  k,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: (k == 'A' || k == 'B' || k == 'C' || k == 'D')
                                        ? const Color(0xFF0284C7)
                                        : (k == '*' || k == '#')
                                            ? const Color(0xFFF59E0B)
                                            : textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controllers[k],
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: isCustom ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFF0FDF4)) : subBg,
                                  hintText: "Default: $k",
                                  hintStyle: TextStyle(fontSize: 11, color: textSecondary.withOpacity(0.5)),
                                  helperText: isCustom ? "Custom Active: $activeCmd" : null,
                                  helperStyle: const TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isCustom ? const Color(0xFF10B981) : cardBorder)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  for (final k in keys) {
                    final txt = controllers[k]?.text.trim() ?? '';
                    state.commandManager.setKeypadCommand(k, txt.isEmpty ? null : txt);
                  }
                  setState(() {});
                  Navigator.pop(ctx);
                  _showToast('Keypad commands saved');
                },
                child: const Text('Save All'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _backspaceDigit() {
    HapticFeedback.selectionClick();
    if (currentBuffer.isNotEmpty) {
      setState(() {
        currentBuffer = currentBuffer.substring(0, currentBuffer.length - 1);
      });
    }
  }

  void _clearDisplay() {
    HapticFeedback.selectionClick();
    if (currentBuffer.isNotEmpty) {
      setState(() {
        currentBuffer = "";
        lastTransmitted = null;
      });
      _showToast('Buffer cleared', icon: Icons.delete_outline);
    }
  }

  void _handleSendPayload() {
    if (currentBuffer.isEmpty) {
      _showToast('Enter digits prior to transmit', icon: Icons.priority_high);
      return;
    }
    
    HapticFeedback.mediumImpact();
    final payload = currentBuffer;
    
    // Transmit accumulated packet payload over active link (Wi-Fi or Bluetooth)
    state.sendPayload("$payload\n");
    state.addTerminalLog(">>> KEYPAD_PACKET: '$payload'", LogType.tx);
    state.addLog(LogType.cmd, 'TX PACKET: $payload');
    
    setState(() {
      lastTransmitted = payload;
      currentBuffer = "";
    });

    final bool isDevConnected = state.isConnected || state.wifiService.isConnected;
    _showToast(
      isDevConnected ? 'Transmitted: $payload' : 'Transmitted (Device not connected)',
      icon: isDevConnected ? Icons.send : Icons.sensors_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final bool isConnected = state.isConnected;
        final bool hasDigits = currentBuffer.isNotEmpty;
        final String displayDigits = hasDigits
            ? currentBuffer.split('').join(' ')
            : '—— —— ——';

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: appBarBg.withOpacity(0.95),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardBg,
                    border: Border.all(color: cardBorder),
                  ),
                  child: Icon(Icons.arrow_back, size: 18, color: textPrimary),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Virtual Keypad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                Text(
                  'SERIAL COMMAND GATEWAY',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: textSecondary),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                child: CustomCommandsButton(
                  onTap: _showKeypadCommandConfigDialog,
                  isCustomized: state.commandManager.hasKeypadOverrides,
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Bluetooth Connection Status Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFF0FDF4))
                              : (isDark ? const Color(0xFF78350F).withOpacity(0.3) : const Color(0xFFFFFBEB)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConnected
                                ? (isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0))
                                : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                    size: 16,
                                    color: isConnected
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                                        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isConnected
                                          ? 'Connected: ${state.currentDevice.name}'
                                          : 'Bluetooth Disconnected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isConnected
                                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D))
                                            : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  instantSend = !instantSend;
                                });
                                _showToast(
                                  instantSend ? 'Instant Key TX Enabled' : 'Packet Mode Enabled',
                                  icon: instantSend ? Icons.flash_on : Icons.all_inbox,
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: instantSend
                                      ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0F2FE))
                                      : chipBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: instantSend
                                        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD))
                                        : cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      instantSend ? Icons.flash_on : Icons.all_inbox,
                                      size: 12,
                                      color: instantSend ? const Color(0xFF38BDF8) : textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      instantSend ? 'Instant TX' : 'Packet Only',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: instantSend ? const Color(0xFF38BDF8) : textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MAIN READOUT BUFFER CARD
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card Header
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.data_array, size: 16, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'PAYLOAD BUFFER',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (lastTransmitted != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
                                          ),
                                          child: Text(
                                            'TX: $lastTransmitted',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: chipBg,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${currentBuffer.length} / $maxBufferLength B',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        // Value Display Area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayDigits,
                                  style: TextStyle(
                                    fontFamily: hasDigits ? 'monospace' : null,
                                    fontSize: hasDigits ? 28 : 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: hasDigits ? 2 : 3,
                                    color: hasDigits ? textPrimary : textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasDigits)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'TX READY',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Display Micro-Actions Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border(top: BorderSide(color: cardBorder)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _clearDisplay,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.clear_all, size: 13, color: textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'CLR',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _backspaceDigit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 28,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Icon(Icons.backspace, size: 14, color: textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // KEYPAD MATRIX GRID (4x4)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      children: [
                        _buildKeypadRow(['1', '2', '3', 'A'], ['.', 'ABC', 'DEF', 'CMD1']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['4', '5', '6', 'B'], ['GHI', 'JKL', 'MNO', 'CMD2']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['7', '8', '9', 'C'], ['PQRS', 'TUV', 'WXYZ', 'CMD3']),
                        const SizedBox(height: 10),
                        _buildKeypadRow(['*', '0', '#', 'D'], ['CMD', '+', 'TERM', 'EXEC']),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // OPERATIONAL FOOTER CONTROLS: SEND PACKET
                  InkWell(
                    onTap: _handleSendPayload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Send Packet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Feedback Micro-Toast
          if (toastMessage != null)
            Positioned(
              bottom: 84,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(toastIcon, size: 16, color: const Color(0xFF5EEAD4)),
                        const SizedBox(width: 8),
                        Text(
                          toastMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Text(
                      'ACK',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildKeypadRow(List<String> keys, List<String> subs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildKeypadButton(keys[index], subs[index]),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadButton(String key, String sub) {
    final bool isActionCol = key == 'A' || key == 'B' || key == 'C' || key == 'D';
    final bool isSpecial = key == '*' || key == '#';

    Color mainColor = textPrimary;
    if (isActionCol) mainColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    if (isSpecial) mainColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFF854D0E);

    final activeCmd = state.commandManager.getKeypadCommand(key);
    final isCustom = state.commandManager.isKeypadCustomized(key);

    return InkWell(
      onTap: () => _appendKey(key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustom
                ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
                : cardBorder,
            width: isCustom ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  key,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                    height: 1.0,
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isCustom
                    ? (isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFDCFCE7))
                    : chipBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'TX: $activeCmd',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: isCustom
                      ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D))
                      : textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
