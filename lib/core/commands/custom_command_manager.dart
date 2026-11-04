import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum CarPresetMode {
  singleChar,
  words,
  numeric,
  endpoints,
}

/// Centralized manager for default presets and per-button custom command overrides
/// across all controller features in the iBots Remote application.
/// Ensures complete independence between features (Car, Gyro, Gamepad, Switch, Keypad).
class CustomCommandManager extends ChangeNotifier {
  static final CustomCommandManager _instance = CustomCommandManager._internal();
  factory CustomCommandManager() => _instance;

  CustomCommandManager._internal() {
    _loadFromDisk();
  }

  // ==========================================
  // SHARED PRESET DEFINITIONS
  // ==========================================
  static const Map<String, String> standardPreset = {
    'FORWARD': 'F',
    'BACKWARD': 'B',
    'LEFT': 'L',
    'RIGHT': 'R',
    'STOP': 'S',
    'HORN': 'HORN',
    'LIGHTS_ON': '1',
    'LIGHTS_OFF': '0',
    'DANCE': 'DANCE',
  };

  static const Map<String, String> wordPreset = {
    'FORWARD': 'FORWARD',
    'BACKWARD': 'BACKWARD',
    'LEFT': 'LEFT',
    'RIGHT': 'RIGHT',
    'STOP': 'STOP',
    'HORN': 'HORN',
    'LIGHTS_ON': 'LIGHT_ON',
    'LIGHTS_OFF': 'LIGHT_OFF',
    'DANCE': 'DANCE',
  };

  static const Map<String, String> numericPreset = {
    'FORWARD': '1',
    'BACKWARD': '2',
    'LEFT': '3',
    'RIGHT': '4',
    'STOP': '0',
    'HORN': 'H',
    'LIGHTS_ON': '1',
    'LIGHTS_OFF': '0',
    'DANCE': '5',
  };

  static const Map<String, String> endpointPreset = {
    'FORWARD': '/forward',
    'BACKWARD': '/backward',
    'LEFT': '/left',
    'RIGHT': '/right',
    'STOP': '/stop',
    'HORN': '/horn',
    'LIGHTS_ON': '/light_on',
    'LIGHTS_OFF': '/light_off',
    'DANCE': '/dance',
  };

  // Backwards compatibility aliases
  static const Map<String, String> carStandardPreset = standardPreset;
  static const Map<String, String> carWordPreset = wordPreset;
  static const Map<String, String> carNumericPreset = numericPreset;
  static const Map<String, String> carEndpointPreset = endpointPreset;

  // ==========================================
  // 1. CAR CONTROLLER (Isolated Feature)
  // ==========================================
  int carPresetMode = 0; // Default Standard
  CarPresetMode get carPresetModeEnum => CarPresetMode.values[carPresetMode.clamp(0, CarPresetMode.values.length - 1)];

  final Map<String, String> _carCustomOverrides = {};

  String getCarPresetName(int mode) {
    switch (mode) {
      case 1:
        return 'Words (FORWARD/BACKWARD/STOP)';
      case 2:
        return 'Numeric (1/2/3/4/0)';
      case 3:
        return 'HTTP Endpoints (/forward...)';
      case 0:
      default:
        return 'Standard (F/B/L/R/S)';
    }
  }

  /// Returns the true default preset command for Car Controller, unaffected by any custom override.
  String getCarDefaultCommand(String key) {
    final upperKey = key.toUpperCase();
    switch (carPresetMode) {
      case 1:
        return wordPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 2:
        return numericPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 3:
        return endpointPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 0:
      default:
        return standardPreset[upperKey] ?? upperKey;
    }
  }

  /// Returns the active command: custom override if configured, otherwise the true default command.
  String getCarCommand(String key) {
    final upperKey = key.toUpperCase();
    if (_carCustomOverrides.containsKey(upperKey) && _carCustomOverrides[upperKey]!.trim().isNotEmpty) {
      return _carCustomOverrides[upperKey]!.trim();
    }
    return getCarDefaultCommand(upperKey);
  }

  String? getCarCustomOverride(String key) {
    return _carCustomOverrides[key.toUpperCase()];
  }

  bool isCarCommandCustomized(String key) {
    final upperKey = key.toUpperCase();
    return _carCustomOverrides.containsKey(upperKey) && _carCustomOverrides[upperKey]!.trim().isNotEmpty;
  }

  bool get hasCarOverrides => _carCustomOverrides.isNotEmpty || carPresetMode != 0;

