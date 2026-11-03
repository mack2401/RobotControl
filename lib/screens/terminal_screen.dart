import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RobotState _state = RobotState();

  // Quick Action Buttons tailored for robot cars and word-based firmware
  final List<Map<String, dynamic>> _quickCommands = const [
    {"label": "FORWARD", "cmd": "FORWARD", "icon": Icons.arrow_upward, "color": Color(0xFF10B981)},
    {"label": "BACKWARD", "cmd": "BACKWARD", "icon": Icons.arrow_downward, "color": Color(0xFF0284C7)},
    {"label": "LEFT", "cmd": "LEFT", "icon": Icons.arrow_back, "color": Color(0xFF0284C7)},
    {"label": "RIGHT", "cmd": "RIGHT", "icon": Icons.arrow_forward, "color": Color(0xFF0284C7)},
    {"label": "STOP", "cmd": "STOP", "icon": Icons.stop_circle, "color": Color(0xFFEF4444)},
    {"label": "F", "cmd": "F", "color": Color(0xFF334155)},
    {"label": "B", "cmd": "B", "color": Color(0xFF334155)},
    {"label": "L", "cmd": "L", "color": Color(0xFF334155)},
    {"label": "R", "cmd": "R", "color": Color(0xFF334155)},
    {"label": "S", "cmd": "S", "color": Color(0xFF334155)},
    {"label": "STATUS", "cmd": "STATUS", "color": Color(0xFF6366F1)},
    {"label": "PING", "cmd": "PING", "color": Color(0xFF6366F1)},
  ];

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? prefilledCmd]) {
    final rawCmd = (prefilledCmd ?? _cmdController.text).trim();
    if (rawCmd.isEmpty) return;

    HapticFeedback.lightImpact();
    _state.sendTerminalCommand(rawCmd);

    if (prefilledCmd == null) {
      _cmdController.clear();
    }
    _scrollToBottom();
  }

  Color _getLogColor(LogType type, bool isDark) {
    switch (type) {
      case LogType.tx:
      case LogType.cmd:
        return const Color(0xFF00F2FE); // Cyan for outgoing commands
      case LogType.rx:
        return const Color(0xFF34D399); // Emerald for robot responses
      case LogType.error:
        return const Color(0xFFF87171); // Red for errors
      case LogType.system:
        return const Color(0xFF94A3B8); // Slate for system info
      case LogType.bluetooth:
        return const Color(0xFF60A5FA); // Blue for transport handshakes
    }
  }

  String _getLogPrefix(LogType type) {
    switch (type) {
      case LogType.tx:
      case LogType.cmd:
        return "> ";
      case LogType.rx:
        return "< ";
      case LogType.error:
        return "! ";
      case LogType.system:
      case LogType.bluetooth:
        return "• ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFFAF9FA);
    final appBarBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFFAF9FA).withOpacity(0.95);
    final backBtnBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1B1C1D);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final isConnected = _state.currentDevice.isConnected;
    final activeDeviceName = _state.currentDevice.name;
    final activeIp = _state.currentDevice.ipAddress.isNotEmpty ? _state.currentDevice.ipAddress : _state.wifiService.currentHost;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appBarBg,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: backBtnBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, size: 20, color: textPrimary),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terminal Console',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    isConnected ? "$activeDeviceName ($activeIp)" : "Offline • Ready",
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isConnected ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)) : textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: textSecondary),
              tooltip: 'Clear Terminal',
              onPressed: () {
                _state.clearTerminal();
                setState(() {});
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              // Clean CRT / Terminal Console Window
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.black.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: _state.logs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _state.logs.length) {
                        // Live blinking prompt row
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Text(
                                '> ',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00F2FE),
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 14,
                                color: const Color(0xFF34D399),
                              ),
                            ],
                          ),
                        );
                      }

                      final log = _state.logs[index];
                      final color = _getLogColor(log.type, isDark);
                      final prefix = _getLogPrefix(log.type);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prefix,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                log.message,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Quick Action Chips Row (FORWARD, BACKWARD, LEFT, RIGHT, STOP)
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickCommands.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final item = _quickCommands[idx];
                    final Color baseColor = item["color"] as Color;
                    final IconData? icon = item["icon"] as IconData?;
                    final String label = item["label"] as String;
                    final String cmd = item["cmd"] as String;

                    final isAccent = label == "FORWARD" || label == "STOP";

                    return InkWell(
                      onTap: () => _handleSend(cmd),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAccent ? baseColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAccent ? baseColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 13, color: isAccent ? Colors.white : baseColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isAccent ? Colors.white : (isDark ? Colors.white : textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Interactive Terminal Input Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _cmdController,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type "FORWARD", "LEFT", etc...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: _cmdController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.cancel, size: 16, color: textSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _cmdController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _handleSend(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  InkWell(
                    onTap: () => _handleSend(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Send',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.send, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
