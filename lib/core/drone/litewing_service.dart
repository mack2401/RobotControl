import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../state/robot_state.dart';
import '../wifi/wifi_service.dart';

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

/// Real-world Service managing flight control, 4-motor mixing, individual motor calibrations,
/// bench testing, and wireless communication for Circuit Digest LiteWing & ESP-Drone.
class LiteWingService extends ChangeNotifier {
  static final LiteWingService _instance = LiteWingService._internal();
  factory LiteWingService() => _instance;

  LiteWingService._internal() {
    _initSocket();
    loadCalibrationsFromStorage();
  }

  // --- Network & Communication Configuration ---
  String droneHost = "192.168.43.42"; // Default LiteWing AP IP (Alternative: 192.168.4.1)
  int dronePort = 2390;                // Default CRTP UDP port
  DroneProtocol protocol = DroneProtocol.crtpUdp;

  RawDatagramSocket? _socket;
  Timer? _flightLoopTimer;
  Timer? _rateCalculationTimer;
  bool _isSocketReady = false;

  // Real connection state (NOT based on transmitted packets!)
  bool isConnected = false;
  DateTime? lastPacketReceivedTime;
  int rxPacketRateHz = 0;
  int txPacketRateHz = 0;
  int _rxPacketsInWindow = 0;
  int _txPacketsInWindow = 0;
  int totalPacketsSent = 0;
  int totalPacketsReceived = 0;

  bool get isTelemetryAlive =>
      lastPacketReceivedTime != null &&
      DateTime.now().difference(lastPacketReceivedTime!).inSeconds < 4;

  // Backward compatible packetRateHz getter
  int get packetRateHz => txPacketRateHz;

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

  // ==========================================
  // REAL-WORLD 4-MOTOR CALIBRATION & HARDWARE ARCHITECTURE
  // ==========================================
  // Motor Layout (X-Configuration):
  // M1: Front-Left (FL)  - Clockwise (CW)        - Pin 4
  // M2: Front-Right (FR) - Counter-Clockwise (CCW)- Pin 5
  // M3: Rear-Left (RL)   - Counter-Clockwise (CCW)- Pin 6
  // M4: Rear-Right (RR)  - Clockwise (CW)        - Pin 7

  // Calibration Multipliers (0.70 to 1.30, nominal 1.00 -> 100%)
  // Allows micro-compensating for coreless motor coil & bearing variances
  double calibMotorFL = 1.00;
  double calibMotorFR = 1.00;
  double calibMotorRL = 1.00;
  double calibMotorRR = 1.00;

  // Individual Motor PWM Offsets (-100 to +100 PWM)
  int offsetMotorFL = 0;
  int offsetMotorFR = 0;
  int offsetMotorRL = 0;
  int offsetMotorRR = 0;

  // Minimum Idle Spin PWM (50 - 200 out of 1023, default 80 PWM ~ 7.8%)
  // Essential in real drones to prevent coreless motors stalling mid-air
  int minIdlePwm = 80;

  // Maximum Output PWM Cap (500 - 1023, default 1023)
  int maxOutputPwm = 1023;

  // Live Computed 4-Motor Outputs (0 - 1023 PWM)
  int motorFL_pwm = 0;
  int motorFR_pwm = 0;
  int motorRL_pwm = 0;
  int motorRR_pwm = 0;

  // Live 4-Motor Percentages (0.0 to 1.0)
  double motorFL_percent = 0.0;
  double motorFR_percent = 0.0;
  double motorRL_percent = 0.0;
  double motorRR_percent = 0.0;

  // Live Estimated Motor Speeds (0 to 28,000 RPM for 8520 coreless motors)
  int motorFL_rpm = 0;
  int motorFR_rpm = 0;
  int motorRL_rpm = 0;
  int motorRR_rpm = 0;

  // Motor Bench Test State (Safety Interlocked)
  bool isBenchTesting = false;
  int testMotorFL_pwm = 0;
  int testMotorFR_pwm = 0;
  int testMotorRL_pwm = 0;
  int testMotorRR_pwm = 0;

