import 'package:flutter_test/flutter_test.dart';
import 'package:ibots_remote_app/core/commands/custom_command_manager.dart';

void main() {
  group('CustomCommandManager Feature Isolation & Default Preservation Tests', () {
    late CustomCommandManager manager;

    setUp(() {
      manager = CustomCommandManager();
      manager.resetCarCommands();
      manager.resetGyroCommands();
      manager.resetGamepadCommands();
      manager.resetSwitchCommands();
      manager.resetKeypadCommands();
    });

    test('Custom command on Car Controller does NOT change default command', () {
      // Before custom override
      expect(manager.getCarDefaultCommand('FORWARD'), equals('F'));
      expect(manager.getCarCommand('FORWARD'), equals('F'));
      expect(manager.isCarCommandCustomized('FORWARD'), isFalse);

      // Provide custom command
      manager.setCarCommand('FORWARD', 'ran');

      // The active command is 'ran', but the default MUST REMAIN 'F'
      expect(manager.getCarCommand('FORWARD'), equals('ran'));
      expect(manager.getCarDefaultCommand('FORWARD'), equals('F'));
      expect(manager.isCarCommandCustomized('FORWARD'), isTrue);

      // Resetting restores default
      manager.resetCarCommand('FORWARD');
      expect(manager.getCarCommand('FORWARD'), equals('F'));
      expect(manager.getCarDefaultCommand('FORWARD'), equals('F'));
      expect(manager.isCarCommandCustomized('FORWARD'), isFalse);
    });

    test('Custom command on Car Controller does NOT affect Gyro or Gamepad', () {
      // Set custom on Car
      manager.setCarCommand('FORWARD', 'TURBO_FWD');
      expect(manager.getCarCommand('FORWARD'), equals('TURBO_FWD'));

      // Gyro FORWARD must remain its own default 'F'
      expect(manager.getGyroCommand('FORWARD'), equals('F'));
      expect(manager.getGyroDefaultCommand('FORWARD'), equals('F'));
      expect(manager.isGyroCommandCustomized('FORWARD'), isFalse);

      // Gamepad UP must remain its own default 'F'
      expect(manager.getGamepadCommand('UP'), equals('F'));
      expect(manager.getGamepadDefaultCommand('UP'), equals('F'));
      expect(manager.isGamepadCommandCustomized('UP'), isFalse);
    });

    test('Custom command on Gyro does NOT affect Car Controller or Gamepad', () {
      manager.setGyroCommand('LEFT', 'TILT_LEFT_99');
      expect(manager.getGyroCommand('LEFT'), equals('TILT_LEFT_99'));
      expect(manager.getGyroDefaultCommand('LEFT'), equals('L'));

      // Car Controller LEFT must remain 'L'
      expect(manager.getCarCommand('LEFT'), equals('L'));
      expect(manager.getCarDefaultCommand('LEFT'), equals('L'));

      // Gamepad LEFT must remain 'L'
      expect(manager.getGamepadCommand('LEFT'), equals('L'));
      expect(manager.getGamepadDefaultCommand('LEFT'), equals('L'));
    });

    test('Custom command on Gamepad does NOT affect Car Controller or Gyro', () {
      manager.setGamepadCommand('UP', 'DPAD_UP_RAW');
      expect(manager.getGamepadCommand('UP'), equals('DPAD_UP_RAW'));
      expect(manager.getGamepadDefaultCommand('UP'), equals('F'));

      // Car Controller FORWARD must remain 'F'
      expect(manager.getCarCommand('FORWARD'), equals('F'));

      // Gyro FORWARD must remain 'F'
      expect(manager.getGyroCommand('FORWARD'), equals('F'));
    });

    test('Switch Panel custom commands preserve defaults and isolation', () {
      expect(manager.getSwitchOnDefault(0), equals('1'));
      expect(manager.getSwitchOffDefault(0), equals('0'));

      manager.setSwitchCommands(0, onCmd: 'RELAY_1_ON', offCmd: 'RELAY_1_OFF');
      expect(manager.getSwitchOnCommand(0), equals('RELAY_1_ON'));
      expect(manager.getSwitchOffCommand(0), equals('RELAY_1_OFF'));

      // Defaults remain unchanged
      expect(manager.getSwitchOnDefault(0), equals('1'));
      expect(manager.getSwitchOffDefault(0), equals('0'));

      // Switch 1 is unaffected
      expect(manager.getSwitchOnCommand(1), equals('21'));
      expect(manager.getSwitchOffCommand(1), equals('20'));
    });

    test('Keypad custom commands preserve defaults and isolation', () {
      expect(manager.getKeypadDefaultCommand('1'), equals('1'));
      manager.setKeypadCommand('1', 'PASS_1');

      expect(manager.getKeypadCommand('1'), equals('PASS_1'));
      expect(manager.getKeypadDefaultCommand('1'), equals('1'));
      expect(manager.getKeypadCommand('2'), equals('2'));
    });
  });
}
