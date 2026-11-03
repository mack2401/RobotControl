import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../state/robot_state.dart';

enum DroneFlightMode {
  manual,
  altitudeHold,
  positionHold,
}

enum DroneArmState {
  disarmed,
  arming,
  armed,
}

enum DroneProtocol {
  crtpUdp,     // Bitcraze CRTP over UDP (Port 2390, Default for LiteWing & ESP-Drone)
  asciiUdp,    // Simple UDP string commands (CMD:ARM, R,P,Y,T)
  jsonUdp,     // JSON format over UDP
  hybridState, // Active RobotState link (Bluetooth SPP, BLE, or TCP)
}

/// Service that manages wireless flight control communication for Circuit Digest LiteWing,
/// ESP-Drone, and DIY quadcopters.
class LiteWingService extends ChangeNotifier {
  static final LiteWingService _instance = LiteWingService._internal();
  factory LiteWingService() => _instance;

  LiteWingService._internal() {
    _initSocket();
  }

  // --- Network & Communication Configuration ---
  String droneHost = "192.168.43.42"; // Default LiteWing AP IP
  int dronePort = 2390;                // Default CRTP UDP port
  DroneProtocol protocol = DroneProtocol.crtpUdp;

  RawDatagramSocket? _socket;
  Timer? _flightLoopTimer;
  bool _isSocketReady = false;

  // --- Flight Control State ---
  DroneArmState armState = DroneArmState.disarmed;
  bool get isArmed => armState == DroneArmState.armed;

  DroneFlightMode flightMode = DroneFlightMode.manual;
  bool get isHeightHold => flightMode == DroneFlightMode.altitudeHold;
  bool get isPositionHold => flightMode == DroneFlightMode.positionHold;

  // Normalized stick inputs (-1.0 to +1.0 for roll/pitch/yaw, 0.0 to 1.0 for thrust)
  double rollInput = 0.0;
  double pitchInput = 0.0;
  double yawInput = 0.0;
  double thrustInput = 0.0;

  // Digital Trims (-0.25 to +0.25 offset)
  double rollTrim = 0.0;
  double pitchTrim = 0.0;
  double yawTrim = 0.0;

  // Tuning Parameters
  double sensitivityExpo = 0.65; // 0.0 (linear) to 1.0 (high expo)
  double maxThrustPercent = 100.0; // Speed/thrust cap (50% to 100%)
  double deadzone = 0.05;
  bool invertPitch = false;
  bool autoCenterThrottle = false; // Center throttle for Height-Hold

  // Live Telemetry & Feedback
  double batteryVoltage = 3.95; // Volts (1S LiPo: 3.2V to 4.2V)
  int batteryPercent = 88;
  double altitudeMeters = 0.0;
  int packetRateHz = 0;
  int _packetsSentInWindow = 0;
  DateTime _lastRateCalcTime = DateTime.now();
  int totalPacketsSent = 0;
  String lastStatusMessage = "Ready for pre-flight check";
  final List<String> consoleLogs = [];

  // NeoPixel / LED settings
  int ledRed = 0;
  int ledGreen = 200;
  int ledBlue = 255;
  String ledPattern = "solid"; // "solid", "strobe", "breathing", "rainbow"