  void setCarCommand(String key, String? customValue) {
    final upperKey = key.toUpperCase();
    if (customValue == null || customValue.trim().isEmpty) {
      _carCustomOverrides.remove(upperKey);
    } else {
      _carCustomOverrides[upperKey] = customValue.trim();
    }
    _saveToDisk();
    notifyListeners();
  }

  void setCarCustomOverride(String key, String? customValue) => setCarCommand(key, customValue);
  void resetCarCommand(String key) => setCarCommand(key, null);
  void resetAllCarOverrides() => resetCarCommands();

  void setCarPresetMode(dynamic mode) {
    if (mode is CarPresetMode) {
      carPresetMode = mode.index;
    } else if (mode is int) {
      carPresetMode = mode;
    }
    _saveToDisk();
    notifyListeners();
  }

  void resetCarCommands() {
    _carCustomOverrides.clear();
    carPresetMode = 0;
    _saveToDisk();
    notifyListeners();
  }

  // ==========================================
  // 2. GYRO CONTROL (Isolated Feature)
  // ==========================================
  int gyroPresetMode = 0; // Default Standard
  CarPresetMode get gyroPresetModeEnum => CarPresetMode.values[gyroPresetMode.clamp(0, CarPresetMode.values.length - 1)];

  final Map<String, String> _gyroCustomOverrides = {};

  String getGyroPresetName(int mode) {
    switch (mode) {
      case 1:
        return 'Words (FORWARD/BACKWARD/STOP)';
      case 2:
        return 'Numeric (1/2/3/4/0)';
      case 3:
        return 'HTTP Endpoints (/forward...)';
      case 0:
      default:
        return 'Standard (F/B/L/R/S)';
    }
  }

  /// Returns the true default preset command for Gyro Control, unaffected by any custom override.
  String getGyroDefaultCommand(String key) {
    final upperKey = key.toUpperCase();
    switch (gyroPresetMode) {
      case 1:
        return wordPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 2:
        return numericPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 3:
        return endpointPreset[upperKey] ?? standardPreset[upperKey] ?? upperKey;
      case 0:
      default:
        return standardPreset[upperKey] ?? upperKey;
    }
  }

  /// Returns the active command: custom override if configured, otherwise the true default command.
  String getGyroCommand(String key) {
    final upperKey = key.toUpperCase();
    if (_gyroCustomOverrides.containsKey(upperKey) && _gyroCustomOverrides[upperKey]!.trim().isNotEmpty) {
      return _gyroCustomOverrides[upperKey]!.trim();
    }
    return getGyroDefaultCommand(upperKey);
  }

  String? getGyroCustomOverride(String key) {
    return _gyroCustomOverrides[key.toUpperCase()];
  }

  bool isGyroCommandCustomized(String key) {
    final upperKey = key.toUpperCase();
    return _gyroCustomOverrides.containsKey(upperKey) && _gyroCustomOverrides[upperKey]!.trim().isNotEmpty;
  }

  bool get hasGyroOverrides => _gyroCustomOverrides.isNotEmpty || gyroPresetMode != 0;

  void setGyroCommand(String key, String? customValue) {
    final upperKey = key.toUpperCase();
    if (customValue == null || customValue.trim().isEmpty) {
      _gyroCustomOverrides.remove(upperKey);
    } else {
      _gyroCustomOverrides[upperKey] = customValue.trim();
    }
    _saveToDisk();
    notifyListeners();
  }

  void setGyroCustomOverride(String key, String? customValue) => setGyroCommand(key, customValue);
  void resetGyroCommand(String key) => setGyroCommand(key, null);
  void resetAllGyroOverrides() => resetGyroCommands();

  void setGyroPresetMode(dynamic mode) {
    if (mode is CarPresetMode) {
      gyroPresetMode = mode.index;
    } else if (mode is int) {
      gyroPresetMode = mode;
    }
    _saveToDisk();
    notifyListeners();
  }

  void resetGyroCommands() {
    _gyroCustomOverrides.clear();
    gyroPresetMode = 0;
    _saveToDisk();
    notifyListeners();
  }

  // ==========================================
  // 3. GAMEPAD CONTROLLER (Isolated Feature)
  // ==========================================
  static const Map<String, String> gamepadDefaultCommands = {
    'UP': 'F',
    'DOWN': 'B',
    'LEFT': 'L',
    'RIGHT': 'R',
    'STOP': 'S',
    'TRIANGLE': 'Y',
    'CROSS': 'A',
    'SQUARE': 'X',
    'CIRCLE': 'B',
    'X': 'X',
    'Y': 'Y',
    'A': 'A',
    'B': 'B',
    'L1': 'L1',
    'R1': 'R1',
    'L2': 'L2',
    'R2': 'R2',
    'START': 'START',
    'SELECT': 'SELECT',
    'PAUSE': 'PAUSE',
  };

