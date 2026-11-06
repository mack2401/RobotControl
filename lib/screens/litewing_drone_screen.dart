import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/drone/litewing_service.dart';
import '../core/state/robot_state.dart';
import '../core/wifi/wifi_service.dart';

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

  // View toggle in center pod: 0 = Cockpit HUD, 1 = 4 Motors Live Schematic
  int _centerViewMode = 0;

  // Rotor animation angle
  double _flAngle = 0.0;
  double _frAngle = 0.0;
  double _rlAngle = 0.0;
  double _rrAngle = 0.0;

  // Left Stick (Throttle & Yaw) touch tracking
  Offset _leftStickDelta = Offset.zero; // x: -1..1 (yaw), y: -1..1 (throttle)
  bool _leftStickTouching = false;
  double _manualThrottlePosition = 0.0; // 0.0 (bottom) to 1.0 (top)

  // Right Stick (Pitch & Roll) touch tracking
  Offset _rightStickDelta = Offset.zero; // x: -1..1 (roll), y: -1..1 (pitch)
  bool _rightStickTouching = false;

  // Connected Wi-Fi info for automatic link detection
  ConnectedWifiInfo? _phoneWifi;

  @override
  void initState() {
    super.initState();
    // Auto lock to Landscape for piloting arena
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _drone.addListener(_onDroneUpdate);
    _checkPhoneWifi();

    // If drone was already connected in service, ensure loop is active
    if (_drone.isConnected) {
      _drone.startFlightLoop();
    }

    // Fast 40ms UI ticker for horizon, rotor animation & motor gauges
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (mounted) {
        setState(() {
          // Increment spinning rotor angles based on individual motor outputs
          if (_drone.motorFL_percent > 0.01) {
            _flAngle = (_flAngle + _drone.motorFL_percent * 0.7) % (math.pi * 2);
          }
          if (_drone.motorFR_percent > 0.01) {
            _frAngle = (_frAngle - _drone.motorFR_percent * 0.7) % (math.pi * 2);
          }
          if (_drone.motorRL_percent > 0.01) {
            _rlAngle = (_rlAngle - _drone.motorRL_percent * 0.7) % (math.pi * 2);
          }
          if (_drone.motorRR_percent > 0.01) {
            _rrAngle = (_rrAngle + _drone.motorRR_percent * 0.7) % (math.pi * 2);
          }
        });
      }
    });
  }

  Future<void> _checkPhoneWifi() async {
    try {
      final info = await _robot.wifiService.refreshConnectedWifi();
      if (mounted) {
        setState(() {
          _phoneWifi = info;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _toastTimer?.cancel();
    _drone.removeListener(_onDroneUpdate);

    // Stop flight loop if disarmed
    if (!_drone.isArmed) {
      _drone.stopFlightLoop();
    }

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
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
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
    if (!_drone.isConnected) {
      _showToast("Please Connect Drone Wi-Fi First!");
      _openConnectDialog();
      return;
    }

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
    final isConnected = _drone.isConnected;
    final isPhoneOnDroneAp = _phoneWifi != null &&
        (_phoneWifi!.ssid.toLowerCase().contains("litewing") ||
            _phoneWifi!.ssid.toLowerCase().contains("drone") ||
            _phoneWifi!.ip.startsWith("192.168.43."));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
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
                  // 1. Top Header Bar
                  _buildTopHeaderBar(),

                  // Sub-banner if phone is on LiteWing AP but app is not linked yet
                  if (!isConnected && isPhoneOnDroneAp)
                    _buildQuickLinkBanner(),

                  // 2. Main Arena: 3 Equal Flex Pods
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // LEFT POD: Throttle & Yaw (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildLeftStickPod(),
                          ),
                          const SizedBox(width: 8),

                          // CENTER POD: Cockpit HUD or 4-Motor Live Schematic (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildCenterFlightPod(),
                          ),
                          const SizedBox(width: 8),

                          // RIGHT POD: Pitch & Roll (flex: 4)
                          Expanded(
                            flex: 4,
                            child: _buildRightStickPod(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Bar: Trims + Quick Calibration Launcher
                  _buildBottomBar(),
                ],
              ),

              // Floating Toast Notification
              if (_toastMessage != null)
                Positioned(
                  bottom: 46,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withAlpha(240),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(120)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 15, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Text(
                            _toastMessage!,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
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
  // QUICK LINK BANNER (When Phone Wi-Fi matches drone)
  // ==========================================
  Widget _buildQuickLinkBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withAlpha(isDark ? 50 : 25),
        border: Border(bottom: BorderSide(color: const Color(0xFF0284C7).withAlpha(80))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, size: 15, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(
                "Phone is on '${_phoneWifi?.ssid ?? 'LiteWing_AP'}'",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 4),
              Text(
                "• Tap Link to start UDP controls",
                style: TextStyle(fontSize: 10.5, color: textSecondary),
              ),
            ],
          ),
          SizedBox(
            height: 24,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              icon: const Icon(Icons.link, size: 13),
              label: const Text("LINK DRONE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final droneIp = (_phoneWifi?.gateway.isNotEmpty == true && _phoneWifi!.gateway != "0.0.0.0")
                    ? _phoneWifi!.gateway
                    : "192.168.43.42";
                final ok = await _drone.connectDrone(host: droneIp, port: 2390);
                if (ok) {
                  _showToast("LiteWing Drone Connected ($droneIp:2390)!");
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER BAR
  // ==========================================
  Widget _buildTopHeaderBar() {
    final isArmed = _drone.isArmed;
    final isConnected = _drone.isConnected;
    final bat = _drone.batteryVoltage;
    final batPct = _drone.batteryPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withAlpha(245) : Colors.white.withAlpha(245),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back + Title + Real Connection Badge / Connect Button
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1), size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "LiteWing Drone",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),

                // Connected / Disconnected Status Indicator & One-Click Connect
                GestureDetector(
                  onTap: _openConnectDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isArmed
                          ? const Color(0xFFFEF2F2)
                          : (isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isArmed
                            ? const Color(0xFFFECACA)
                            : (isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
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
                                : (isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isArmed
                              ? "ARMED"
                              : (isConnected ? "ONLINE (${_drone.dronePort})" : "DISCONNECTED"),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isArmed
                                ? const Color(0xFFDC2626)
                                : (isConnected ? const Color(0xFF059669) : const Color(0xFFB45309)),
                          ),
                        ),
                        if (!isConnected) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.link, size: 11, color: Color(0xFFB45309)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Telemetry Chips + 4-Motor Calibration Button + Settings
          Flexible(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Battery
                _buildHeaderBadge(
                  icon: Icons.battery_charging_full,
                  label: "${bat.toStringAsFixed(2)}V ($batPct%)",
                  color: batPct > 30 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  bgColor: batPct > 30 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                ),
                const SizedBox(width: 5),

                // Altitude
                _buildHeaderBadge(
                  icon: Icons.height,
                  label: "${_drone.altitudeMeters.toStringAsFixed(2)}m",
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                ),
                const SizedBox(width: 5),

                // Packet Rate: Tx / Rx
                _buildHeaderBadge(
                  icon: Icons.sync_alt,
                  label: "${_drone.txPacketRateHz}T|${_drone.rxPacketRateHz}R",
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                ),
                const SizedBox(width: 6),

                // 4-MOTOR CALIBRATION BUTTON (Hero feature)
                InkWell(
                  onTap: () => _open4MotorCalibrationDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.precision_manufacturing, size: 14, color: Color(0xFF0284C7)),
                        SizedBox(width: 4),
                        Text(
                          "4-MOTORS",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Settings Button
                InkWell(
                  onTap: () => _openDroneSettings(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.tune, size: 15, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 5),

                // Code Snippet Button
                InkWell(
                  onTap: _showCodeSnippetDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.code, size: 15, color: Color(0xFF334155)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.navigation, size: 13, color: Color(0xFF0284C7)),
                  SizedBox(width: 4),
                  Text(
                    "THROTTLE / YAW",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "THR: ${(_drone.thrustInput * 100).toInt()}% | YAW: ${(_drone.yawInput * 100).toInt()}%",
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

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
                          width: _leftStickTouching ? 1.6 : 1.0,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildConcentricRings(boxSize),

                          // Left Vertical Thrust Bar Indicator
                          Positioned(
                            left: 12,
                            top: 16,
                            bottom: 16,
                            child: _buildVerticalThrustBar(
                              height: boxSize - 32,
                              percent: _drone.thrustInput,
                            ),
                          ),

                          // Thumb Knob
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.control_camera, size: 13, color: Color(0xFF0284C7)),
                  SizedBox(width: 4),
                  Text(
                    "PITCH / ROLL",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "PIT: ${(_drone.pitchInput * 100).toInt()}% | ROL: ${(_drone.rollInput * 100).toInt()}%",
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

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
                          width: _rightStickTouching ? 1.6 : 1.0,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildConcentricRings(boxSize),

                          const Positioned(top: 6, child: Text("FWD", style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          const Positioned(bottom: 6, child: Text("REV", style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          const Positioned(left: 6, child: Text("L", style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          const Positioned(right: 6, child: Text("R", style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),

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
  // 4. CENTER FLIGHT POD (Horizon + 4-Motor Visualizer Switch)
  // ==========================================
  Widget _buildCenterFlightPod() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Center Mode Switcher: [HUD GAUGES] vs [4 MOTORS LIVE]
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildSubTabButton("COCKPIT HUD", 0),
                _buildSubTabButton("4-MOTORS LIVE", 1),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 2. Main Center Visualizer (Animated Horizon or 4-Motor Quad Schematic)
          Expanded(
            child: _centerViewMode == 0 ? _buildHorizonAndMotorMini() : _build4MotorLiveSchematic(),
          ),
          const SizedBox(height: 4),

          // 3. Flight Modes Selector (MANUAL | ALT HOLD | POS HOLD)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildModePill("MANUAL", DroneFlightMode.manual),
                _buildModePill("ALT HOLD", DroneFlightMode.altitudeHold),
                _buildModePill("POS HOLD", DroneFlightMode.positionHold),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 4. Quick Action Row: Auto Takeoff & Land
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFF0F9FF),
                      foregroundColor: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    icon: const Icon(Icons.flight_takeoff, size: 12),
                    label: const Text("TAKEOFF", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _drone.autoTakeoff();
                      _showToast("Auto Takeoff initiated...");
                    },
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
                      foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    icon: const Icon(Icons.flight_land, size: 12),
                    label: const Text("LAND", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 4),

          // 5. Primary Safety Controls: ARM / DISARM + EMERGENCY STOP
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _drone.isArmed ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    icon: Icon(_drone.isArmed ? Icons.lock_open : Icons.lock, size: 13),
                    label: Text(
                      _drone.isArmed ? "DISARM" : "ARM DRONE",
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: _toggleArming,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    icon: const Icon(Icons.pan_tool, size: 13),
                    label: const Text(
                      "EMERGENCY",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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

  Widget _buildSubTabButton(String label, int index) {
    final isSelected = _centerViewMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _centerViewMode = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0284C7) : textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW A: HORIZON HUD + MINI 4-MOTOR BARS
  // ==========================================
  Widget _buildHorizonAndMotorMini() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Motors Mini-Bar (FL, RL)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniMotorGauge("FL (M1)", _drone.motorFL_percent, _drone.calibMotorFL, isCw: true),
            const SizedBox(height: 6),
            _buildMiniMotorGauge("RL (M3)", _drone.motorRL_percent, _drone.calibMotorRL, isCw: false),
          ],
        ),
        const SizedBox(width: 8),

        // Center Artificial Horizon
        LayoutBuilder(
          builder: (context, constraints) {
            final gaugeSize = math.min(constraints.maxWidth * 0.55, constraints.maxHeight).clamp(50.0, 105.0);
            return _buildAttitudeIndicator(size: gaugeSize);
          },
        ),
        const SizedBox(width: 8),

        // Right Motors Mini-Bar (FR, RR)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniMotorGauge("FR (M2)", _drone.motorFR_percent, _drone.calibMotorFR, isCw: false),
            const SizedBox(height: 6),
            _buildMiniMotorGauge("RR (M4)", _drone.motorRR_percent, _drone.calibMotorRR, isCw: true),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniMotorGauge(String label, double percent, double calib, {required bool isCw}) {
    final pctInt = (percent * 100).toInt();
    final calibInt = (calib * 100).toInt();
    final color = percent > 0.8
        ? const Color(0xFFEF4444)
        : (percent > 0.4 ? const Color(0xFF10B981) : const Color(0xFF0284C7));

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: wellBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
              Text("${calibInt}%", style: TextStyle(fontSize: 6.5, color: textSecondary, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 1),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            "$pctInt%",
            style: TextStyle(fontSize: 7.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW B: TOP-DOWN 4-MOTOR QUADCOPTER SCHEMATIC
  // ==========================================
  Widget _build4MotorLiveSchematic() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: boxSize,
            height: boxSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cross Arms
                Transform.rotate(
                  angle: 0.785398, // 45 deg
                  child: Container(
                    width: boxSize * 0.78,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -0.785398, // -45 deg
                  child: Container(
                    width: boxSize * 0.78,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Fuselage Center Hub
                Container(
                  width: boxSize * 0.28,
                  height: boxSize * 0.28,
                  decoration: BoxDecoration(
                    color: wellBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flight, size: 14, color: Color(0xFF0284C7)),
                        Text(
                          "LITEWING",
                          style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

                // Front Arrow
                Positioned(
                  top: boxSize * 0.12,
                  child: const Icon(Icons.arrow_drop_up, size: 16, color: Color(0xFF0284C7)),
                ),

                // MOTOR 1: Front-Left (CW, Pin 4)
                Positioned(
                  left: boxSize * 0.04,
                  top: boxSize * 0.04,
                  child: _buildRotorPod(
                    label: "M1 FL",
                    pin: "P4",
                    isCw: true,
                    percent: _drone.motorFL_percent,
                    angle: _flAngle,
                    calib: _drone.calibMotorFL,
                    rpm: _drone.motorFL_rpm,
                    size: boxSize * 0.32,
                  ),
                ),

                // MOTOR 2: Front-Right (CCW, Pin 5)
                Positioned(
                  right: boxSize * 0.04,
                  top: boxSize * 0.04,
                  child: _buildRotorPod(
                    label: "M2 FR",
                    pin: "P5",
                    isCw: false,
                    percent: _drone.motorFR_percent,
                    angle: _frAngle,
                    calib: _drone.calibMotorFR,
                    rpm: _drone.motorFR_rpm,
                    size: boxSize * 0.32,
                  ),
                ),

                // MOTOR 3: Rear-Left (CCW, Pin 6)
                Positioned(
                  left: boxSize * 0.04,
                  bottom: boxSize * 0.04,
                  child: _buildRotorPod(
                    label: "M3 RL",
                    pin: "P6",
                    isCw: false,
                    percent: _drone.motorRL_percent,
                    angle: _rlAngle,
                    calib: _drone.calibMotorRL,
                    rpm: _drone.motorRL_rpm,
                    size: boxSize * 0.32,
                  ),
                ),

                // MOTOR 4: Rear-Right (CW, Pin 7)
                Positioned(
                  right: boxSize * 0.04,
                  bottom: boxSize * 0.04,
                  child: _buildRotorPod(
                    label: "M4 RR",
                    pin: "P7",
                    isCw: true,
                    percent: _drone.motorRR_percent,
                    angle: _rrAngle,
                    calib: _drone.calibMotorRR,
                    rpm: _drone.motorRR_rpm,
                    size: boxSize * 0.32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRotorPod({
    required String label,
    required String pin,
    required bool isCw,
    required double percent,
    required double angle,
    required double calib,
    required int rpm,
    required double size,
  }) {
    final activeColor = percent > 0.8
        ? const Color(0xFFEF4444)
        : (percent > 0.25 ? const Color(0xFF10B981) : const Color(0xFF0284C7));

    return GestureDetector(
      onTap: () => _open4MotorCalibrationDialog(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: wellBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: percent > 0.05 ? activeColor : cardBorder,
            width: percent > 0.05 ? 1.6 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated Spinning Propeller Blades
            Transform.rotate(
              angle: angle,
              child: SizedBox(
                width: size * 0.82,
                height: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: percent > 0.05 ? activeColor.withAlpha(200) : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: percent > 0.05 ? activeColor.withAlpha(200) : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Inner motor hub with data
            Container(
              width: size * 0.58,
              height: size * 0.58,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder, width: 0.8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold)),
                  Text(
                    "${(percent * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                  ),
                  Text(
                    "${(calib * 100).toInt()}% cal",
                    style: TextStyle(fontSize: 6, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ARTIFICIAL HORIZON ATTITUDE HUD
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
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _HorizonSkyGroundPainter(rollDeg: rollDeg, pitchDeg: pitchDeg),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _AttitudeReticlePainter(),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                "${rollDeg.toStringAsFixed(0)}° R | ${pitchDeg.toStringAsFixed(0)}° P",
                style: const TextStyle(fontSize: 7, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0284C7) : textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConcentricRings(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: size, height: 1, color: const Color(0xFFE2E8F0)),
        Container(width: 1, height: size, color: const Color(0xFFE2E8F0)),
        Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
        ),
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
          width: 1.8,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.35,
          color: isTouching ? Colors.white : const Color(0xFF0284C7),
        ),
      ),
    );
  }

  // ==========================================
  // 5. BOTTOM BAR: TRIMS & QUICK ACTIONS
  // ==========================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTrimAdjuster(
            label: "ROLL",
            value: _drone.rollTrim,
            onDec: () => _drone.adjustRollTrim(-0.01),
            onInc: () => _drone.adjustRollTrim(0.01),
          ),
          _buildTrimAdjuster(
            label: "PITCH",
            value: _drone.pitchTrim,
            onDec: () => _drone.adjustPitchTrim(-0.01),
            onInc: () => _drone.adjustPitchTrim(0.01),
          ),
          _buildTrimAdjuster(
            label: "YAW",
            value: _drone.yawTrim,
            onDec: () => _drone.adjustYawTrim(-0.01),
            onInc: () => _drone.adjustYawTrim(0.01),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              minimumSize: const Size(50, 24),
            ),
            icon: const Icon(Icons.refresh, size: 12, color: Color(0xFF0284C7)),
            label: const Text("RESET", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
            onPressed: () {
              HapticFeedback.selectionClick();
              _drone.resetTrims();
              _showToast("Trims Reset to 0");
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
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textSecondary)),
        const SizedBox(width: 3),
        IconButton(
          icon: const Icon(Icons.remove, size: 13, color: Color(0xFF0284C7)),
          onPressed: onDec,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        ),
        Container(
          width: 30,
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cardBorder),
          ),
          child: Center(
            child: Text(
              offsetStr,
              style: TextStyle(fontSize: 8.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 13, color: Color(0xFF0284C7)),
          onPressed: onInc,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        ),
      ],
    );
  }

  // ==========================================
  // 6. CONNECT / LINK DRONE DIALOG
  // ==========================================
  void _openConnectDialog() {
    final ipController = TextEditingController(text: _drone.droneHost);
    final portController = TextEditingController(text: _drone.dronePort.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isPhoneOnDroneAp = _phoneWifi != null &&
              (_phoneWifi!.ssid.toLowerCase().contains("litewing") ||
                  _phoneWifi!.ssid.toLowerCase().contains("drone") ||
                  _phoneWifi!.ip.startsWith("192.168.43."));

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.wifi_tethering, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  "Connect LiteWing Drone",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone Wi-Fi Status Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPhoneOnDroneAp
                          ? const Color(0xFF059669).withAlpha(20)
                          : const Color(0xFF0284C7).withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPhoneOnDroneAp ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPhoneOnDroneAp ? Icons.check_circle : Icons.info_outline,
                          color: isPhoneOnDroneAp ? const Color(0xFF059669) : const Color(0xFF0284C7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _phoneWifi != null
                                    ? "Phone Wi-Fi: ${_phoneWifi!.ssid}"
                                    : "Scanning phone Wi-Fi...",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isPhoneOnDroneAp
                                    ? "LiteWing AP detected! Ready for high-speed UDP link."
                                    : "Connect phone to 'LiteWing_AP' in phone Wi-Fi Settings.",
                                style: TextStyle(fontSize: 10, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // IP & Port Input
                  const Text("DRONE TARGET IP & PORT", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ipController,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            labelText: "Drone IP",
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
                        label: const Text("192.168.43.42", style: TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ipController.text = "192.168.43.42";
                          portController.text = "2390";
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text("192.168.4.1", style: TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ipController.text = "192.168.4.1";
                          portController.text = "2390";
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings, size: 14),
                label: const Text("Phone Wi-Fi", style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _robot.wifiService.openWifiSettings();
                },
              ),
              if (_drone.isConnected)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _drone.disconnectDrone();
                    Navigator.pop(ctx);
                    _showToast("Drone Disconnected.");
                  },
                  child: const Text("Disconnect", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final ip = ipController.text.trim();
                  final p = int.tryParse(portController.text.trim()) ?? 2390;
                  Navigator.pop(ctx);
                  _showToast("Connecting to $ip:$p...");
                  final ok = await _drone.connectDrone(host: ip, port: p);
                  if (ok) {
                    _showToast("Connected to LiteWing Drone ($ip:$p)!");
                  }
                },
                child: const Text("Link Drone", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 7. COMPREHENSIVE 4-MOTOR CALIBRATION & BENCH TESTING MODAL
  // ==========================================
  void _open4MotorCalibrationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MotorCalibrationSheet(drone: _drone),
    );
  }

  // ==========================================
  // 8. SETTINGS & SENSITIVITY MODAL
  // ==========================================
  void _openDroneSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, color: Color(0xFF0284C7), size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Flight Dynamics & LED Settings",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const Divider(),

                      // Expo & Speed Cap
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EXPO / SENSITIVITY: ${(_drone.sensitivityExpo * 100).toInt()}%",
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
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
                                  "SPEED CAP: ${_drone.maxThrustPercent.toInt()}%",
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
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

                      // Gyro Calibrate Button
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                          icon: const Icon(Icons.explore, size: 16),
                          label: Text(
                            _drone.isCalibratingSensors ? "CALIBRATING LEVEL..." : "CALIBRATE LEVEL GYRO (FLAT SURFACE)",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _drone.isCalibratingSensors
                              ? null
                              : () async {
                                  HapticFeedback.mediumImpact();
                                  _drone.calibrateSensors();
                                  _showToast("Keep drone stationary on flat ground!");
                                  setModalState(() {});
                                },
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text("NEOPIXEL DRONE LEDS", style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.bold)),
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
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  void _showCodeSnippetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                          "LiteWing UDP Commander & 4-Motor Calibration",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CRTP Commander & Motor Calibration Protocol:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        "// 30Hz CRTP UDP Flight Frame (Port 2390):\n"
                        "uint8_t buffer[15];\n"
                        "buffer[0] = 0x30; // CRTP Commander (Port 3, Chan 0)\n"
                        "memcpy(&buffer[1], &roll, 4);\n"
                        "memcpy(&buffer[5], &pitch, 4);\n"
                        "memcpy(&buffer[9], &yawRate, 4);\n"
                        "memcpy(&buffer[13], &thrust, 2);\n"
                        "udp.send(buffer, 15, IPAddress(192,168,43,42), 2390);\n\n"
                        "// Real-World 4-Motor Calibration Command:\n"
                        "// CMD:MOTOR_CAL:<fl_pct>,<fr_pct>,<rl_pct>,<rr_pct>,<idle>,<max>\n"
                        "// Example: CMD:MOTOR_CAL:102,98,100,100,80,1023\\n",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF38BDF8)),
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
                              text: "UDP Port: 2390\nDefault AP: 192.168.43.42\nCommander: 15-byte CRTP (0x30)\nCalib: CMD:MOTOR_CAL:<fl>,<fr>,<rl>,<rr>,<idle>,<max>",
                            ));
                            Navigator.pop(ctx);
                            _showToast("Protocol Details Copied!");
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
}

// ============================================================================
// 4-MOTOR CALIBRATION & BENCH TESTING SHEET (The Real-World Tuning Center)
// ============================================================================
class _MotorCalibrationSheet extends StatefulWidget {
  final LiteWingService drone;
  const _MotorCalibrationSheet({required this.drone});

  @override
  State<_MotorCalibrationSheet> createState() => _MotorCalibrationSheetState();
}

class _MotorCalibrationSheetState extends State<_MotorCalibrationSheet> {
  int _activeTab = 0; // 0 = Trims & Balance, 1 = Spin Bench Test, 2 = Calibration Wizard
  bool _safetyLockAcknowledged = false;
  double _masterTestSlider = 0.0;

  @override
  void dispose() {
    // Cut motors if user closes while bench testing
    if (widget.drone.isBenchTesting) {
      widget.drone.stopMotorTest();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drone = widget.drone;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.precision_manufacturing, color: Color(0xFF0284C7), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "4-Motor Precision Calibration & Bench",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Adjust M1 (FL), M2 (FR), M3 (RL), M4 (RR) thrust scales & idle",
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Tab Selector: [1. TRIMS & BALANCE] | [2. BENCH TEST] | [3. WIZARD]
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTabPill("1. MOTOR TRIMS", 0),
                  _buildTabPill("2. BENCH TEST", 1),
                  _buildTabPill("3. DRIFT WIZARD", 2),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: SingleChildScrollView(
                child: _activeTab == 0
                    ? _buildTrimsTab(drone)
                    : (_activeTab == 1 ? _buildBenchTestTab(drone) : _buildWizardTab(drone)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String label, int index) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeTab = index;
            if (index != 1 && widget.drone.isBenchTesting) {
              widget.drone.stopMotorTest();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
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
  // TAB 1: 4-MOTOR TRIMS & BALANCE
  // ==========================================
  Widget _buildTrimsTab(LiteWingService drone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper hint
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Individual motor multipliers (70% - 130%) calibrate manufacturing variations in coreless motor thrust. Calibrations are saved to storage and sent to drone firmware.",
                  style: TextStyle(fontSize: 10, color: Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4 Motors Grid
        Row(
          children: [
            // M1 Front-Left (CW)
            Expanded(
              child: _buildMotorTrimControl(
                label: "M1 Front-Left (FL)",
                pin: "Pin 4 • CW",
                calibVal: drone.calibMotorFL,
                onChanged: (v) => drone.setMotorCalibration(fl: v),
              ),
            ),
            const SizedBox(width: 10),
            // M2 Front-Right (CCW)
            Expanded(
              child: _buildMotorTrimControl(
                label: "M2 Front-Right (FR)",
                pin: "Pin 5 • CCW",
                calibVal: drone.calibMotorFR,
                onChanged: (v) => drone.setMotorCalibration(fr: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // M3 Rear-Left (CCW)
            Expanded(
              child: _buildMotorTrimControl(
                label: "M3 Rear-Left (RL)",
                pin: "Pin 6 • CCW",
                calibVal: drone.calibMotorRL,
                onChanged: (v) => drone.setMotorCalibration(rl: v),
              ),
            ),
            const SizedBox(width: 10),
            // M4 Rear-Right (CW)
            Expanded(
              child: _buildMotorTrimControl(
                label: "M4 Rear-Right (RR)",
                pin: "Pin 7 • CW",
                calibVal: drone.calibMotorRR,
                onChanged: (v) => drone.setMotorCalibration(rr: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Idle Throttle & Max PWM
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MIN IDLE SPIN PWM: ${drone.minIdlePwm} (${((drone.minIdlePwm / 1023) * 100).toStringAsFixed(1)}%)",
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Keeps motors spinning smoothly on arming to prevent in-flight stall.",
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                  ),
                  Slider(
                    value: drone.minIdlePwm.toDouble(),
                    min: 40.0,
                    max: 200.0,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (v) => drone.setMotorCalibration(idle: v.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MAX MOTOR CAP: ${drone.maxOutputPwm} (${((drone.maxOutputPwm / 1023) * 100).toStringAsFixed(0)}%)",
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Limits top-end current to avoid motor overheating or voltage sag.",
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                  ),
                  Slider(
                    value: drone.maxOutputPwm.toDouble(),
                    min: 600.0,
                    max: 1023.0,
                    activeColor: const Color(0xFFD97706),
                    onChanged: (v) => drone.setMotorCalibration(maxPwm: v.toInt()),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bottom Actions: Save & Sync, Reset
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, size: 15),
                label: const Text("SAVE & SYNC TO DRONE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  drone.sendMotorCalibrationToDrone();
                  drone.saveCalibrationsToStorage();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("4-Motor Calibrations Saved & Dispatched to Drone!")),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text("RESET ALL (100%)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                HapticFeedback.selectionClick();
                drone.resetMotorCalibrations();
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMotorTrimControl({
    required String label,
    required String pin,
    required double calibVal,
    required ValueChanged<double> onChanged,
  }) {
    final pctInt = (calibVal * 100).round();
    final isTrimmed = pctInt != 100;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isTrimmed ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTrimmed ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
          width: isTrimmed ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isTrimmed ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "$pctInt%",
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isTrimmed ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          Text(pin, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
          const SizedBox(height: 4),

          // Fine Adjustment Step Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepBtn("-5%", () => onChanged(calibVal - 0.05)),
              _buildStepBtn("-1%", () => onChanged(calibVal - 0.01)),
              _buildStepBtn("100%", () => onChanged(1.00)),
              _buildStepBtn("+1%", () => onChanged(calibVal + 0.01)),
              _buildStepBtn("+5%", () => onChanged(calibVal + 0.05)),
            ],
          ),
          const SizedBox(height: 2),

          Slider(
            value: calibVal,
            min: 0.70,
            max: 1.30,
            activeColor: const Color(0xFF0284C7),
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // TAB 2: MOTOR SPIN BENCH TEST (SAFETY INTERLOCKED)
  // ==========================================
  Widget _buildBenchTestTab(LiteWingService drone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prominent Safety Warning
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _safetyLockAcknowledged ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _safetyLockAcknowledged ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: _safetyLockAcknowledged ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SAFETY HAZARD: REMOVE ALL 4 PROPELLERS!",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Bench testing spins motors directly at up to 28,000 RPM. Never test with propellers installed.",
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _safetyLockAcknowledged,
                activeColor: const Color(0xFF059669),
                onChanged: (v) {
                  setState(() {
                    _safetyLockAcknowledged = v;
                    if (!v) drone.stopMotorTest();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (!_safetyLockAcknowledged) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.lock, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text(
                    "Motor bench testing is locked for safety.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Toggle the safety switch above to confirm propellers are removed.",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Master All-Motors Slider
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "MASTER ALL MOTORS: ${(_masterTestSlider * 100).toInt()}% (PWM: ${(_masterTestSlider * drone.maxOutputPwm).round()})",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                      Slider(
                        value: _masterTestSlider,
                        min: 0.0,
                        max: 0.50, // Cap at 50% for bench safety
                        activeColor: const Color(0xFF0284C7),
                        onChanged: (v) {
                          setState(() {
                            _masterTestSlider = v;
                            final pwm = (v * drone.maxOutputPwm).round();
                            drone.testMotor(0, pwm);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.stop, size: 14),
                  label: const Text("STOP ALL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _masterTestSlider = 0.0;
                      drone.stopMotorTest();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4 Individual Motor Test Sliders
          Row(
            children: [
              Expanded(
                child: _buildIndividualMotorTestCard(
                  name: "M1 Front-Left",
                  pin: "Pin 4 (CW)",
                  index: 1,
                  currentPwm: drone.testMotorFL_pwm,
                  maxPwm: drone.maxOutputPwm,
                  onPwmChange: (pwm) => drone.testMotor(1, pwm),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIndividualMotorTestCard(
                  name: "M2 Front-Right",
                  pin: "Pin 5 (CCW)",
                  index: 2,
                  currentPwm: drone.testMotorFR_pwm,
                  maxPwm: drone.maxOutputPwm,
                  onPwmChange: (pwm) => drone.testMotor(2, pwm),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildIndividualMotorTestCard(
                  name: "M3 Rear-Left",
                  pin: "Pin 6 (CCW)",
                  index: 3,
                  currentPwm: drone.testMotorRL_pwm,
                  maxPwm: drone.maxOutputPwm,
                  onPwmChange: (pwm) => drone.testMotor(3, pwm),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIndividualMotorTestCard(
                  name: "M4 Rear-Right",
                  pin: "Pin 7 (CW)",
                  index: 4,
                  currentPwm: drone.testMotorRR_pwm,
                  maxPwm: drone.maxOutputPwm,
                  onPwmChange: (pwm) => drone.testMotor(4, pwm),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIndividualMotorTestCard({
    required String name,
    required String pin,
    required int index,
    required int currentPwm,
    required int maxPwm,
    required ValueChanged<int> onPwmChange,
  }) {
    final pct = (currentPwm / maxPwm).clamp(0.0, 1.0);
    final pctInt = (pct * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: currentPwm > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: currentPwm > 0 ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(pin, style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                ],
              ),
              Text(
                "$pctInt% ($currentPwm)",
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: currentPwm > 0 ? const Color(0xFF059669) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Slider capped at 40% for bench safety
          Slider(
            value: pct,
            min: 0.0,
            max: 0.40,
            activeColor: const Color(0xFF059669),
            onChanged: (v) {
              final pwm = (v * maxPwm).round();
              onPwmChange(pwm);
              setState(() {});
            },
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pulse 15% button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPwmChange(150); // ~15%
                  Timer(const Duration(milliseconds: 600), () {
                    onPwmChange(0);
                    setState(() {});
                  });
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text("Pulse 15%", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                ),
              ),
              // Cut button
              InkWell(
                onTap: () {
                  onPwmChange(0);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text("Cut", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: GUIDED 4-MOTOR CALIBRATION WIZARD
  // ==========================================
  Widget _buildWizardTab(LiteWingService drone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Real-World Flight Calibration Assistant",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
        ),
        const SizedBox(height: 4),
        Text(
          "If your LiteWing tilts or drifts during hover, use these one-touch drift compensators to automatically balance the 4 motors.",
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),

        // Step 1: Flat level gyro zeroing
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                child: const Center(child: Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Zero Gyro & Accelerometer", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text("Place drone stationary on a level floor before flight.", style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () {
                  drone.calibrateSensors();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gyro Level Zeroed!")),
                  );
                },
                child: const Text("Calibrate Level", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Step 2: In-Flight Drift Compensation
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                    child: const Center(child: Text("2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hover Drift Balance Assistant", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("Tap the direction your drone tends to drift toward to nudge motor trims:", style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Directional Nudge Pad
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      _buildDriftBtn("Drifting FWD ⬆", "forward", drone),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildDriftBtn("Drift LEFT ⬅", "left", drone),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                            child: const Icon(Icons.flight, size: 20, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          _buildDriftBtn("Drift RIGHT ➡", "right", drone),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildDriftBtn("Drifting REV ⬇", "backward", drone),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Yaw Drift
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDriftBtn("Spinning CW 🔄", "cw", drone),
                  const SizedBox(width: 12),
                  _buildDriftBtn("Spinning CCW 🔃", "ccw", drone),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriftBtn(String label, String direction, LiteWingService drone) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0284C7),
          side: const BorderSide(color: Color(0xFFBAE6FD)),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          drone.adjustForDrift(direction);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Motor trims adjusted for '$direction' drift! FL:${(drone.calibMotorFL*100).toInt()}% FR:${(drone.calibMotorFR*100).toInt()}% RL:${(drone.calibMotorRL*100).toInt()}% RR:${(drone.calibMotorRR*100).toInt()}%"),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
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
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 2.0, Paint()..color = const Color(0xFFF59E0B));
    canvas.drawLine(Offset(center.dx - 18, center.dy), Offset(center.dx - 6, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 6, center.dy), Offset(center.dx + 18, center.dy), paint);

    final vPath = Path()
      ..moveTo(center.dx - 4, center.dy)
      ..lineTo(center.dx, center.dy + 3.5)
      ..lineTo(center.dx + 4, center.dy);
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
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    canvas.translate(center.dx, center.dy);
    canvas.rotate(rollDeg * (math.pi / 180));
    canvas.translate(0, -pitchDeg * 1.2);

    final extent = size.width * 3.0;

    // Sky
    final skyPaint = Paint()..color = const Color(0xFF0284C7);
    canvas.drawRect(Rect.fromLTWH(-extent / 2, -extent, extent, extent), skyPaint);

    // Ground
    final groundPaint = Paint()..color = const Color(0xFFB45309);
    canvas.drawRect(Rect.fromLTWH(-extent / 2, 0, extent, extent), groundPaint);

    // Horizon line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(-extent / 2, 0), Offset(extent / 2, 0), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HorizonSkyGroundPainter oldDelegate) {
    return oldDelegate.rollDeg != rollDeg || oldDelegate.pitchDeg != pitchDeg;
  }
}