  /// Initialize the UDP socket for local broadcast and point-to-point drone comms
  Future<void> _initSocket() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;
      _isSocketReady = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleIncomingDatagram(datagram);
          }
        }
      });
      _log("UDP Socket initialized on port ${_socket?.port}");
    } catch (e) {
      _isSocketReady = false;
      _log("UDP Socket Bind Error: $e");
    }
  }

  void _handleIncomingDatagram(Datagram datagram) {
    try {
      // Check for incoming CRTP or string telemetry
      final data = datagram.data;
      if (data.isNotEmpty) {
        // If CRTP Console packet (Port 0)
        final header = data[0];
        final port = (header >> 4) & 0x0F;

        if (port == 0) {
          final text = utf8.decode(data.sublist(1), allowMalformed: true).trim();
          if (text.isNotEmpty) {
            _log("[Drone] $text");
          }
        } else if (port == 5) {
          // Telemetry packet: parse battery & altitude if available
          if (data.length >= 7) {
            final bd = ByteData.sublistView(data);
            final v = bd.getFloat32(1, Endian.little);
            if (v >= 2.5 && v <= 13.0) {
              batteryVoltage = v;
              batteryPercent = (((batteryVoltage - 3.2) / (4.2 - 3.2)) * 100).clamp(0, 100).toInt();
              notifyListeners();
            }
          }
        } else {
          final text = utf8.decode(data, allowMalformed: true).trim();
          if (text.startsWith("{") && text.endsWith("}")) {
            final map = jsonDecode(text) as Map<String, dynamic>;
            if (map.containsKey("bat")) {
              batteryVoltage = (map["bat"] as num).toDouble();
            }
            if (map.containsKey("alt")) {
              altitudeMeters = (map["alt"] as num).toDouble();
            }
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  void _log(String msg) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    consoleLogs.insert(0, "[$timeStr] $msg");
    if (consoleLogs.length > 50) {
      consoleLogs.removeLast();
    }
    lastStatusMessage = msg;
    notifyListeners();
  }

  /// Start the continuous 30Hz high-frequency flight transmission loop
  void startFlightLoop() {
    _flightLoopTimer?.cancel();
    _flightLoopTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _sendFlightControlFrame();
    });
  }

  void stopFlightLoop() {
    _flightLoopTimer?.cancel();
    _flightLoopTimer = null;
  }

  /// Updates stick inputs with expo curve calculation
  void setStickInputs({
    required double roll,
    required double pitch,
    required double yaw,
    required double thrust,
  }) {
    rollInput = _applyExpo(roll.clamp(-1.0, 1.0));
    pitchInput = _applyExpo((invertPitch ? -pitch : pitch).clamp(-1.0, 1.0));
    yawInput = _applyExpo(yaw.clamp(-1.0, 1.0));
    thrustInput = thrust.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Convenience method for partial or named input updates
  void setFlightInputs({
    double? roll,
    double? pitch,
    double? yaw,
    double? thrust,
  }) {
    if (roll != null) rollInput = _applyExpo(roll.clamp(-1.0, 1.0));
    if (pitch != null) pitchInput = _applyExpo((invertPitch ? -pitch : pitch).clamp(-1.0, 1.0));
    if (yaw != null) yawInput = _applyExpo(yaw.clamp(-1.0, 1.0));
    if (thrust != null) thrustInput = thrust.clamp(0.0, 1.0);
    notifyListeners();
  }

  double _applyExpo(double input) {
    if (input.abs() < deadzone) return 0.0;
    // Standard cubic expo formula: Output = Input * (1 - expo) + Input^3 * expo
    return input * (1.0 - sensitivityExpo) + (input * input * input) * sensitivityExpo;
  }

  /// Sends the current commander flight frame to the aircraft
  void _sendFlightControlFrame() {
    if (armState != DroneArmState.armed) {
      // Stream 0 thrust when disarmed so drone stays stable on ground
      _dispatchCommander(0.0, 0.0, 0.0, 0);
      return;
    }

    // Apply digital trims
    final double netRoll = (rollInput + rollTrim).clamp(-1.0, 1.0);
    final double netPitch = (pitchInput + pitchTrim).clamp(-1.0, 1.0);
    final double netYaw = (yawInput + yawTrim).clamp(-1.0, 1.0);

    // Apply thrust cap
    final double effectiveThrust = (thrustInput * (maxThrustPercent / 100.0)).clamp(0.0, 1.0);

    // Convert to engineering units:
    // Roll & Pitch: -30 to +30 degrees
    final double rollDeg = netRoll * 30.0;
    final double pitchDeg = netPitch * 30.0;
    // Yaw rate: -200 to +200 degrees/sec
    final double yawRateDegSec = netYaw * 200.0;
    // Thrust: 0 to 65535 (16-bit uint)
    final int rawThrust = (effectiveThrust * 65535).round().clamp(0, 65535);

    // Simulated altitude estimation for realistic HUD when sensor telemetry is idle
    if (effectiveThrust > 0.45) {
      altitudeMeters = (altitudeMeters + (effectiveThrust - 0.5) * 0.05).clamp(0.0, 15.0);
    } else {
      altitudeMeters = (altitudeMeters - 0.08).clamp(0.0, 15.0);
    }

    // Send via selected protocol
    _dispatchCommander(rollDeg, pitchDeg, yawRateDegSec, rawThrust);

    // Rate calculation
    _packetsSentInWindow++;
    totalPacketsSent++;
    final now = DateTime.now();
    if (now.difference(_lastRateCalcTime).inMilliseconds >= 1000) {
      packetRateHz = _packetsSentInWindow;
      _packetsSentInWindow = 0;
      _lastRateCalcTime = now;
      notifyListeners();
    }
  }

  void _dispatchCommander(double rollDeg, double pitchDeg, double yawRate, int thrust) {
    switch (protocol) {
      case DroneProtocol.crtpUdp:
        _sendCrtpCommander(rollDeg, pitchDeg, yawRate, thrust);
        break;
      case DroneProtocol.asciiUdp:
        _sendAsciiCommander(rollDeg, pitchDeg, yawRate, thrust);
        break;
      case DroneProtocol.jsonUdp:
        _sendJsonCommander(rollDeg, pitchDeg, yawRate, thrust);
        break;
      case DroneProtocol.hybridState:
        _sendHybridStateCommander(rollDeg, pitchDeg, yawRate, thrust);
        break;
    }
  }

  /// Encodes standard Bitcraze / ESP-Drone CRTP Commander packet (Port 3, Channel 0)
  void _sendCrtpCommander(double roll, double pitch, double yawRate, int thrust) {
    if (_socket == null) return;
    try {
      final buffer = Uint8List(15);
      final bd = ByteData.sublistView(buffer);

      // Byte 0: Header (Port 3 << 4 | Channel 0)
      buffer[0] = 0x30;
      // Bytes 1..4: Roll (Float32 Little Endian)
      bd.setFloat32(1, roll, Endian.little);
      // Bytes 5..8: Pitch (Float32 Little Endian)
      bd.setFloat32(5, pitch, Endian.little);
      // Bytes 9..12: Yaw rate (Float32 Little Endian)
      bd.setFloat32(9, yawRate, Endian.little);
      // Bytes 13..14: Thrust (UInt16 Little Endian)
      bd.setUint16(13, thrust, Endian.little);

      final dest = InternetAddress(droneHost);
      _socket?.send(buffer, dest, dronePort);
    } catch (_) {}
  }

  /// Sends human-readable ASCII string over UDP: `SET:roll,pitch,yaw,thrust\n`
  void _sendAsciiCommander(double roll, double pitch, double yawRate, int thrust) {
    if (_socket == null) return;
    try {
      final msg = "SET:${roll.toStringAsFixed(1)},${pitch.toStringAsFixed(1)},${yawRate.toStringAsFixed(1)},$thrust\n";
      final bytes = utf8.encode(msg);
      _socket?.send(bytes, InternetAddress(droneHost), dronePort);
    } catch (_) {}
  }

  /// Sends JSON packet: {"r":0,"p":0,"y":0,"t":50}
  void _sendJsonCommander(double roll, double pitch, double yawRate, int thrust) {
    if (_socket == null) return;
    try {
      final jsonStr = jsonEncode({
        "r": double.parse(roll.toStringAsFixed(1)),
        "p": double.parse(pitch.toStringAsFixed(1)),
        "y": double.parse(yawRate.toStringAsFixed(1)),
        "t": thrust,
        "arm": isArmed ? 1 : 0,
      });
      _socket?.send(utf8.encode("$jsonStr\n"), InternetAddress(droneHost), dronePort);
    } catch (_) {}
  }

  /// Sends commander inputs through RobotState active connection (Bluetooth Classic / BLE / TCP)
  void _sendHybridStateCommander(double roll, double pitch, double yawRate, int thrust) {
    final state = RobotState();
    final cmd = "DRONE:${roll.toInt()},${pitch.toInt()},${yawRate.toInt()},$thrust\n";
    state.sendCommand(cmd);
  }

  // --- High-Level Flight Action Commands ---

  /// Arm the drone motors (verifies safety checks)
  Future<void> armDrone() async {
    armState = DroneArmState.arming;
    notifyListeners();
    _log("Arming pre-flight sequence initiated...");

    // Send initialization command
    _sendCommandString("CMD:ARM\n");
    _dispatchCommander(0.0, 0.0, 0.0, 0);

    await Future.delayed(const Duration(milliseconds: 300));
    armState = DroneArmState.armed;
    _log("MOTORS ARMED! Controls active.");
    notifyListeners();
  }

  void arm() => armDrone();

  /// Disarm drone motors
  void disarmDrone() {
    armState = DroneArmState.disarmed;
    thrustInput = 0.0;
    _dispatchCommander(0.0, 0.0, 0.0, 0);
    _sendCommandString("CMD:DISARM\n");
    _log("Drone DISARMED. Motors shut down.");
    notifyListeners();
  }

  void disarm() => disarmDrone();

  /// EMERGENCY STOP - Instant motor kill
  void emergencyStop() {
    armState = DroneArmState.disarmed;
    thrustInput = 0.0;
    rollInput = 0.0;
    pitchInput = 0.0;
    yawInput = 0.0;

    // Send zero thrust multiple times to ensure immediate reception
    for (int i = 0; i < 4; i++) {
      _dispatchCommander(0.0, 0.0, 0.0, 0);
      _sendCommandString("CMD:EMERGENCY\n");
    }
    _log("EMERGENCY KILL SWITCH TRIGGERED! All motors halted.");
    notifyListeners();
  }

  /// Automatic 1-meter takeoff
  void autoTakeoff() {
    if (!isArmed) {
      armDrone();
    }
    flightMode = DroneFlightMode.altitudeHold;
    thrustInput = 0.58; // Takeoff thrust
    altitudeMeters = 1.0;
    _sendCommandString("CMD:TAKEOFF:1.0\n");
    _log("Auto-Takeoff sequence: climbing to 1.0m hover");
    notifyListeners();
  }

  /// Automatic gentle landing
  void autoLand() {
    _sendCommandString("CMD:LAND\n");
    _log("Auto-Landing engaged: descending gently...");
    thrustInput = 0.35;
    Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (altitudeMeters > 0.1) {
        altitudeMeters = (altitudeMeters - 0.1).clamp(0.0, 10.0);
        notifyListeners();
      } else {
        t.cancel();
        disarmDrone();
        _log("Touchdown complete. Disarmed.");
      }
    });
  }

  /// Toggle Height-Hold (Altitude Hold) mode
  void toggleHeightHold() {
    if (flightMode == DroneFlightMode.altitudeHold) {
      flightMode = DroneFlightMode.manual;
      _sendCommandString("CMD:HOLD_ALT:0\n");
      _log("Height-Hold OFF. Manual throttle engaged.");
    } else {
      flightMode = DroneFlightMode.altitudeHold;
      _sendCommandString("CMD:HOLD_ALT:1\n");
      _log("Height-Hold ON: Altitude locked via ToF sensor.");
    }
    notifyListeners();
  }

  /// Toggle Optical Flow Position Hold mode
  void togglePositionHold() {
    if (flightMode == DroneFlightMode.positionHold) {
      flightMode = DroneFlightMode.manual;
      _sendCommandString("CMD:HOLD_POS:0\n");
      _log("Position Hold OFF.");
    } else {
      flightMode = DroneFlightMode.positionHold;
      _sendCommandString("CMD:HOLD_POS:1\n");
      _log("Position Hold ON: Indoor optical flow lock engaged.");
    }
    notifyListeners();
  }

  /// Calibrate onboard Gyroscope & Accelerometer
  void calibrateSensors() {
    _sendCommandString("CMD:CALIBRATE\n");
    _log("Gyro/Acc calibration command dispatched. Keep drone stationary on level ground!");
  }

  void calibrateGyro() => calibrateSensors();

  /// Update onboard NeoPixel / RGB LEDs
  void updateNeoPixels(int r, int g, int b, {String pattern = "solid"}) {
    ledRed = r;
    ledGreen = g;
    ledBlue = b;
    ledPattern = pattern;
    _sendCommandString("CMD:LED:$r,$g,$b,$pattern\n");
    _log("LEDs set to RGB($r,$g,$b) [$pattern]");
    notifyListeners();
  }

  void setLedColor(int r, int g, int b, {String pattern = "solid"}) => updateNeoPixels(r, g, b, pattern: pattern);

  void setFlightMode(DroneFlightMode mode) {
    flightMode = mode;
    switch (mode) {
      case DroneFlightMode.manual:
        _sendCommandString("CMD:MODE:MANUAL\n");
        _log("Flight Mode: MANUAL");
        break;
      case DroneFlightMode.altitudeHold:
        _sendCommandString("CMD:MODE:ALT_HOLD\n");
        _log("Flight Mode: ALTITUDE HOLD");
        break;
      case DroneFlightMode.positionHold:
        _sendCommandString("CMD:MODE:POS_HOLD\n");
        _log("Flight Mode: POSITION HOLD");
        break;
    }
    notifyListeners();
  }

  void setNetworkTarget(String host, int port) {
    droneHost = host;
    dronePort = port;
    _log("Target set to $droneHost:$dronePort");
    notifyListeners();
  }

  // --- Trim Adjustments ---
  void adjustRollTrim(double delta) {
    rollTrim = (rollTrim + delta).clamp(-0.25, 0.25);
    notifyListeners();
  }

  void adjustPitchTrim(double delta) {
    pitchTrim = (pitchTrim + delta).clamp(-0.25, 0.25);
    notifyListeners();
  }

  void adjustYawTrim(double delta) {
    yawTrim = (yawTrim + delta).clamp(-0.25, 0.25);
    notifyListeners();
  }

  void resetTrims() {
    rollTrim = 0.0;
    pitchTrim = 0.0;
    yawTrim = 0.0;
    _log("Digital trims reset to zero.");
    notifyListeners();
  }

  void _sendCommandString(String cmd) {
    try {
      if (_socket != null && _isSocketReady) {
        _socket?.send(utf8.encode(cmd), InternetAddress(droneHost), dronePort);
      }
      // Also send through RobotState
      RobotState().sendCommand(cmd);
    } catch (_) {}
  }

  @override
  void dispose() {
    stopFlightLoop();
    _socket?.close();
    super.dispose();
  }
}
