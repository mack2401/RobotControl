import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibots_remote_app/widgets/custom_commands_button.dart';

void main() {
  group('CustomCommandsButton Tests', () {
    testWidgets('renders default state with label and down arrow', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                CustomCommandsButton(
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CUSTOM CMDS'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.text('CUSTOM'), findsNothing);

      await tester.tap(find.byType(CustomCommandsButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders customized active indicator when isCustomized is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                CustomCommandsButton(
                  onTap: () {},
                  isCustomized: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CUSTOM CMDS'), findsOneWidget);
      expect(find.text('CUSTOM'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });

    testWidgets('renders in compact mode with custom label and accent color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomCommandsButton(
              onTap: () {},
              label: 'CMDS',
              accentColor: const Color(0xFF0D9488),
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('CMDS'), findsOneWidget);
      expect(find.byType(CustomCommandsButton), findsOneWidget);
    });
  });
}
