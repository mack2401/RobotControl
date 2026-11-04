import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';
import '../core/sensors/sensor_service.dart';
import '../core/commands/custom_command_manager.dart';
import '../widgets/custom_commands_button.dart';

class GyroControlScreen extends StatefulWidget {
  const GyroControlScreen({super.key});

  @override
  State<GyroControlScreen> createState() => _GyroControlScreenState();
}

class _GyroControlScreenState extends State<GyroControlScreen> {
  final RobotState state = RobotState();
  final SensorService _sensorService = SensorService();
  StreamSubscription<SensorData>? _sensorSub;

  double rawPitch = 0.0;
  double rawRoll = 0.0;
  double rawYaw = 0.0;

  double zeroPitch = 0.0;
  double zeroRoll = 0.0;

  double pitch = 0.0;
  double roll = 0.0;
  double yaw = 0.0;

  double steeringSensitivity = 1.5; // 0.5x to 3.0x multiplier
  bool isTransmitting = true;
  String activeDirection = 'S'; // 'F', 'B', 'L', 'R', 'S'
  DateTime _lastHeartbeat = DateTime.now();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
  Color get appBarBg => isDark ? const Color(0xFF0F172A) : Colors.white.withOpacity(0.95);
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get subBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get chipBg => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  Future<void> _startSensors() async {
    await _sensorService.start();
    _sensorSub = _sensorService.sensorStream.listen(_onSensorData);
  }