  final Map<String, String> _gamepadCustomOverrides = {};

  /// Returns the true default command for Gamepad, unaffected by custom overrides or Car Controller.
  String getGamepadDefaultCommand(String key) {
    final upperKey = key.toUpperCase();
    return gamepadDefaultCommands[upperKey] ?? upperKey;
  }

  /// Returns the active command: custom override if configured, otherwise the true Gamepad default.
  String getGamepadCommand(String key) {
    final upperKey = key.toUpperCase();
    if (_gamepadCustomOverrides.containsKey(upperKey) && _gamepadCustomOverrides[upperKey]!.trim().isNotEmpty) {
      return _gamepadCustomOverrides[upperKey]!.trim();
    }
    return getGamepadDefaultCommand(upperKey);
  }

  String? getGamepadCustomOverride(String key) {
    return _gamepadCustomOverrides[key.toUpperCase()];
  }

  bool isGamepadCommandCustomized(String key) {
    final upperKey = key.toUpperCase();
    return _gamepadCustomOverrides.containsKey(upperKey) && _gamepadCustomOverrides[upperKey]!.trim().isNotEmpty;
  }

  bool get hasGamepadOverrides => _gamepadCustomOverrides.isNotEmpty;

  void setGamepadCommand(String key, String? customValue) {
    final upperKey = key.toUpperCase();
    if (customValue == null || customValue.trim().isEmpty) {
      _gamepadCustomOverrides.remove(upperKey);
    } else {
      _gamepadCustomOverrides[upperKey] = customValue.trim();
    }
    _saveToDisk();
    notifyListeners();
  }

  void resetGamepadCommands() {
    _gamepadCustomOverrides.clear();
    _saveToDisk();
    notifyListeners();
  }

  // ==========================================
  // 4. SWITCH PANEL (Isolated Feature)
  // ==========================================
  final Map<int, String> _switchOnCustomOverrides = {};
  final Map<int, String> _switchOffCustomOverrides = {};

  /// Returns the true default ON command for Switch index.
  String getSwitchOnDefault(int index) {
    if (index == 0) return '1';
    return '${index + 1}1';
  }

  /// Returns the true default OFF command for Switch index.
  String getSwitchOffDefault(int index) {
    if (index == 0) return '0';
    return '${index + 1}0';
  }

  String getSwitchOnCommand(int index) {
    if (_switchOnCustomOverrides.containsKey(index) && _switchOnCustomOverrides[index]!.trim().isNotEmpty) {
      return _switchOnCustomOverrides[index]!.trim();
    }
    return getSwitchOnDefault(index);
  }

  String getSwitchOffCommand(int index) {
    if (_switchOffCustomOverrides.containsKey(index) && _switchOffCustomOverrides[index]!.trim().isNotEmpty) {
      return _switchOffCustomOverrides[index]!.trim();
    }
    return getSwitchOffDefault(index);
  }

  String? getSwitchOnCustomOverride(int index) => _switchOnCustomOverrides[index];
  String? getSwitchOffCustomOverride(int index) => _switchOffCustomOverrides[index];

  bool isSwitchOnCustomized(int index) {
    return _switchOnCustomOverrides.containsKey(index) && _switchOnCustomOverrides[index]!.trim().isNotEmpty;
  }

  bool isSwitchOffCustomized(int index) {
    return _switchOffCustomOverrides.containsKey(index) && _switchOffCustomOverrides[index]!.trim().isNotEmpty;
  }

  bool isSwitchCustomized(int index) {
    return isSwitchOnCustomized(index) || isSwitchOffCustomized(index);
  }

  bool get hasSwitchOverrides => _switchOnCustomOverrides.isNotEmpty || _switchOffCustomOverrides.isNotEmpty;

  void setSwitchCommands(int index, {String? onCmd, String? offCmd}) {
    if (onCmd != null && onCmd.trim().isNotEmpty) {
      _switchOnCustomOverrides[index] = onCmd.trim();
    } else {
      _switchOnCustomOverrides.remove(index);
    }
    if (offCmd != null && offCmd.trim().isNotEmpty) {
      _switchOffCustomOverrides[index] = offCmd.trim();
    } else {
      _switchOffCustomOverrides.remove(index);
    }
    _saveToDisk();
    notifyListeners();
  }

  void resetSwitchCommands([int? index]) {
    if (index != null) {
      _switchOnCustomOverrides.remove(index);
      _switchOffCustomOverrides.remove(index);
    } else {
      _switchOnCustomOverrides.clear();
      _switchOffCustomOverrides.clear();
    }
    _saveToDisk();
    notifyListeners();
  }

