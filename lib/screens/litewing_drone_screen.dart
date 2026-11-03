import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/drone/litewing_service.dart';
import '../core/state/robot_state.dart';

class LiteWingDroneScreen extends StatefulWidget {
  const LiteWingDroneScreen({super.key});

  @override
  State<LiteWingDroneScreen> createState() => _LiteWingDroneScreenState();
}

class _LiteWingDroneScreenState extends State<LiteWingDroneScreen> with SingleTickerProviderStateMixin {
  final LiteWingService _drone = LiteWingService();
  final RobotState _robot = RobotState();

  Timer? _uiRefreshTimer;
  String? _toastMessage;
  Timer? _toastTimer;

  // Left Stick (Throttle & Yaw) touch tracking
  Offset _leftStickDelta = Offset.zero; // x: -1..1 (yaw), y: -1..1 (throttle)
  bool _leftStickTouching = false;
  double _manualThrottlePosition = 0.0; // 0.0 (bottom) to 1.0 (top)

  // Right Stick (Pitch & Roll) touch tracking
  Offset _rightStickDelta = Offset.zero; // x: -1..1 (roll), y: -1..1 (pitch)
  bool _rightStickTouching = false;

  @override
  void initState() {
    super.initState();
    // Auto lock to Landscape for piloting arena
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _drone.addListener(_onDroneUpdate);
    _drone.startFlightLoop();

    // Fast 50ms UI ticker for smooth horizon & telemetry
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _toastTimer?.cancel();
    _drone.removeListener(_onDroneUpdate);

    // Always restore portrait orientations on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onDroneUpdate() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  // --- Left Stick Handling (Throttle & Yaw) ---
  void _onLeftStickPanStart(DragStartDetails details, Size stickAreaSize) {
    _leftStickTouching = true;
    _updateLeftStick(details.localPosition, stickAreaSize);
  }

  void _onLeftStickPanUpdate(DragUpdateDetails details, Size stickAreaSize) {
    _updateLeftStick(details.localPosition, stickAreaSize);
  }

  void _onLeftStickPanEnd(DragEndDetails details) {
    _leftStickTouching = false;
    if (_drone.isHeightHold || _drone.autoCenterThrottle) {
      _leftStickDelta = Offset.zero;
      _drone.setFlightInputs(yaw: 0.0, thrust: 0.5);
    } else {
      // In manual mode, yaw returns to 0, thrust stays at current position
      _leftStickDelta = Offset(0.0, _leftStickDelta.dy);
      _drone.setFlightInputs(yaw: 0.0, thrust: _manualThrottlePosition);
    }
    setState(() {});
  }

  void _updateLeftStick(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) - 16;

    double dx = (localPos.dx - center.dx) / maxRadius;
    double dy = (localPos.dy - center.dy) / maxRadius;

    dx = dx.clamp(-1.0, 1.0);
    dy = dy.clamp(-1.0, 1.0);

    _leftStickDelta = Offset(dx, dy);

    final yawVal = dx;
    final thrustVal = ((-dy + 1.0) / 2.0).clamp(0.0, 1.0);
    _manualThrottlePosition = thrustVal;

    _drone.setFlightInputs(
      yaw: yawVal,
      thrust: thrustVal,
    );
    setState(() {});
  }

  // --- Right Stick Handling (Pitch & Roll) ---
  void _onRightStickPanStart(DragStartDetails details, Size stickAreaSize) {
    _rightStickTouching = true;
    _updateRightStick(details.localPosition, stickAreaSize);
  }

  void _onRightStickPanUpdate(DragUpdateDetails details, Size stickAreaSize) {
    _updateRightStick(details.localPosition, stickAreaSize);
  }

  void _onRightStickPanEnd(DragEndDetails details) {
    _rightStickTouching = false;
    _rightStickDelta = Offset.zero;
    _drone.setFlightInputs(roll: 0.0, pitch: 0.0);
    setState(() {});
  }

  void _updateRightStick(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) - 16;