  // Telemetry & Feedback
  double batteryVoltage = 4.12; // Volts (1S LiPo: 3.2V to 4.2V)
  int batteryPercent = 95;
  double altitudeMeters = 0.0;
  double gyroRoll = 0.0;
  double gyroPitch = 0.0;
  double gyroYaw = 0.0;
  bool isCalibratingSensors = false;

  String lastStatusMessage = "Ready for pre-flight check";
  final List<String> consoleLogs = [];

  // NeoPixel / LED settings
  int ledRed = 0;
  int ledGreen = 200;
  int ledBlue = 255;
  String ledPattern = "solid";

  /// Initialize the UDP socket
  Future<void> _initSocket() async {
    try {
      _socket?.close();
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
      _startRateCalculator();
      _log("UDP Socket initialized on port ${_socket?.port}");
    } catch (e) {
      _isSocketReady = false;
      _log("UDP Socket Bind Error: $e");
    }
  }

  void _startRateCalculator() {
    _rateCalculationTimer?.cancel();
    _rateCalculationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      txPacketRateHz = _txPacketsInWindow;
      rxPacketRateHz = _rxPacketsInWindow;
      _txPacketsInWindow = 0;
      _rxPacketsInWindow = 0;
      notifyListeners();
    });
  }

  void _handleIncomingDatagram(Datagram datagram) {
    try {
      final data = datagram.data;
      if (data.isEmpty) return;

      lastPacketReceivedTime = DateTime.now();
      _rxPacketsInWindow++;
      totalPacketsReceived++;

      // Auto-mark connected if receiving valid packets from drone
      if (!isConnected) {
        isConnected = true;
        _syncGlobalRobotState(connected: true);
      }

      final header = data[0];
      final port = (header >> 4) & 0x0F;

      if (port == 0) {
        // CRTP Console packet
        final text = utf8.decode(data.sublist(1), allowMalformed: true).trim();
        if (text.isNotEmpty) {
          _log("[Drone] $text");
        }
      } else if (port == 5) {
        // CRTP Telemetry packet
        if (data.length >= 7) {
          final bd = ByteData.sublistView(data);
          final v = bd.getFloat32(1, Endian.little);
          if (v >= 2.5 && v <= 13.0) {
            batteryVoltage = v;
            batteryPercent = (((batteryVoltage - 3.2) / (4.2 - 3.2)) * 100).clamp(0, 100).toInt();
          }
          if (data.length >= 11) {
            altitudeMeters = bd.getFloat32(7, Endian.little);
          }
        }
      } else {
        // String / JSON Telemetry packet
        final text = utf8.decode(data, allowMalformed: true).trim();
        if (text.startsWith("{") && text.endsWith("}")) {
          final map = jsonDecode(text) as Map<String, dynamic>;
          if (map.containsKey("bat")) {
            batteryVoltage = (map["bat"] as num).toDouble();
            batteryPercent = (((batteryVoltage - 3.2) / (4.2 - 3.2)) * 100).clamp(0, 100).toInt();
          }
          if (map.containsKey("alt")) {
            altitudeMeters = (map["alt"] as num).toDouble();
          }
          if (map.containsKey("r")) gyroRoll = (map["r"] as num).toDouble();
          if (map.containsKey("p")) gyroPitch = (map["p"] as num).toDouble();
          if (map.containsKey("y")) gyroYaw = (map["y"] as num).toDouble();

          // Firmware reported motor PWMs
          if (map.containsKey("m") && map["m"] is List) {
            final mList = map["m"] as List;
            if (mList.length >= 4) {
              motorFL_pwm = (mList[0] as num).toInt();
              motorFR_pwm = (mList[1] as num).toInt();
              motorRL_pwm = (mList[2] as num).toInt();
              motorRR_pwm = (mList[3] as num).toInt();
            }
          }
        } else if (text.startsWith("PONG") || text.startsWith("OK")) {
          _log("[Drone ACK] $text");
        }
      }
      notifyListeners();
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

  // ==========================================
  // CONNECTION MANAGEMENT & GLOBAL SYNC
  // ==========================================

  /// Explicitly connect to LiteWing Drone via UDP and bind Android Wi-Fi
  Future<bool> connectDrone({String? host, int? port}) async {
    if (host != null && host.trim().isNotEmpty) {
      droneHost = host.trim();
    }
    if (port != null && port > 0) {
      dronePort = port;
    }

    _log("Connecting to LiteWing Drone ($droneHost:$dronePort)...");

    // 1. Force Android system to bind sockets to Wi-Fi adapter
    try {
      await RealWifiService().bindProcessToWifi();
    } catch (_) {}

    // 2. Ensure UDP socket is ready
    if (_socket == null || !_isSocketReady) {
      await _initSocket();
    }

    // 3. Mark connected and start high-frequency flight loop
    isConnected = true;
    startFlightLoop();

    // 4. Send ping & sync 4-motor calibrations
    sendPing();
    sendMotorCalibrationToDrone();

    // 5. Synchronize with global RobotState so Dashboard & other screens know LiteWing is connected!
    _syncGlobalRobotState(connected: true);

    _log("LiteWing Drone linked on $droneHost:$dronePort");
    notifyListeners();
    return true;
  }

  /// Explicitly disconnect from LiteWing Drone
  Future<void> disconnectDrone() async {
    if (isArmed) {
      disarmDrone();
    }
    stopFlightLoop();
    isConnected = false;
    rxPacketRateHz = 0;
    txPacketRateHz = 0;

    _syncGlobalRobotState(connected: false);

    _log("Disconnected from LiteWing Drone.");
    notifyListeners();
  }

  void _syncGlobalRobotState({required bool connected}) {
    final state = RobotState();
    if (connected) {
      final dev = RoboticDevice(
        id: "litewing-${droneHost.replaceAll('.', '-')}",
        name: "LiteWing Drone",
        macAddress: "UDP: $droneHost:$dronePort",
        ipAddress: droneHost,
        protocol: "Wi-Fi (UDP $dronePort)",
        rssi: -38,
        isConnected: true,
        pingMs: 12,
        deviceType: "Rover",
      );
      state.selectTargetDevice(dev);
      state.connectionStatus = ConnectionStatus.connected;
      state.currentDevice = dev;
      state.addTerminalLog("[LiteWing] Linked to $droneHost:$dronePort (CRTP UDP)", LogType.system);
    } else {
      if (state.currentDevice.name.contains("LiteWing") || state.currentDevice.protocol.contains("UDP")) {
        state.connectionStatus = ConnectionStatus.disconnected;
        state.currentDevice = state.currentDevice.copyWith(isConnected: false);
        state.addTerminalLog("[LiteWing] Disconnected from drone link.", LogType.system);
      }
    }
    state.notifyListeners();
  }

  /// Send a ping packet to test drone reachability
  void sendPing() {
    _sendCommandString("CMD:PING\n");
    // Also dispatch CRTP ping
    if (_socket != null && _isSocketReady) {
      try {
        final pingBytes = Uint8List.fromList([0x00, 0x01, 0x50, 0x49, 0x4E, 0x47]); // Port 0 ping
        _socket?.send(pingBytes, InternetAddress(droneHost), dronePort);
      } catch (_) {}
    }
  }

  // ==========================================
  // FLIGHT TRANSMISSION & 4-MOTOR MIXING
  // ==========================================

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
    _computeMotorOutputs();
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
    _computeMotorOutputs();
    notifyListeners();
  }

  double _applyExpo(double input) {
    if (input.abs() < deadzone) return 0.0;
    return input * (1.0 - sensitivityExpo) + (input * input * input) * sensitivityExpo;
  }

  /// Real-world 4-Motor Mixing Algorithm applying individual calibrations & trims
  void _computeMotorOutputs() {
    if (isBenchTesting) {
      motorFL_pwm = testMotorFL_pwm;
      motorFR_pwm = testMotorFR_pwm;
      motorRL_pwm = testMotorRL_pwm;
      motorRR_pwm = testMotorRR_pwm;
    } else if (armState == DroneArmState.armed) {
      // 1. Base thrust mapped to 0 - 1023 (10-bit PWM)
      final double effectiveThrust = (thrustInput * (maxThrustPercent / 100.0)).clamp(0.0, 1.0);
      final int basePwm = (effectiveThrust * 1023).round();

      // 2. Flight dynamics mixing from Roll, Pitch, Yaw
      final double netRoll = (rollInput + rollTrim).clamp(-1.0, 1.0);
      final double netPitch = (pitchInput + pitchTrim).clamp(-1.0, 1.0);
      final double netYaw = (yawInput + yawTrim).clamp(-1.0, 1.0);

      final double rAdj = netRoll * 250.0;
      final double pAdj = netPitch * 250.0;
      final double yAdj = netYaw * 160.0;

      if (basePwm > 20) {
        // LiteWing X-Quad Mixing Formula:
        // FL (CW):  base - pitch + roll + yaw
        // FR (CCW): base - pitch - roll - yaw
        // RL (CCW): base + pitch + roll - yaw
        // RR (CW):  base + pitch - roll + yaw
        final double rawFL = basePwm - pAdj + rAdj + yAdj;
        final double rawFR = basePwm - pAdj - rAdj - yAdj;
        final double rawRL = basePwm + pAdj + rAdj - yAdj;
        final double rawRR = basePwm + pAdj - rAdj + yAdj;

        // 3. Apply individual 4-motor calibration multipliers & offsets:
        int fl = ((rawFL * calibMotorFL) + offsetMotorFL).round();
        int fr = ((rawFR * calibMotorFR) + offsetMotorFR).round();
        int rl = ((rawRL * calibMotorRL) + offsetMotorRL).round();
        int rr = ((rawRR * calibMotorRR) + offsetMotorRR).round();

        // 4. Clamp within idle spin threshold and maximum PWM
        motorFL_pwm = math.max(fl, minIdlePwm).clamp(0, maxOutputPwm);
        motorFR_pwm = math.max(fr, minIdlePwm).clamp(0, maxOutputPwm);
        motorRL_pwm = math.max(rl, minIdlePwm).clamp(0, maxOutputPwm);
        motorRR_pwm = math.max(rr, minIdlePwm).clamp(0, maxOutputPwm);
      } else {
        // Idle spin on ground when armed at 0 throttle
        motorFL_pwm = minIdlePwm;
        motorFR_pwm = minIdlePwm;
        motorRL_pwm = minIdlePwm;
        motorRR_pwm = minIdlePwm;
      }
    } else {
      // Disarmed - Motors 0
      motorFL_pwm = 0;
      motorFR_pwm = 0;
      motorRL_pwm = 0;
      motorRR_pwm = 0;
    }

    // Compute live percentages & RPM estimation
    motorFL_percent = (motorFL_pwm / 1023.0).clamp(0.0, 1.0);
    motorFR_percent = (motorFR_pwm / 1023.0).clamp(0.0, 1.0);
    motorRL_percent = (motorRL_pwm / 1023.0).clamp(0.0, 1.0);
    motorRR_percent = (motorRR_pwm / 1023.0).clamp(0.0, 1.0);

    motorFL_rpm = (motorFL_percent * 28000).round();
    motorFR_rpm = (motorFR_percent * 28000).round();
    motorRL_rpm = (motorRL_percent * 28000).round();
    motorRR_rpm = (motorRR_percent * 28000).round();
  }

  /// Sends the current commander flight frame to the aircraft
  void _sendFlightControlFrame() {
    _computeMotorOutputs();

    if (armState != DroneArmState.armed && !isBenchTesting) {
      _dispatchCommander(0.0, 0.0, 0.0, 0);
      return;
    }

    // Apply digital trims
    final double netRoll = (rollInput + rollTrim).clamp(-1.0, 1.0);
    final double netPitch = (pitchInput + pitchTrim).clamp(-1.0, 1.0);
    final double netYaw = (yawInput + yawTrim).clamp(-1.0, 1.0);
    final double effectiveThrust = (thrustInput * (maxThrustPercent / 100.0)).clamp(0.0, 1.0);

    final double rollDeg = netRoll * 30.0;
    final double pitchDeg = netPitch * 30.0;
    final double yawRateDegSec = netYaw * 200.0;
    final int rawThrust = (effectiveThrust * 65535).round().clamp(0, 65535);

    // Realistic altitude model
    if (effectiveThrust > 0.48) {
      altitudeMeters = (altitudeMeters + (effectiveThrust - 0.5) * 0.06).clamp(0.0, 20.0);
    } else if (altitudeMeters > 0.05) {
      altitudeMeters = (altitudeMeters - 0.08).clamp(0.0, 20.0);
    } else {
      altitudeMeters = 0.0;
    }

    // Send frame to drone
    _dispatchCommander(rollDeg, pitchDeg, yawRateDegSec, rawThrust);

    _txPacketsInWindow++;
    totalPacketsSent++;
  }

  void _dispatchCommander(double rollDeg, double pitchDeg, double yawRate, int thrust) {
    if (!isConnected) return; // Only transmit over network when linked!

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
    if (_socket == null || !_isSocketReady) return;
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

  /// Sends human-readable ASCII string over UDP: `SET:roll,pitch,yaw,thrust,mFL,mFR,mRL,mRR\n`
  void _sendAsciiCommander(double roll, double pitch, double yawRate, int thrust) {
    if (_socket == null || !_isSocketReady) return;
    try {
      final msg = "SET:${roll.toStringAsFixed(1)},${pitch.toStringAsFixed(1)},${yawRate.toStringAsFixed(1)},$thrust,$motorFL_pwm,$motorFR_pwm,$motorRL_pwm,$motorRR_pwm\n";
      final bytes = utf8.encode(msg);
      _socket?.send(bytes, InternetAddress(droneHost), dronePort);
    } catch (_) {}
  }

  /// Sends JSON packet with both commander inputs and calibrated motor PWMs
  void _sendJsonCommander(double roll, double pitch, double yawRate, int thrust) {
    if (_socket == null || !_isSocketReady) return;
    try {
      final jsonStr = jsonEncode({
        "r": double.parse(roll.toStringAsFixed(1)),
        "p": double.parse(pitch.toStringAsFixed(1)),
        "y": double.parse(yawRate.toStringAsFixed(1)),
        "t": thrust,
        "arm": isArmed ? 1 : 0,
        "m": [motorFL_pwm, motorFR_pwm, motorRL_pwm, motorRR_pwm],
      });
      _socket?.send(utf8.encode("$jsonStr\n"), InternetAddress(droneHost), dronePort);
    } catch (_) {}
  }

  /// Sends commander inputs through RobotState active connection
  void _sendHybridStateCommander(double roll, double pitch, double yawRate, int thrust) {
    final state = RobotState();
    final cmd = "DRONE:${roll.toInt()},${pitch.toInt()},${yawRate.toInt()},$thrust,$motorFL_pwm,$motorFR_pwm,$motorRL_pwm,$motorRR_pwm\n";
    state.sendCommand(cmd);
  }

  // ==========================================
  // 4-MOTOR CALIBRATION & BENCH TESTING METHODS
  // ==========================================

  /// Update individual motor calibration multipliers (0.70 to 1.30)
  void setMotorCalibration({
    double? fl,
    double? fr,
    double? rl,
    double? rr,
    int? idle,
    int? maxPwm,
  }) {
    if (fl != null) calibMotorFL = fl.clamp(0.70, 1.30);
    if (fr != null) calibMotorFR = fr.clamp(0.70, 1.30);
    if (rl != null) calibMotorRL = rl.clamp(0.70, 1.30);
    if (rr != null) calibMotorRR = rr.clamp(0.70, 1.30);
    if (idle != null) minIdlePwm = idle.clamp(40, 250);
    if (maxPwm != null) maxOutputPwm = maxPwm.clamp(500, 1023);

    _computeMotorOutputs();
    sendMotorCalibrationToDrone();
    saveCalibrationsToStorage();
    notifyListeners();
  }

  /// Update individual motor PWM offsets (-100 to +100 PWM)
  void setMotorOffset({
    int? fl,
    int? fr,
    int? rl,
    int? rr,
  }) {
    if (fl != null) offsetMotorFL = fl.clamp(-100, 100);
    if (fr != null) offsetMotorFR = fr.clamp(-100, 100);
    if (rl != null) offsetMotorRL = rl.clamp(-100, 100);
    if (rr != null) offsetMotorRR = rr.clamp(-100, 100);

    _computeMotorOutputs();
    sendMotorCalibrationToDrone();
    saveCalibrationsToStorage();
    notifyListeners();
  }

  /// Reset all 4 motor calibrations and offsets to factory nominal (1.00x, 0 offset)
  void resetMotorCalibrations() {
    calibMotorFL = 1.00;
    calibMotorFR = 1.00;
    calibMotorRL = 1.00;
    calibMotorRR = 1.00;
    offsetMotorFL = 0;
    offsetMotorFR = 0;
    offsetMotorRL = 0;
    offsetMotorRR = 0;
    minIdlePwm = 80;
    maxOutputPwm = 1023;

    _computeMotorOutputs();
    sendMotorCalibrationToDrone();
    saveCalibrationsToStorage();
    _log("4-Motor Calibrations reset to nominal 100%.");
    notifyListeners();
  }

  /// Dispatch calibration command to firmware over UDP:
  /// `CMD:MOTOR_CAL:<fl_pct>,<fr_pct>,<rl_pct>,<rr_pct>,<min_idle>,<max_pwm>\n`
  void sendMotorCalibrationToDrone() {
    final flPct = (calibMotorFL * 100).round();
    final frPct = (calibMotorFR * 100).round();
    final rlPct = (calibMotorRL * 100).round();
    final rrPct = (calibMotorRR * 100).round();

    final cmd = "CMD:MOTOR_CAL:$flPct,$frPct,$rlPct,$rrPct,$minIdlePwm,$maxOutputPwm\n";
    _sendCommandString(cmd);
    _log("Dispatched 4-motor calibration to drone [$flPct%, $frPct%, $rlPct%, $rrPct%]");
  }

  /// Interactive drift compensation assistant (e.g. drone drifts Forward -> decrease rear / increase front)
  void adjustForDrift(String direction) {
    const double delta = 0.02; // 2% nudge
    switch (direction.toLowerCase()) {
      case "forward":
        // Drifting forward: Front motors are too strong, or Rear are too weak. Increase Rear, decrease Front.
        calibMotorFL = (calibMotorFL - delta).clamp(0.70, 1.30);
        calibMotorFR = (calibMotorFR - delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL + delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR + delta).clamp(0.70, 1.30);
        _log("Drift trim: Boosted rear motors +2%, lowered front -2%");
        break;
      case "backward":
        calibMotorFL = (calibMotorFL + delta).clamp(0.70, 1.30);
        calibMotorFR = (calibMotorFR + delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL - delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR - delta).clamp(0.70, 1.30);
        _log("Drift trim: Boosted front motors +2%, lowered rear -2%");
        break;
      case "left":
        // Drifting left: Right motors are too strong, or Left are too weak. Increase Left.
        calibMotorFL = (calibMotorFL + delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL + delta).clamp(0.70, 1.30);
        calibMotorFR = (calibMotorFR - delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR - delta).clamp(0.70, 1.30);
        _log("Drift trim: Boosted left motors +2%, lowered right -2%");
        break;
      case "right":
        calibMotorFL = (calibMotorFL - delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL - delta).clamp(0.70, 1.30);
        calibMotorFR = (calibMotorFR + delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR + delta).clamp(0.70, 1.30);
        _log("Drift trim: Boosted right motors +2%, lowered left -2%");
        break;
      case "cw":
        // Yawing clockwise: CCW motors (FR, RL) too weak, or CW (FL, RR) too strong
        calibMotorFR = (calibMotorFR + delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL + delta).clamp(0.70, 1.30);
        calibMotorFL = (calibMotorFL - delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR - delta).clamp(0.70, 1.30);
        _log("Drift trim: Countered CW yaw spin");
        break;
      case "ccw":
        calibMotorFL = (calibMotorFL + delta).clamp(0.70, 1.30);
        calibMotorRR = (calibMotorRR + delta).clamp(0.70, 1.30);
        calibMotorFR = (calibMotorFR - delta).clamp(0.70, 1.30);
        calibMotorRL = (calibMotorRL - delta).clamp(0.70, 1.30);
        _log("Drift trim: Countered CCW yaw spin");
        break;
    }
    _computeMotorOutputs();
    sendMotorCalibrationToDrone();
    saveCalibrationsToStorage();
    notifyListeners();
  }

  /// Run bench test on individual motors (0 = All, 1 = FL, 2 = FR, 3 = RL, 4 = RR)
  void testMotor(int motorIndex, int pwm) {
    isBenchTesting = true;
    final clampedPwm = pwm.clamp(0, maxOutputPwm);

    if (motorIndex == 0) {
      testMotorFL_pwm = clampedPwm;
      testMotorFR_pwm = clampedPwm;
      testMotorRL_pwm = clampedPwm;
      testMotorRR_pwm = clampedPwm;
    } else if (motorIndex == 1) {
      testMotorFL_pwm = clampedPwm;
    } else if (motorIndex == 2) {
      testMotorFR_pwm = clampedPwm;
    } else if (motorIndex == 3) {
      testMotorRL_pwm = clampedPwm;
    } else if (motorIndex == 4) {
      testMotorRR_pwm = clampedPwm;
    }

    _computeMotorOutputs();

    // Transmit motor test frame to firmware: `CMD:MOTOR_TEST:<mIndex>,<pwm>\n`
    _sendCommandString("CMD:MOTOR_TEST:$motorIndex,$clampedPwm\n");
    notifyListeners();
  }

  /// Stop bench testing and cut all motors immediately
  void stopMotorTest() {
    isBenchTesting = false;
    testMotorFL_pwm = 0;
    testMotorFR_pwm = 0;
    testMotorRL_pwm = 0;
    testMotorRR_pwm = 0;
    _computeMotorOutputs();
    _sendCommandString("CMD:MOTOR_TEST:0,0\n");
    _log("Motor bench test halted. All motors cut.");
    notifyListeners();
  }

  // ==========================================
  // PERSISTENCE (LOCAL STORAGE)
  // ==========================================

  File _getConfigFile() {
    final tempDir = Directory.systemTemp;
    return File('${tempDir.path}/litewing_motor_calib.json');
  }

  Future<void> saveCalibrationsToStorage() async {
    try {
      final file = _getConfigFile();
      final map = {
        "calibFL": calibMotorFL,
        "calibFR": calibMotorFR,
        "calibRL": calibMotorRL,
        "calibRR": calibMotorRR,
        "offsetFL": offsetMotorFL,
        "offsetFR": offsetMotorFR,
        "offsetRL": offsetMotorRL,
        "offsetRR": offsetMotorRR,
        "minIdlePwm": minIdlePwm,
        "maxOutputPwm": maxOutputPwm,
        "sensitivityExpo": sensitivityExpo,
        "maxThrustPercent": maxThrustPercent,
        "droneHost": droneHost,
        "dronePort": dronePort,
      };
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  Future<void> loadCalibrationsFromStorage() async {
    try {
      final file = _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map.containsKey("calibFL")) calibMotorFL = (map["calibFL"] as num).toDouble();
        if (map.containsKey("calibFR")) calibMotorFR = (map["calibFR"] as num).toDouble();
        if (map.containsKey("calibRL")) calibMotorRL = (map["calibRL"] as num).toDouble();
        if (map.containsKey("calibRR")) calibMotorRR = (map["calibRR"] as num).toDouble();
        if (map.containsKey("offsetFL")) offsetMotorFL = (map["offsetFL"] as num).toInt();
        if (map.containsKey("offsetFR")) offsetMotorFR = (map["offsetFR"] as num).toInt();
        if (map.containsKey("offsetRL")) offsetMotorRL = (map["offsetRL"] as num).toInt();
        if (map.containsKey("offsetRR")) offsetMotorRR = (map["offsetRR"] as num).toInt();
        if (map.containsKey("minIdlePwm")) minIdlePwm = (map["minIdlePwm"] as num).toInt();
        if (map.containsKey("maxOutputPwm")) maxOutputPwm = (map["maxOutputPwm"] as num).toInt();
        if (map.containsKey("sensitivityExpo")) sensitivityExpo = (map["sensitivityExpo"] as num).toDouble();
        if (map.containsKey("maxThrustPercent")) maxThrustPercent = (map["maxThrustPercent"] as num).toDouble();
        if (map.containsKey("droneHost")) droneHost = map["droneHost"] as String;
        if (map.containsKey("dronePort")) dronePort = (map["dronePort"] as num).toInt();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ==========================================
  // HIGH-LEVEL FLIGHT ACTIONS
  // ==========================================

  /// Arm the drone motors (verifies safety checks)
  Future<void> armDrone() async {
    armState = DroneArmState.arming;
    notifyListeners();
    _log("Arming pre-flight sequence initiated...");

    _sendCommandString("CMD:ARM\n");
    _dispatchCommander(0.0, 0.0, 0.0, 0);

    await Future.delayed(const Duration(milliseconds: 300));
    armState = DroneArmState.armed;
    _computeMotorOutputs();
    _log("MOTORS ARMED! Controls active.");
    notifyListeners();
  }

  void arm() => armDrone();

  /// Disarm drone motors
  void disarmDrone() {
    armState = DroneArmState.disarmed;
    thrustInput = 0.0;
    _computeMotorOutputs();
    _dispatchCommander(0.0, 0.0, 0.0, 0);
    _sendCommandString("CMD:DISARM\n");
    _log("Drone DISARMED. Motors shut down.");
    notifyListeners();
  }

  void disarm() => disarmDrone();

  /// EMERGENCY STOP - Instant motor kill
  void emergencyStop() {
    armState = DroneArmState.disarmed;
    isBenchTesting = false;
    thrustInput = 0.0;
    rollInput = 0.0;
    pitchInput = 0.0;
    yawInput = 0.0;
    _computeMotorOutputs();

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
    thrustInput = 0.58;
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
  Future<void> calibrateSensors() async {
    isCalibratingSensors = true;
    notifyListeners();
    _sendCommandString("CMD:CALIBRATE\n");
    _log("Calibrating 6-Axis Gyro/Acc... Keep drone completely stationary on level surface!");

    await Future.delayed(const Duration(seconds: 3));
    isCalibratingSensors = false;
    gyroRoll = 0.0;
    gyroPitch = 0.0;
    _log("Gyro/Acc Calibration complete! Zero level offsets stored.");
    notifyListeners();
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

  void setLedColor(int r, int g, int b, {String pattern = "solid"}) =>
      updateNeoPixels(r, g, b, pattern: pattern);

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
    saveCalibrationsToStorage();
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
      if (_socket != null && _isSocketReady && isConnected) {
        _socket?.send(utf8.encode(cmd), InternetAddress(droneHost), dronePort);
      }
      RobotState().sendCommand(cmd);
    } catch (_) {}
  }

  @override
  void dispose() {
    stopFlightLoop();
    _rateCalculationTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
