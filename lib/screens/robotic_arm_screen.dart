import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class MovementItem {
  final String letter;
  String title;
  String subtitle;
  double angle;
  final bool isFixed;

  MovementItem({
    required this.letter,
    required this.title,
    required this.subtitle,
    this.angle = 90.0,
    this.isFixed = false,
  });
}

class RoboticArmScreen extends StatefulWidget {
  const RoboticArmScreen({super.key});

  @override
  State<RoboticArmScreen> createState() => _RoboticArmScreenState();
}

class _RoboticArmScreenState extends State<RoboticArmScreen> {
  final RobotState state = RobotState();
  final List<String> _availableLetters = 'DEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  late List<MovementItem> _movements;
  DateTime _lastSliderSend = DateTime.now();
  int _lastSentAngle = -1;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
  Color get appBarBg => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get subBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get chipBg => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _movements = [
      MovementItem(letter: 'A', title: 'Base Rotation', subtitle: '/move?joint=base&angle', angle: 90, isFixed: true),
      MovementItem(letter: 'B', title: 'Shoulder Axis', subtitle: '/move?joint=shoulder&angle', angle: 90, isFixed: true),
      MovementItem(letter: 'C', title: 'Elbow Axis', subtitle: '/move?joint=elbow&angle', angle: 90, isFixed: true),
    ];
  }

  /// Formats the command based on user input in the "Joint / Subtitle" field
  String _buildCommand(MovementItem item, int angle) {
    var sub = item.subtitle.trim();
    if (sub.isEmpty) {
      return "${item.letter}$angle";
    }
    // Single or 2 alphanumeric characters without command chars (e.g. "A" or "S1")
    if (sub.length <= 2 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(sub)) {
      return "$sub$angle";
    }
    // Replace explicit placeholders if present (e.g. {angle} or {val})
    if (sub.contains("{angle}")) {
      return sub.replaceAll("{angle}", "$angle");
    }
    if (sub.contains("{val}")) {
      return sub.replaceAll("{val}", "$angle");
    }
    // Legacy description with spaces and no endpoint characters (e.g. "Servo Base / Axis 1")
    if (sub.contains(" ") && !sub.startsWith("/") && !sub.contains("?") && !sub.contains("=")) {
      return "${item.letter}$angle";
    }

    // Prepend '/' if it has query parameters or path structure without leading slash
    if (!sub.startsWith("/") && (sub.contains("?") || sub.contains("&") || sub.contains("="))) {
      sub = "/$sub";
    }

    // Delimiter handling: append angle cleanly
    if (sub.endsWith("=") || sub.endsWith("/") || sub.endsWith(":")) {
      return "$sub$angle";
    } else {
      return "$sub=$angle";
    }
  }

  void _resetAllServos() {
    setState(() {
      for (final m in _movements) {
        m.angle = 90.0;
      }
    });
    state.resetAllArmServos();
    for (final m in _movements) {
      final cmd = _buildCommand(m, 90);
      state.sendPayload(cmd.endsWith('\n') ? cmd : "$cmd\n");
    }
    state.addLog(LogType.cmd, 'ARM: RESET ALL TO 90°');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All servos centered to 90°'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onAngleChanged(MovementItem item, double val) {
    setState(() {
      item.angle = val;
    });
    final int currentAngle = val.toInt();
    final now = DateTime.now();
    if (now.difference(_lastSliderSend).inMilliseconds > 70 && currentAngle != _lastSentAngle) {
      _lastSliderSend = now;
      _lastSentAngle = currentAngle;
      final cmd = _buildCommand(item, currentAngle);
      state.setArmAngle(item.letter, val, customCommand: cmd);
    }
  }

  void _onAngleChangeEnd(MovementItem item, double val) {
    _lastSentAngle = val.toInt();
    final cmd = _buildCommand(item, val.toInt());
    state.setArmAngle(item.letter, val, customCommand: cmd);
  }

  void _addMovement() {
    if (_availableLetters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum number of movements reached (A-Z).')),
      );
      return;
    }
    final nextLetter = _availableLetters.removeAt(0);
    setState(() {
      _movements.add(
        MovementItem(
          letter: nextLetter,
          title: 'Movement $nextLetter',
          subtitle: '/move?joint=joint_${nextLetter.toLowerCase()}&angle',
          angle: 90,
          isFixed: false,
        ),
      );
    });
    state.addLog(LogType.cmd, 'ARM: ADDED AXIS $nextLetter');
  }

  void _removeMovement(int index) {
    final removed = _movements[index];
    _availableLetters.insert(0, removed.letter);
    _availableLetters.sort();
    setState(() {
      _movements.removeAt(index);
    });
    state.addLog(LogType.cmd, 'ARM: REMOVED AXIS ${removed.letter}');
  }

  void _editMovementName(int index) {
    final item = _movements[index];
    final titleController = TextEditingController(text: item.title);
    final subtitleController = TextEditingController(text: item.subtitle);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tempItem = MovementItem(
            letter: item.letter,
            title: titleController.text,
            subtitle: subtitleController.text,
            angle: item.angle,
          );
          final previewCmd = _buildCommand(tempItem, item.angle.toInt());

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD)),
                  ),
                  child: Center(
                    child: Text(
                      item.letter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Edit Movement ${item.letter}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Movement Name",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: "e.g. Base Rotation, Gripper Clamp",
                      hintStyle: TextStyle(color: textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Joint / Subtitle (Command Format)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Enter your endpoint (e.g. /move?joint=base&angle). Angle will be appended automatically.",
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subtitleController,
                    style: TextStyle(color: textPrimary, fontFamily: 'monospace', fontSize: 13),
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: "e.g. /move?joint=base&angle",
                      hintStyle: TextStyle(color: textSecondary, fontFamily: 'monospace'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Live Command Preview Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: subBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.send, size: 11, color: Color(0xFF0284C7)),
                            const SizedBox(width: 5),
                            Text(
                              "LIVE COMMAND PREVIEW",
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          previewCmd,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final newTitle = titleController.text.trim();
                  final newSubtitle = subtitleController.text.trim();
                  if (newTitle.isNotEmpty) {
                    setState(() {
                      item.title = newTitle;
                      item.subtitle = newSubtitle;
                    });
                    state.addLog(LogType.cmd, "ARM: UPDATED AXIS ${item.letter} ('$newTitle' -> '$newSubtitle')");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Updated Movement ${item.letter}"),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Icon(Icons.arrow_back, size: 20, color: textPrimary),
            ),
          ),
        ),
        title: Text(
          'Robotic Arm Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: InkWell(
              onTap: _resetAllServos,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, size: 15, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Center All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Sliders List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final item = _movements[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.letter,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _editMovementName(index),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: chipBg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 11,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.terminal,
                                          size: 11,
                                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _buildCommand(item, item.angle.toInt()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: subBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${item.angle.toInt()}',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                        ),
                                      ),
                                      Text(
                                        '°',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.isFixed) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _removeMovement(index),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(Icons.close, size: 16, color: textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Slider Row
                        Row(
                          children: [
                            Text('0°', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textSecondary)),
                            Expanded(
                              child: Slider(
                                value: item.angle,
                                min: 0,
                                max: 180,
                                activeColor: const Color(0xFF0284C7),
                                inactiveColor: cardBorder,
                                onChanged: (val) => _onAngleChanged(item, val),
                                onChangeEnd: (val) => _onAngleChangeEnd(item, val),
                              ),
                            ),
                            Text('180°', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              // Add Movement Button
              InkWell(
                onTap: _addMovement,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '+ Add Movement',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
