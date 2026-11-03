// SQLite + Drift Database Abstraction for iBots Remote Controller
// Defines the schema for persistent robotic device profiles matching Drift ORM.

import 'dart:async';
import '../models/device_model.dart';

/// Representation of a stored device profile in SQLite/Drift
class DeviceProfile {
  final String id;
  final String name;
  final String macAddress;
  final String ipAddress;
  final String protocol; // "Bluetooth (Classic)", "BLE 5.2", "Wi-Fi AP"
  final String deviceType; // "Rover", "Gamepad", "Cam", "Arm", "Relay"
  final DateTime lastConnected;
  final int rssi;
  final bool isPaired;
  final bool autoConnect;

  const DeviceProfile({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.ipAddress,
    required this.protocol,
    required this.deviceType,
    required this.lastConnected,
    this.rssi = -55,
    this.isPaired = true,
    this.autoConnect = false,
  });

  RoboticDevice toRoboticDevice({bool isConnected = false}) {
    return RoboticDevice(
      id: id,
      name: name,
      macAddress: macAddress,
      ipAddress: ipAddress,
      protocol: protocol,
      rssi: rssi,
      isConnected: isConnected,
      deviceType: deviceType,
    );
  }

  bool get isRobotDevice => toRoboticDevice().isRobotDevice;

  factory DeviceProfile.fromRoboticDevice(RoboticDevice device) {
    return DeviceProfile(
      id: device.id,
      name: device.name,
      macAddress: device.macAddress,
      ipAddress: device.ipAddress,
      protocol: device.protocol,
      deviceType: device.deviceType,
      lastConnected: DateTime.now(),
      rssi: device.rssi,
      isPaired: true,
    );
  }

  DeviceProfile copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? ipAddress,
    String? protocol,
    String? deviceType,
    DateTime? lastConnected,
    int? rssi,
    bool? isPaired,
    bool? autoConnect,
  }) {
    return DeviceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      protocol: protocol ?? this.protocol,
      deviceType: deviceType ?? this.deviceType,
      lastConnected: lastConnected ?? this.lastConnected,
      rssi: rssi ?? this.rssi,
      isPaired: isPaired ?? this.isPaired,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }
}

/// Drift Table Definition Reference:
/// ```dart
/// class DeviceProfilesTable extends Table {
///   TextColumn get id => text()();
///   TextColumn get name => text().withLength(min: 1, max: 64)();
///   TextColumn get macAddress => text().withLength(min: 12, max: 20)();
///   TextColumn get ipAddress => text().nullable()();
///   TextColumn get protocol => text()();
///   TextColumn get deviceType => text()();
///   DateTimeColumn get lastConnected => dateTime()();
///   IntColumn get rssi => integer().withDefault(const Constant(-60))();
///   BoolColumn get isPaired => boolean().withDefault(const Constant(true))();
///   BoolColumn get autoConnect => boolean().withDefault(const Constant(false))();
///   @override
///   Set<Column> get primaryKey => {id};
/// }
/// ```

class DeviceProfileDatabase {
  static final DeviceProfileDatabase _instance = DeviceProfileDatabase._internal();
  factory DeviceProfileDatabase() => _instance;

  DeviceProfileDatabase._internal();

  final List<DeviceProfile> _profiles = [];

  Future<List<DeviceProfile>> getAllProfiles() async {
    return List.unmodifiable(_profiles);
  }

  Future<List<DeviceProfile>> getProfilesForProtocol(String protocol) async {
    final cleanProto = protocol.toLowerCase();
    if (cleanProto.contains("classic")) {
      return _profiles.where((p) => p.protocol.toLowerCase().contains("classic")).toList();
    } else if (cleanProto.contains("ble")) {
      return _profiles.where((p) => p.protocol.toLowerCase().contains("ble")).toList();
    } else if (cleanProto.contains("wi-fi") || cleanProto.contains("wifi")) {
      return _profiles.where((p) => p.protocol.toLowerCase().contains("wi-fi") || p.protocol.toLowerCase().contains("wifi")).toList();
    }
    return _profiles.where((p) => p.protocol == protocol).toList();
  }

  Future<void> saveProfile(DeviceProfile profile) async {
    final index = _profiles.indexWhere((p) =>
        p.id == profile.id ||
        (profile.macAddress.isNotEmpty &&
            profile.macAddress != "00:00:00:00:00:00" &&
            p.macAddress.toLowerCase() == profile.macAddress.toLowerCase()) ||
        (p.name.toLowerCase() == profile.name.toLowerCase() && p.protocol == profile.protocol));
    if (index >= 0) {
      _profiles[index] = profile;
    } else {
      _profiles.insert(0, profile);
    }
  }

  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
  }

  Future<void> updateLastConnected(String id) async {
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _profiles[index] = _profiles[index].copyWith(lastConnected: DateTime.now());
    }
  }
}