  // ==========================================
  // 5. VIRTUAL KEYPAD (Isolated Feature)
  // ==========================================
  final Map<String, String> _keypadCustomOverrides = {};

  /// Returns the true default command for keypad key.
  String getKeypadDefaultCommand(String key) => key;

  String getKeypadCommand(String key) {
    final upperKey = key.toUpperCase();
    if (_keypadCustomOverrides.containsKey(upperKey) && _keypadCustomOverrides[upperKey]!.trim().isNotEmpty) {
      return _keypadCustomOverrides[upperKey]!.trim();
    }
    return getKeypadDefaultCommand(key);
  }

  String? getKeypadCustomOverride(String key) => _keypadCustomOverrides[key.toUpperCase()];

  bool isKeypadCustomized(String key) {
    final upperKey = key.toUpperCase();
    return _keypadCustomOverrides.containsKey(upperKey) && _keypadCustomOverrides[upperKey]!.trim().isNotEmpty;
  }

  bool get hasKeypadOverrides => _keypadCustomOverrides.isNotEmpty;

  void setKeypadCommand(String key, String? customValue) {
    final upperKey = key.toUpperCase();
    if (customValue == null || customValue.trim().isEmpty) {
      _keypadCustomOverrides.remove(upperKey);
    } else {
      _keypadCustomOverrides[upperKey] = customValue.trim();
    }
    _saveToDisk();
    notifyListeners();
  }

  void resetKeypadCommand(String key) {
    final upperKey = key.toUpperCase();
    _keypadCustomOverrides.remove(upperKey);
    _saveToDisk();
    notifyListeners();
  }

  void resetAllKeypadCommands() => resetKeypadCommands();

  void resetKeypadCommands() {
    _keypadCustomOverrides.clear();
    _saveToDisk();
    notifyListeners();
  }

  // ==========================================
  // PERSISTENCE ENGINE
  // ==========================================
  File? _getStorageFile() {
    try {
      final tmp = Directory.systemTemp.path;
      return File('$tmp/ibots_command_config.json');
    } catch (_) {
      return null;
    }
  }

  void _saveToDisk() {
    try {
      final file = _getStorageFile();
      if (file == null) return;
      final data = {
        'carPresetMode': carPresetMode,
        'carCustomOverrides': _carCustomOverrides,
        'gyroPresetMode': gyroPresetMode,
        'gyroCustomOverrides': _gyroCustomOverrides,
        'gamepadCustomOverrides': _gamepadCustomOverrides,
        'switchOnCustomOverrides': _switchOnCustomOverrides.map((k, v) => MapEntry(k.toString(), v)),
        'switchOffCustomOverrides': _switchOffCustomOverrides.map((k, v) => MapEntry(k.toString(), v)),
        'keypadCustomOverrides': _keypadCustomOverrides,
      };
      file.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      debugPrint('[CustomCommandManager] Save error: $e');
    }
  }

  void _loadFromDisk() {
    try {
      final file = _getStorageFile();
      if (file != null && file.existsSync()) {
        final content = file.readAsStringSync();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data.containsKey('carPresetMode')) {
          carPresetMode = data['carPresetMode'] as int;
        }
        if (data.containsKey('carCustomOverrides')) {
          _carCustomOverrides.addAll(Map<String, String>.from(data['carCustomOverrides']));
        }
        if (data.containsKey('gyroPresetMode')) {
          gyroPresetMode = data['gyroPresetMode'] as int;
        }
        if (data.containsKey('gyroCustomOverrides')) {
          _gyroCustomOverrides.addAll(Map<String, String>.from(data['gyroCustomOverrides']));
        }
        if (data.containsKey('gamepadCustomOverrides')) {
          _gamepadCustomOverrides.addAll(Map<String, String>.from(data['gamepadCustomOverrides']));
        }
        if (data.containsKey('switchOnCustomOverrides')) {
          final m = Map<String, dynamic>.from(data['switchOnCustomOverrides']);
          m.forEach((k, v) => _switchOnCustomOverrides[int.parse(k)] = v.toString());
        }
        if (data.containsKey('switchOffCustomOverrides')) {
          final m = Map<String, dynamic>.from(data['switchOffCustomOverrides']);
          m.forEach((k, v) => _switchOffCustomOverrides[int.parse(k)] = v.toString());
        }
        if (data.containsKey('keypadCustomOverrides')) {
          _keypadCustomOverrides.addAll(Map<String, String>.from(data['keypadCustomOverrides']));
        }
      }
    } catch (e) {
      debugPrint('[CustomCommandManager] Load error: $e');
    }
  }
}
