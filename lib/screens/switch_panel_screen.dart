import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';
import '../widgets/custom_commands_button.dart';

class SwitchPanelScreen extends StatefulWidget {
  const SwitchPanelScreen({super.key});

  @override
  State<SwitchPanelScreen> createState() => _SwitchPanelScreenState();
}

class _SwitchPanelScreenState extends State<SwitchPanelScreen> {
  final RobotState state = RobotState();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? const Color(0xFF0B0F17) : const Color(0xFFFAF9FA);
  Color get appBarBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF9FA);
  Color get cardBg => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1B1C1D);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF5A5F63);
  Color get subBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF9FA);
  Color get chipBg => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  // 10 Customizable switch names
  late List<String> switchNames;

  // 10 Switches with exact stitch defaults (1, 3, 6, 8 ON)
  final List<bool> switchStates = [
    true,  // 1
    false, // 2
    true,  // 3
    false, // 4
    false, // 5
    true,  // 6
    false, // 7
    true,  // 8
    false, // 9
    false, // 10
  ];

  @override
  void initState() {
    super.initState();
    switchNames = List.generate(10, (i) => "Switch ${i + 1}");
  }

  void _toggleSwitch(int index) {
    setState(() {
      switchStates[index] = !switchStates[index];
    });
    final sName = switchNames[index];
    final sVal = switchStates[index] ? "ON" : "OFF";
    final cmd = switchStates[index]
        ? state.commandManager.getSwitchOnCommand(index)
        : state.commandManager.getSwitchOffCommand(index);
    state.addLog(LogType.cmd, '$sName: $sVal ($cmd)');
    state.sendPayload(cmd.endsWith('\n') ? cmd : "$cmd\n");
    state.addTerminalLog(">>> SWITCH $sName -> $sVal (CMD: '$cmd')", LogType.tx);
  }

  void _editSwitchConfig(int index) {
    final nameCtrl = TextEditingController(text: switchNames[index]);
    final onCtrl = TextEditingController(text: state.commandManager.getSwitchOnCustomOverride(index) ?? '');
    final offCtrl = TextEditingController(text: state.commandManager.getSwitchOffCustomOverride(index) ?? '');
    final defaultOn = state.commandManager.getSwitchOnDefault(index);
    final defaultOff = state.commandManager.getSwitchOffDefault(index);
    final currentOn = state.commandManager.getSwitchOnCommand(index);
    final currentOff = state.commandManager.getSwitchOffCommand(index);
    final isCustomOn = state.commandManager.isSwitchOnCustomized(index);
    final isCustomOff = state.commandManager.isSwitchOffCustomized(index);
    final isCustom = state.commandManager.isSwitchCustomized(index);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFF0284C7), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Configure Switch ${index + 1}",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Switch Label", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                style: TextStyle(fontSize: 12, color: textPrimary),
                decoration: InputDecoration(
                  hintText: "Switch ${index + 1}",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCustomOn ? "ON Command (Default: $defaultOn • Custom: $currentOn)" : "ON Command (Default: $defaultOn)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: onCtrl,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: textPrimary),
                decoration: InputDecoration(
                  hintText: "Default: $defaultOn",
                  hintStyle: TextStyle(fontSize: 10, color: textSecondary.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCustomOff ? "OFF Command (Default: $defaultOff • Custom: $currentOff)" : "OFF Command (Default: $defaultOff)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: offCtrl,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: textPrimary),
                decoration: InputDecoration(
                  hintText: "Default: $defaultOff",
                  hintStyle: TextStyle(fontSize: 10, color: textSecondary.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isCustom)
            TextButton(
              onPressed: () {
                state.commandManager.resetSwitchCommands(index);
                Navigator.pop(ctx);
                setState(() {});
                _showToast("Switch ${index + 1} reset to default commands");
              },
              child: const Text("Reset Commands", style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: textSecondary, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) switchNames[index] = newName;
              state.commandManager.setSwitchCommands(
                index,
                onCmd: onCtrl.text,
                offCmd: offCtrl.text,
              );
              Navigator.pop(ctx);
              setState(() {});
              _showToast("Switch ${index + 1} settings saved");
            },
            child: const Text("Save", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAllSwitchesConfigDialog() {
    final cm = state.commandManager;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 360),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.toggle_on, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Switch Panel: Present & Custom Commands",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, i) {
                      final onCmd = cm.getSwitchOnCommand(i);
                      final offCmd = cm.getSwitchOffCommand(i);
                      final defaultOn = cm.getSwitchOnDefault(i);
                      final defaultOff = cm.getSwitchOffDefault(i);
                      final isCustom = cm.isSwitchCustomized(i);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: subBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCustom ? const Color(0xFF0284C7) : cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  switchNames[i],
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                Text(
                                  isCustom
                                      ? "ON: $onCmd (Def: $defaultOn)  •  OFF: $offCmd (Def: $defaultOff)"
                                      : "ON: $defaultOn  •  OFF: $defaultOff",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isCustom ? const Color(0xFF0284C7) : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCustom ? const Color(0xFF0284C7) : chipBg,
                                foregroundColor: isCustom ? Colors.white : textPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              icon: const Icon(Icons.edit, size: 11),
                              label: const Text("Edit", style: TextStyle(fontSize: 10)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _editSwitchConfig(i);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text("Reset All to Defaults", style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        cm.resetSwitchCommands();
                        setModalState(() {});
                        setState(() {});
                        _showToast("All switches reset to default commands");
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Done", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appBarBg.withOpacity(0.95),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: CustomCommandsButton(
              onTap: _showAllSwitchesConfigDialog,
              accentColor: const Color(0xFF0D9488),
              isCustomized: state.commandManager.hasSwitchOverrides,
            ),
          ),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cardBg,
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, size: 20, color: textPrimary),
            ),
          ),
        ),
        title: Text(
          'Switch Panel',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top control strip: 10 Relays
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
                child: Text(
                  "10-Channel Relays",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.25,
                ),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final isChecked = switchStates[index];
                  final name = switchNames[index];
                  final onCmd = state.commandManager.getSwitchOnCommand(index);
                  final offCmd = state.commandManager.getSwitchOffCommand(index);
                  final isCustom = state.commandManager.isSwitchCustomized(index);

                  return InkWell(
                    onTap: () => _toggleSwitch(index),
                    onLongPress: () => _editSwitchConfig(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isChecked
                              ? (isDark ? const Color(0xFF0D9488) : const Color(0xFF99F6E4))
                              : (isCustom ? const Color(0xFF0284C7) : cardBorder),
                          width: isChecked || isCustom ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isChecked ? 'ON' : 'OFF',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isChecked ? const Color(0xFF14B8A6) : textSecondary,
                                ),
                              ),
                            ],
                          ),
                          // Present Command Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCustom ? const Color(0xFF0284C7) : cardBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isChecked ? "ON: $onCmd" : "OFF: $offCmd",
                              style: TextStyle(
                                fontSize: 8.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isChecked
                                    ? const Color(0xFF14B8A6)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 24,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: isChecked
                                      ? const Color(0xFF0D9488)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE3E2E3)),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: isChecked ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