    double dx = (localPos.dx - center.dx) / maxRadius;
    double dy = (localPos.dy - center.dy) / maxRadius;

    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > 1.0) {
      dx /= dist;
      dy /= dist;
    }

    _rightStickDelta = Offset(dx, dy);

    final rollVal = dx;
    final pitchVal = -dy;

    _drone.setFlightInputs(
      roll: rollVal,
      pitch: pitchVal,
    );
    setState(() {});
  }

  void _toggleArming() {
    HapticFeedback.heavyImpact();
    if (_drone.isArmed) {
      _drone.disarm();
      _showToast("Drone Disarmed • Motors Stopped");
    } else {
      if (_drone.thrustInput > 0.15 && !_drone.isHeightHold) {
        _showToast("SAFETY: Lower Throttle to 0% to Arm!");
        return;
      }
      _drone.arm();
      _showToast("MOTORS ARMED • Flight Controls Live");
    }
  }

  void _triggerEmergencyStop() {
    HapticFeedback.heavyImpact();
    _leftStickDelta = Offset.zero;
    _rightStickDelta = Offset.zero;
    _manualThrottlePosition = 0.0;
    _drone.emergencyStop();
    _showToast("EMERGENCY STOP • All Motors Cut!");
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get wellBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get pillBg => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Disarm and restore orientations
        if (_drone.isArmed) _drone.disarm();
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. Top Header Bar (Matching CarController / Gamepad)
                  _buildTopHeaderBar(),

                  // 2. Main Arena: 3 Equal Flex Pods (Left Stick, Center Cockpit, Right Stick)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // LEFT POD: Throttle & Yaw / Rudder (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildLeftStickPod(),
                          ),
                          const SizedBox(width: 10),

                          // CENTER POD: Flight Horizon + Actions + Modes (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildCenterFlightPod(),
                          ),
                          const SizedBox(width: 10),

                          // RIGHT POD: Pitch & Roll / Elevator & Aileron (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildRightStickPod(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Digital Trims Bar
                  _buildBottomTrimsBar(),
                ],
              ),

              // Floating Quick Toast Banner matching Stitch design
              if (_toastMessage != null)
                Positioned(
                  bottom: 44,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withAlpha(235),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Text(
                            _toastMessage!,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER BAR (Light Theme UI/UX)
  // ==========================================
  Widget _buildTopHeaderBar() {
    final isArmed = _drone.isArmed;
    final isConnected = _robot.isConnected || _drone.packetRateHz > 0;
    final bat = _drone.batteryVoltage;
    final batPct = _drone.batteryPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withAlpha(245) : Colors.white.withAlpha(245),
        border: Border(bottom: BorderSide(color: cardBorder)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x050F172A),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back button + Title + Arm/Connected Badge
          Flexible(
            flex: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_drone.isArmed) _drone.disarm();
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                    ]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1), size: 17),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "LiteWing Drone",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),

                // Connected / Armed Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isArmed
                        ? const Color(0xFFFEF2F2)
                        : (isConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isArmed
                          ? const Color(0xFFFECACA)
                          : (isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isArmed
                              ? const Color(0xFFEF4444)
                              : (isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isArmed ? "ARMED" : (isConnected ? "ONLINE" : "DISCONNECTED"),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isArmed
                              ? const Color(0xFFDC2626)
                              : (isConnected ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Telemetry chips & Tool buttons
          Flexible(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Battery Chip
                _buildHeaderBadge(
                  icon: Icons.battery_charging_full,
                  label: "${bat.toStringAsFixed(2)}V ($batPct%)",
                  color: batPct > 30 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  bgColor: batPct > 30 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                ),
                const SizedBox(width: 6),

                // Altitude Chip
                _buildHeaderBadge(
                  icon: Icons.height,
                  label: "${_drone.altitudeMeters.toStringAsFixed(2)}m",
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                ),
                const SizedBox(width: 6),

                // Packet Rate (Hz)
                _buildHeaderBadge(
                  icon: Icons.wifi_tethering,
                  label: "${_drone.packetRateHz}Hz",
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                ),
                const SizedBox(width: 8),

                // Code Snippet Button
                InkWell(
                  onTap: _showCodeSnippetDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.code, size: 16, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 6),

                // Settings / Tuning Button
                InkWell(
                  onTap: () => _openDroneSettings(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.tune, size: 16, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. LEFT POD: THROTTLE & YAW (Mode 2)
  // ==========================================
  Widget _buildLeftStickPod() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x050F172A),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.navigation, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  Text(
                    "THROTTLE / YAW",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  "THR: ${(_drone.thrustInput * 100).toInt()}% | YAW: ${(_drone.yawInput * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Interactive Responsive Joystick Well
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxSize = math.min(constraints.maxWidth, constraints.maxHeight) - 4;
                final radius = boxSize / 2;
                final thumbRadius = radius * 0.36;

                final thumbOffset = Offset(
                  _leftStickDelta.dx * (radius - thumbRadius - 8),
                  _leftStickDelta.dy * (radius - thumbRadius - 8),
                );

                return Center(
                  child: GestureDetector(
                    onPanStart: (d) => _onLeftStickPanStart(d, Size(boxSize, boxSize)),
                    onPanUpdate: (d) => _onLeftStickPanUpdate(d, Size(boxSize, boxSize)),
                    onPanEnd: _onLeftStickPanEnd,
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: wellBg,
                        border: Border.all(
                          color: _leftStickTouching ? const Color(0xFF0284C7) : cardBorder,
                          width: _leftStickTouching ? 1.8 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Crosshair and rings
                          _buildConcentricRings(boxSize),

                          // Left Vertical Thrust Bar Indicator
                          Positioned(
                            left: 14,
                            top: 20,
                            bottom: 20,
                            child: _buildVerticalThrustBar(
                              height: boxSize - 40,
                              percent: _drone.thrustInput,
                            ),
                          ),

                          // 3D Styled Thumb Knob
                          Transform.translate(
                            offset: thumbOffset,
                            child: _buildJoystickThumbKnob(
                              size: thumbRadius * 2,
                              isTouching: _leftStickTouching,
                              icon: Icons.navigation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. RIGHT POD: PITCH & ROLL (Mode 2)
  // ==========================================
  Widget _buildRightStickPod() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x050F172A),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.control_camera, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  Text(
                    "PITCH / ROLL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  "PIT: ${(_drone.pitchInput * 100).toInt()}% | ROL: ${(_drone.rollInput * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Interactive Responsive Joystick Well
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxSize = math.min(constraints.maxWidth, constraints.maxHeight) - 4;
                final radius = boxSize / 2;
                final thumbRadius = radius * 0.36;

                final thumbOffset = Offset(
                  _rightStickDelta.dx * (radius - thumbRadius - 8),
                  _rightStickDelta.dy * (radius - thumbRadius - 8),
                );

                return Center(
                  child: GestureDetector(
                    onPanStart: (d) => _onRightStickPanStart(d, Size(boxSize, boxSize)),
                    onPanUpdate: (d) => _onRightStickPanUpdate(d, Size(boxSize, boxSize)),
                    onPanEnd: _onRightStickPanEnd,
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: wellBg,
                        border: Border.all(
                          color: _rightStickTouching ? const Color(0xFF0284C7) : cardBorder,
                          width: _rightStickTouching ? 1.8 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildConcentricRings(boxSize),

                          // Direction Label Indicators (F / B / L / R)
                          const Positioned(
                            top: 8,
                            child: Text("FWD", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          ),
                          const Positioned(
                            bottom: 8,
                            child: Text("REV", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          ),
                          const Positioned(
                            left: 8,
                            child: Text("LEFT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          ),
                          const Positioned(
                            right: 8,
                            child: Text("RIGHT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          ),

                          // 3D Styled Thumb Knob
                          Transform.translate(
                            offset: thumbOffset,
                            child: _buildJoystickThumbKnob(
                              size: thumbRadius * 2,
                              isTouching: _rightStickTouching,
                              icon: Icons.control_camera,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. CENTER FLIGHT POD: HORIZON + ACTIONS
  // ==========================================
  Widget _buildCenterFlightPod() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x050F172A),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Artificial Horizon / Attitude Gyro (Responsive size)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gaugeSize = math.min(constraints.maxWidth * 0.68, constraints.maxHeight - 6).clamp(50.0, 130.0);
                return Center(
                  child: _buildAttitudeIndicator(size: gaugeSize),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // 2. Flight Modes Selector (MANUAL | ALT HOLD | POS HOLD)
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildModePill("MANUAL", DroneFlightMode.manual),
                _buildModePill("ALT HOLD", DroneFlightMode.altitudeHold),
                _buildModePill("POS HOLD", DroneFlightMode.positionHold),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // 3. Quick Action Row: Auto Takeoff & Land
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                      foregroundColor: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.flight_takeoff, size: 13),
                    label: const Text("TAKEOFF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _drone.autoTakeoff();
                      _showToast("Auto Takeoff initiated...");
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
                      foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.flight_land, size: 13),
                    label: const Text("LAND", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _drone.autoLand();
                      _showToast("Auto Landing initiated...");
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // 4. Primary Safety Controls: ARM / DISARM + EMERGENCY STOP
          Row(
            children: [
              // ARM / DISARM Toggle
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _drone.isArmed ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: Icon(_drone.isArmed ? Icons.lock_open : Icons.lock, size: 14),
                    label: Text(
                      _drone.isArmed ? "DISARM" : "ARM DRONE",
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: _toggleArming,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Big Red Emergency Kill Switch (Matching Car Controller STOP button)
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0x66EF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.pan_tool, size: 14),
                    label: const Text(
                      "EMERGENCY",
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: _triggerEmergencyStop,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. ARTIFICIAL HORIZON ATTITUDE HUD
  // ==========================================
  Widget _buildAttitudeIndicator({required double size}) {
    final rollDeg = _drone.rollInput * 25.0;
    final pitchDeg = _drone.pitchInput * 20.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: wellBg,
        border: Border.all(color: const Color(0xFF0284C7), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x140284C7),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sky & Earth & Horizon Line via CustomPainter
          CustomPaint(
            size: Size(size, size),
            painter: _HorizonSkyGroundPainter(rollDeg: rollDeg, pitchDeg: pitchDeg),
          ),

          // Fixed Airplane Reticle in Center
          CustomPaint(
            size: Size(size, size),
            painter: _AttitudeReticlePainter(),
          ),

          // Roll angle badge overlay
          Positioned(
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                "${rollDeg.toStringAsFixed(0)}° R | ${pitchDeg.toStringAsFixed(0)}° P",
                style: const TextStyle(
                  fontSize: 7.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(String label, DroneFlightMode mode) {
    final isSelected = _drone.flightMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _drone.setFlightMode(mode);
          _showToast("Flight Mode: $label");
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 6. JOYSTICK WELL HELPERS
  // ==========================================
  Widget _buildConcentricRings(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Horizontal & Vertical Crosshairs
        Container(width: size, height: 1, color: const Color(0xFFE2E8F0)),
        Container(width: 1, height: size, color: const Color(0xFFE2E8F0)),
        // Outer concentric ring
        Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
        ),
        // Inner concentric ring
        Container(
          width: size * 0.40,
          height: size * 0.40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBAE6FD).withAlpha(160), width: 1),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalThrustBar({required double height, required double percent}) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 4,
          height: height * percent.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildJoystickThumbKnob({
    required double size,
    required bool isTouching,
    required IconData icon,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: isTouching
              ? [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD), const Color(0xFF0284C7)]
              : [Colors.white, const Color(0xFFF8FAFC), const Color(0xFFCBD5E1)],
        ),
        border: Border.all(
          color: isTouching ? const Color(0xFF0284C7) : Colors.white,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isTouching
                ? const Color(0xFF0284C7).withAlpha(100)
                : const Color(0xFF0F172A).withAlpha(40),
            blurRadius: isTouching ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.45,
          height: size * 0.45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTouching ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
            border: Border.all(color: isTouching ? Colors.white : const Color(0xFFCBD5E1)),
          ),
          child: Center(
            child: Icon(
              icon,
              size: size * 0.28,
              color: isTouching ? Colors.white : const Color(0xFF0284C7),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 7. BOTTOM TRIMS BAR
  // ==========================================
  Widget _buildBottomTrimsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Roll Trim
          _buildTrimAdjuster(
            label: "ROLL",
            value: _drone.rollTrim,
            onDec: () => _drone.adjustRollTrim(-0.01),
            onInc: () => _drone.adjustRollTrim(0.01),
          ),
          // Pitch Trim
          _buildTrimAdjuster(
            label: "PITCH",
            value: _drone.pitchTrim,
            onDec: () => _drone.adjustPitchTrim(-0.01),
            onInc: () => _drone.adjustPitchTrim(0.01),
          ),
          // Yaw Trim
          _buildTrimAdjuster(
            label: "YAW",
            value: _drone.yawTrim,
            onDec: () => _drone.adjustYawTrim(-0.01),
            onInc: () => _drone.adjustYawTrim(0.01),
          ),
          // Zero Trims Reset Button
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(60, 26),
            ),
            icon: const Icon(Icons.refresh, size: 13, color: Color(0xFF0284C7)),
            label: const Text(
              "RESET TRIMS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0284C7),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _drone.resetTrims();
              _showToast("Digital Trims Reset to 0");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrimAdjuster({
    required String label,
    required double value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    final offsetStr = (value >= 0 ? "+${(value * 100).toInt()}" : "${(value * 100).toInt()}");
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove, size: 14, color: Color(0xFF0284C7)),
          onPressed: onDec,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        ),
        Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cardBorder),
          ),
          child: Center(
            child: Text(
              offsetStr,
              style: TextStyle(
                fontSize: 9.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 14, color: Color(0xFF0284C7)),
          onPressed: onInc,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        ),
      ],
    );
  }

  // ==========================================
  // 8. CODE SNIPPET DIALOG (Matching Gamepad)
  // ==========================================
  void _showCodeSnippetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flight, color: Color(0xFF0284C7), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "ESP32-S3 LiteWing UDP Protocol",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bitcraze CRTP over UDP (Port 2390):",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "// Commander frame (15 bytes at 30Hz):\n"
                        "uint8_t buffer[15];\n"
                        "buffer[0] = 0x30; // Port 3, Channel 0\n"
                        "memcpy(&buffer[1], &rollFloat, 4);\n"
                        "memcpy(&buffer[5], &pitchFloat, 4);\n"
                        "memcpy(&buffer[9], &yawRateFloat, 4);\n"
                        "memcpy(&buffer[13], &thrustUint16, 2);\n"
                        "udp.send(buffer, 15, IPAddress(192,168,43,42), 2390);",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF38BDF8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text("Copy Protocol Details", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                              text: "UDP Port: 2390\nDefault AP: 192.168.43.42\nFormat: CRTP 0x30 Commander (15 bytes)",
                            ));
                            Navigator.pop(ctx);
                            _showToast("Protocol Copied to Clipboard!");
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 9. SETTINGS & TUNING MODAL (Light Theme)
  // ==========================================
  void _openDroneSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final ipController = TextEditingController(text: _drone.droneHost);
            final portController = TextEditingController(text: _drone.dronePort.toString());

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, color: Color(0xFF0284C7), size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Drone Configuration & Tuning",
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFE2E8F0)),

                      // UDP Target IP & Port
                      const Text(
                        "DRONE NETWORK TARGET (UDP)",
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ipController,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                labelText: "Drone Host IP",
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                _drone.setNetworkTarget(val.trim(), _drone.dronePort);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: portController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                labelText: "Port",
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                final p = int.tryParse(val) ?? 2390;
                                _drone.setNetworkTarget(_drone.droneHost, p);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Presets
                      Row(
                        children: [
                          const Text("Presets: ", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ActionChip(
                            label: const Text("192.168.43.42 (LiteWing)", style: TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            labelStyle: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                            onPressed: () {
                              _drone.setNetworkTarget("192.168.43.42", 2390);
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text("192.168.4.1 (ESP AP)", style: TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            labelStyle: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                            onPressed: () {
                              _drone.setNetworkTarget("192.168.4.1", 2390);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      // Tuning Sliders
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EXPO / SENSITIVITY: ${(_drone.sensitivityExpo * 100).toInt()}%",
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                Slider(
                                  value: _drone.sensitivityExpo,
                                  min: 0.0,
                                  max: 1.0,
                                  activeColor: const Color(0xFF0284C7),
                                  onChanged: (v) {
                                    _drone.sensitivityExpo = v;
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MAX SPEED CAP: ${_drone.maxThrustPercent.toInt()}%",
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                Slider(
                                  value: _drone.maxThrustPercent,
                                  min: 40.0,
                                  max: 100.0,
                                  activeColor: const Color(0xFFD97706),
                                  onChanged: (v) {
                                    _drone.maxThrustPercent = v;
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Calibrate Gyro
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.explore, size: 16),
                          label: const Text("CALIBRATE GYROSCOPE (FLAT LEVEL)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _drone.calibrateGyro();
                            _showToast("Gyro level command sent!");
                          },
                        ),
                      ),

                      const SizedBox(height: 12),
                      // NeoPixel LEDs
                      const Text(
                        "NEOPIXEL DRONE LEDS",
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLedChip("Cyan", const Color(0xFF0284C7), 2, 132, 199, setModalState),
                          _buildLedChip("Green", const Color(0xFF10B981), 16, 185, 129, setModalState),
                          _buildLedChip("Red", const Color(0xFFEF4444), 239, 68, 68, setModalState),
                          _buildLedChip("Amber", const Color(0xFFF59E0B), 245, 158, 11, setModalState),
                          _buildLedChip("Rainbow", const Color(0xFF8B5CF6), 255, 255, 255, setModalState, pattern: "rainbow"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLedChip(String label, Color color, int r, int g, int b, StateSetter setModalState, {String pattern = "solid"}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _drone.setLedColor(r, g, b, pattern: pattern);
        _showToast("LED: $label");
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

// ==========================================
// ATTITUDE HORIZON RETICLE PAINTER
// ==========================================
class _AttitudeReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFF59E0B) // Amber flight cross
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Center dot
    canvas.drawCircle(center, 2.0, Paint()..color = const Color(0xFFF59E0B));

    // Wings
    canvas.drawLine(Offset(center.dx - 20, center.dy), Offset(center.dx - 8, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 8, center.dy), Offset(center.dx + 20, center.dy), paint);

    // Center V downward tick
    final vPath = Path()
      ..moveTo(center.dx - 5, center.dy)
      ..lineTo(center.dx, center.dy + 4)
      ..lineTo(center.dx + 5, center.dy);
    canvas.drawPath(vPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// ARTIFICIAL HORIZON SKY / GROUND PAINTER
// ==========================================
class _HorizonSkyGroundPainter extends CustomPainter {
  final double rollDeg;
  final double pitchDeg;

  _HorizonSkyGroundPainter({required this.rollDeg, required this.pitchDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.0;

    canvas.save();
    // Clip to circular horizon perimeter
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Apply roll rotation and pitch translation
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rollDeg * (math.pi / 180));
    canvas.translate(0, -pitchDeg * 1.3);

    final extent = size.width * 3.0;

    // 1. Sky (Clean Blue)
    final skyPaint = Paint()..color = const Color(0xFF0284C7);
    canvas.drawRect(Rect.fromLTWH(-extent / 2, -extent, extent, extent), skyPaint);

    // 2. Ground (Warm Earth Amber)
    final groundPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawRect(Rect.fromLTWH(-extent / 2, 0, extent, extent), groundPaint);

    // 3. Horizon separator line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(-extent / 2, 0), Offset(extent / 2, 0), linePaint);

    // 4. Pitch ladder guide marks
    final tickPaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..strokeWidth = 1.2;
    // +10° Climb pitch line
    canvas.drawLine(const Offset(-14, -14), const Offset(14, -14), tickPaint);
    // -10° Dive pitch line
    canvas.drawLine(const Offset(-14, 14), const Offset(14, 14), tickPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HorizonSkyGroundPainter oldDelegate) {
    return oldDelegate.rollDeg != rollDeg || oldDelegate.pitchDeg != pitchDeg;
  }
}