  void _onSensorData(SensorData data) {
    if (!mounted) return;

    rawPitch = data.pitch;
    rawRoll = data.roll;
    rawYaw = data.yaw;

    // Relative to calibrated neutral orientation
    final relPitch = (rawPitch - zeroPitch);
    final relRoll = (rawRoll - zeroRoll);

    setState(() {
      pitch = relPitch;
      roll = relRoll;
      yaw = rawYaw;
    });

    if (!isTransmitting) return;

    // Dynamic threshold based on sensitivity (higher sensitivity = easier to trigger)
    final threshold = (12.0 / steeringSensitivity).clamp(5.0, 25.0);

    String newDir = 'S';
    if (relPitch < -threshold) {
      newDir = 'F'; // Phone top tilted downward
    } else if (relPitch > threshold) {
      newDir = 'B'; // Phone top tilted upward
    } else if (relRoll < -threshold) {
      newDir = 'L'; // Phone tilted left
    } else if (relRoll > threshold) {
      newDir = 'R'; // Phone tilted right
    } else {
      newDir = 'S'; // Neutral level zone
    }

    final now = DateTime.now();
    // Send when direction changes or periodically as heartbeat for continuous movement
    if (newDir != activeDirection || (newDir != 'S' && now.difference(_lastHeartbeat).inMilliseconds > 350)) {
      activeDirection = newDir;
      _lastHeartbeat = now;
      state.sendGyroMotionCommand(newDir);
      state.addLog(LogType.cmd, 'GYRO: $newDir (P:${pitch.toInt()}° R:${roll.toInt()}°)');
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _sensorService.stop();
    // Always halt motors when exiting gyro screen
    state.sendGyroMotionCommand("S");
    super.dispose();
  }

  void _calibrateZero() {
    setState(() {
      zeroPitch = rawPitch;
      zeroRoll = rawRoll;
      pitch = 0.0;
      roll = 0.0;
      activeDirection = 'S';
    });
    state.sendGyroMotionCommand("S");
    state.addLog(LogType.cmd, 'GYRO: CALIBRATED NEUTRAL ZERO');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Neutral orientation calibrated to current position (0.0°)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _setSensitivity(double val) {
    setState(() {
      steeringSensitivity = double.parse(val.toStringAsFixed(1));
    });
    state.gyroSensitivity = steeringSensitivity;
    state.addLog(LogType.cmd, 'GYRO: SENSITIVITY ${steeringSensitivity.toStringAsFixed(1)}x');
  }

  void _showGyroCommandConfigDialog() {
    final motionKeys = ['FORWARD', 'BACKWARD', 'LEFT', 'RIGHT', 'STOP'];
    final controllers = {
      for (final k in motionKeys)
        k: TextEditingController(text: state.commandManager.getGyroCustomOverride(k) ?? '')
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final activePreset = state.commandManager.gyroPresetModeEnum;
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
                    Text('Gyro Commands', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    state.commandManager.resetAllGyroOverrides();
                    for (final k in motionKeys) {
                      controllers[k]?.clear();
                    }
                    setDialogState(() {});
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All custom overrides reset to active preset defaults')),
                    );
                  },
                  child: const Text('Reset All', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRESET MODES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: CarPresetMode.values.map((mode) {
                        final isSelected = activePreset == mode;
                        final label = mode == CarPresetMode.singleChar
                            ? 'Single (F/B/L/R/S)'
                            : mode == CarPresetMode.words
                                ? 'Words (FORWARD)'
                                : mode == CarPresetMode.numeric
                                    ? 'Numeric (1/2/3/4/0)'
                                    : 'HTTP (/move?dir=...)';
                        return InkWell(
                          onTap: () {
                            state.commandManager.setGyroPresetMode(mode);
                            setDialogState(() {});
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0F2FE))
                                  : subBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0284C7) : cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF0284C7) : textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('CUSTOM DIRECTION OVERRIDES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary)),
                    const SizedBox(height: 8),
                    ...motionKeys.map((k) {
                      final defaultVal = state.commandManager.getGyroDefaultCommand(k);
                      final activeVal = state.commandManager.getGyroCommand(k);
                      final isCustom = state.commandManager.isGyroCommandCustomized(k);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    k,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                  ),
                                  Text(
                                    isCustom
                                        ? "Default: $defaultVal  •  Custom: $activeVal"
                                        : "Default: $defaultVal",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: isCustom ? const Color(0xFF0284C7) : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controllers[k],
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: "Default: $defaultVal",
                                  hintStyle: TextStyle(fontSize: 10, color: textSecondary.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: isCustom ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFF0FDF4)) : subBg,
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
                  for (final k in motionKeys) {
                    final val = controllers[k]?.text.trim();
                    state.commandManager.setGyroCommand(k, val != null && val.isNotEmpty ? val : null);
                  }
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gyro motion commands saved successfully!')),
                  );
                },
                child: const Text('Save All'),
              ),
            ],
          );
        },
      ),
    );
  }

  String get _sensitivityLabel {
    if (steeringSensitivity <= 1.0) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Low)';
    } else if (steeringSensitivity <= 1.8) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Medium)';
    } else {
      return '${steeringSensitivity.toStringAsFixed(1)}x (High)';
    }
  }

  Widget _buildPresetButton(double val, String title, String multiplier) {
    final isSelected = (steeringSensitivity - val).abs() < 0.15;
    return InkWell(
      onTap: () => _setSensitivity(val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF))
              : subBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                    : textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              multiplier,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1))
                    : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threshold = (12.0 / steeringSensitivity).clamp(5.0, 25.0);
    final isFwd = pitch < -threshold;
    final isRev = pitch > threshold;
    final isLeft = roll < -threshold;
    final isRight = roll > threshold;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appBarBg,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chipBg,
                border: Border.all(color: cardBorder),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: textPrimary),
            ),
          ),
        ),
        title: Text(
          'Gyro Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
            child: CustomCommandsButton(
              onTap: _showGyroCommandConfigDialog,
              isCustomized: state.commandManager.hasGyroOverrides,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  state.toggleMotionCommandProtocol();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.useNumericMotionCommands
                        ? "Protocol: 1/2/3/4/0 (Mecanum Robot)"
                        : "Protocol: F/B/L/R/S (Standard Rover)"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: state.useNumericMotionCommands
                      ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF))
                      : chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: state.useNumericMotionCommands ? const Color(0xFF3B82F6) : cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.useNumericMotionCommands ? Icons.pin : Icons.font_download,
                      size: 13,
                      color: state.useNumericMotionCommands
                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                          : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.useNumericMotionCommands ? '1 2 3 4 0' : 'F B L R S',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: state.useNumericMotionCommands
                            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                            : textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: InkWell(
              onTap: _calibrateZero,
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
                    Icon(Icons.restart_alt, size: 15, color: textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Center All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
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
              // 1. Transmission Status & Toggle Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTransmitting ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTransmitting ? 'Motion Control Active' : 'Motion Control Paused',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTransmitting ? textPrimary : textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isTransmitting,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() {
                          isTransmitting = val;
                          if (!val) {
                            activeDirection = 'S';
                            state.sendGyroMotionCommand("S");
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Interactive Gimbal & Attitude Visualizer Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.explore, size: 16, color: textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Attitude Matrix (Live IMU)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ],
                        ),
                        // Current Active Motion Command Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeDirection == 'S'
                                ? chipBg
                                : (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activeDirection == 'S'
                                  ? cardBorder
                                  : const Color(0xFF38BDF8),
                            ),
                          ),
                          child: Text(
                            activeDirection == 'F'
                                ? '▲ FWD (${state.commandManager.getGyroCommand("FORWARD")})'
                                : activeDirection == 'B'
                                    ? '▼ REV (${state.commandManager.getGyroCommand("BACKWARD")})'
                                    : activeDirection == 'L'
                                        ? '◄ LEFT (${state.commandManager.getGyroCommand("LEFT")})'
                                        : activeDirection == 'R'
                                            ? '► RIGHT (${state.commandManager.getGyroCommand("RIGHT")})'
                                            : '● NEUTRAL (${state.commandManager.getGyroCommand("STOP")})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: activeDirection == 'S'
                                  ? textSecondary
                                  : const Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Virtual Gimbal Horizon Ring Container
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Compass Outer Ring
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeDirection != 'S'
                                    ? const Color(0xFF38BDF8)
                                    : cardBorder,
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBorder, width: 1.5),
                            ),
                          ),
                          // Crosshair lines
                          Container(width: 190, height: 1, color: cardBorder),
                          Container(width: 1, height: 190, color: cardBorder),

                          // Direction Pointers (Highlight actively triggered directions)
                          Positioned(
                            top: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFwd ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FWD (F)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isFwd ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRev ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'REV (B)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isRev ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLeft ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'L',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isLeft ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRight ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'R',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isRight ? Colors.white : textSecondary,
                                ),
                              ),
                            ),
                          ),

                          // Real-time 3D Phone Model / Silhouette tilting in response to phone motion
                          Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateX((pitch.clamp(-45.0, 45.0) * 3.14159 / 180.0))
                              ..rotateZ((roll.clamp(-45.0, 45.0) * 3.14159 / 180.0)),
                            alignment: Alignment.center,
                            child: Container(
                              width: 90,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: activeDirection != 'S'
                                      ? [const Color(0xFF0369A1), const Color(0xFF0F172A)]
                                      : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeDirection != 'S'
                                        ? const Color(0xFF0284C7).withOpacity(0.4)
                                        : Colors.black.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.adjust,
                                          size: 28,
                                          color: activeDirection != 'S'
                                              ? const Color(0xFF38BDF8)
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'IMU 6-DOF',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: activeDirection != 'S'
                                                ? const Color(0xFF7DD3FC)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF475569),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Axis Value Readouts (Bento Row)
                    Row(
                      children: [
                        // Pitch Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isFwd || isRev)
                                    ? const Color(0xFF0284C7)
                                    : cardBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('Pitch (X)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${pitch.toStringAsFixed(1)}°',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFwd ? '▲ FWD' : isRev ? '▼ REV' : '—',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (isFwd || isRev) ? const Color(0xFF0284C7) : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Roll Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isLeft || isRight)
                                    ? const Color(0xFF4F46E5)
                                    : cardBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('Roll (Y)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${roll >= 0 ? '+' : ''}${roll.toStringAsFixed(1)}°',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLeft ? '◄ LEFT' : isRight ? '► RIGHT' : '—',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (isLeft || isRight) ? const Color(0xFF4F46E5) : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Yaw Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                Text('Yaw (Z)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${yaw.toStringAsFixed(1)}°',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 2),
                                const Text('COMPASS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Tuning & Sensitivity Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, size: 18, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Text(
                              'Steering Sensitivity',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _sensitivityLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                      ),
                      child: Slider(
                        value: steeringSensitivity.clamp(0.5, 3.0),
                        min: 0.5,
                        max: 3.0,
                        divisions: 25,
                        activeColor: const Color(0xFF0284C7),
                        inactiveColor: cardBorder,
                        onChanged: (val) => _setSensitivity(val),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick-Select Sensitivity Preset Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetButton(0.8, 'Low', '0.8x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(1.5, 'Medium', '1.5x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(2.4, 'High', '2.4x'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _calibrateZero,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location, size: 16, color: textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Calibrate Neutral Zero',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
