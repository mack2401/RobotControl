import 'package:flutter/material.dart';
import 'profile_screen.dart';

class GuideItemModel {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final String tag;
  final Widget content;

  GuideItemModel({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.tag,
    required this.content,
  });
}

class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  State<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends State<GettingStartedScreen> {
  String selectedCategory = 'all';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedItems = {'Getting Started', 'Car Controller'};

  late final List<GuideItemModel> _guides;

  @override
  void initState() {
    super.initState();
    _guides = [
      // 1. Getting Started
      GuideItemModel(
        title: 'Getting Started',
        subtitle: 'Setup, pairing modes & connection telemetry',
        category: 'connectivity',
        icon: Icons.rocket_launch,
        tag: 'Essential',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The iBots Remote Controller delivers responsive low-latency IoT control for ESP32 and Arduino boards over BLE, Classic Bluetooth, and local Wi-Fi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '3-STEP QUICK CONNECT',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF094CB2), letterSpacing: 0.8),
                  ),
                  SizedBox(height: 8),
                  _StepRow(step: '1', title: 'Enable Radio:', desc: 'Turn on phone Bluetooth or join the robot\'s local Wi-Fi network.'),
                  SizedBox(height: 6),
                  _StepRow(step: '2', title: 'Select Mode:', desc: 'Choose between BLE, Classic BT, or Wi-Fi IP.'),
                  SizedBox(height: 6),
                  _StepRow(step: '3', title: 'Pair & Verify:', desc: 'Tap Connect Device and look for the connection indicator.'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEDEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info, size: 18, color: Color(0xFF094CB2)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected shows active ping latency. Disconnected requires re-scanning.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1B1C1D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 2. Car Controller
      GuideItemModel(
        title: 'Car Controller',
        subtitle: 'Omnidirectional drive, cutoff switch & dance mode',
        category: 'controls',
        icon: Icons.directions_car,
        tag: 'Standard',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Car Controller view dispatches instant single-character UART commands over serial stream for H-Bridge motor drivers (L298N, TB6612FNG, or ESP32 Motor Shields).',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3F4), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Movement Commands', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF094CB2))),
                        SizedBox(height: 4),
                        Text('F = Drive Forward\nB = Reverse / Back\nL = Pivot Left\nR = Pivot Right', style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3F4), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Emergency Brake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A))),
                        SizedBox(height: 4),
                        Text('S = Instant Cutoff', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A))),
                        SizedBox(height: 2),
                        Text('Releasing buttons also automatically issues \'S\' stop pulses.', style: TextStyle(fontSize: 10, color: Color(0xFF5A5F63))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Special Triggers:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B1C1D))),
            const SizedBox(height: 4),
            const Text('• Horn: Toggles onboard active buzzer / piezo pin.\n• Headlights: Toggles ultra-bright forward LED array.\n• Dance Mode: Automated celebratory routine with spins and wiggles.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 3. Robotic Arm Control
      GuideItemModel(
        title: 'Robotic Arm Control',
        subtitle: 'Servo angle adjustment (0°–180°), multi-joint expansion & centering',
        category: 'controls',
        icon: Icons.precision_manufacturing,
        tag: 'Multi-Axis',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Robotic Arm module controls articulated servos across individual joint axes (Base A, Shoulder B, Elbow C, and auxiliary joints).',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            const SizedBox(height: 8),
            const Text('• Servo Sliders (0°–180°): Continuous angle manipulation with real-time degree readout.\n• + Add Movement: Append extra axes (D, E, F...) for 4-DOF to 6-DOF arms.\n• Center All: Instantly resets all connected servos to 90° neutral position.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF5F3F4), borderRadius: BorderRadius.circular(6)),
              child: const Text('Serial Protocol: [Axis][Angle] (e.g. A90, B120, C45).', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF094CB2))),
            ),
          ],
        ),
      ),

      // 4. Virtual Gamepad
      GuideItemModel(
        title: 'Virtual Gamepad',
        subtitle: 'Dual-zone D-pad, 4 PlayStation action keys & pause',
        category: 'controls',
        icon: Icons.sports_esports,
        tag: 'Tactile',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Provides an ergonomic dual-zone gamepad experience designed for low touch-latency and customizable actuator routines.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Left Zone: 4-way D-Pad and directional thumbstick triggers.\n• Right Zone: ▲ Triangle (Gripper Open), ■ Square (Pan Left), ● Circle (Pan Right), ✕ Cross (Gripper Close).\n• Start / Pause header buttons freeze autonomous navigation immediately.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 5. LED & RGB Control
      GuideItemModel(
        title: 'LED & RGB Control',
        subtitle: '360° color wheel, PWM brightness & quick chips',
        category: 'hardware',
        icon: Icons.lightbulb,
        tag: 'Lighting',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Control single-pin digital lamps or WS2812B / NeoPixel addressable lighting strips.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Simple Lamp Switch: Transmits binary command 1 for ON and 0 for OFF.\n• RGB Wheel & Brightness: Color canvas sends #RRGGBB\\n. Use the 0–255 PWM slider to dim.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 6. Switch Panel
      GuideItemModel(
        title: 'Switch Panel',
        subtitle: '10 template digital toggle relays & GPIO pins',
        category: 'hardware',
        icon: Icons.tune,
        tag: 'Relays',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Configured as a convenient 2-column grid of 10 digital toggles (Switch 1 through 10) for activating solenoids, secondary pumps, or custom GPIO relays.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Active (ON): Sends SW{ID}:HIGH with state glow.\n• Inactive (OFF): Sends SW{ID}:LOW in neutral state.\n• Inline pencil edit button allows renaming custom channels.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 7. Text Terminal (CLI)
      GuideItemModel(
        title: 'Text Terminal (CLI)',
        subtitle: 'Direct ASCII commands, echo buffer & console logs',
        category: 'connectivity',
        icon: Icons.terminal,
        tag: 'Raw UART',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'The low-level engineer\'s tool for observing live return data, debug logs, and dispatching custom string parameters.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Common Commands: FORWARD, BACKWARD, STOP, LIGHT ON, HORN ON, STATUS.\n• Type any command in the prompt to send directly over serial connection.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 8. Voice Control
      GuideItemModel(
        title: 'Voice Control',
        subtitle: 'Speech recognition routines & trigger keywords',
        category: 'controls',
        icon: Icons.mic,
        tag: 'Smart',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Control the vehicle hands-free using natural speech processed locally on your smartphone device.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('Supported phrases: "Go forward", "Turn left", "Turn right", "Stop car", "Lights on", "Dance mode".', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 9. Virtual Keypad
      GuideItemModel(
        title: 'Virtual Keypad',
        subtitle: 'Matrix telephone dialer with A-D, *, and # commands',
        category: 'controls',
        icon: Icons.dialpad,
        tag: 'Hex 4x4',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Simulates an industrial 4x4 tactile matrix keypad (0–9, A, B, C, D, *, #). Ideal for password authentication locks or setting numeric PID parameters.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Backspace (<): Clears the most recent buffer entry.\n• Clear (C): Flushes the current staging string.\n• Send Packet: Pushes the verified byte array to your microcontroller.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 10. Telemetry & Sensors
      GuideItemModel(
        title: 'Telemetry & Sensors',
        subtitle: 'Ultrasonic sonar, LiPo voltage, warnings & debug pins',
        category: 'hardware',
        icon: Icons.speed,
        tag: 'Live Data',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Receives streaming JSON or delimited packets from HC-SR04 sonar sensors, IMU gyroscopes, and analog battery dividers.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Sonar Range: Displays obstacle distance in cm. Warning triggers below 15 cm.\n• Battery Level: LiPo voltage and percentage calculation.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 11. ESP32-CAM Video
      GuideItemModel(
        title: 'ESP32-CAM Video',
        subtitle: 'MJPEG feed, AP vs Station mode & snapshots',
        category: 'hardware',
        icon: Icons.videocam,
        tag: 'Streaming',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Connect to an OV2640 camera module streaming real-time video directly into the controller cockpit.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• AP Mode: Connect to "iBots-ESP32" default IP http://192.168.4.1:81/stream.\n• Features: High / Medium / Low resolution picker, recording with pause/resume, snapshots.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 12. Settings & Profiles
      GuideItemModel(
        title: 'Settings & Profiles',
        subtitle: 'Themes, operator identity, sound & firmware info',
        category: 'troubleshooting',
        icon: Icons.settings,
        tag: 'System',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Manage application configuration scope, user operator identity, and client preferences in the Settings tab.',
              style: TextStyle(fontSize: 12, color: Color(0xFF434653), height: 1.45),
            ),
            SizedBox(height: 6),
            Text('• Profile: Edit full name and email address with instantaneous avatar initials updates.\n• Preferences: Dark mode theme toggle and voice control switch.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),

      // 13. Troubleshooting
      GuideItemModel(
        title: 'Troubleshooting',
        subtitle: 'Connection failures, motor power & sensor fixes',
        category: 'troubleshooting',
        icon: Icons.build_circle,
        tag: 'Diagnostics',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Quick diagnostic checklist for hardware and connection issues:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A)),
            ),
            SizedBox(height: 6),
            Text('• Device fails to discover: Ensure ESP32 is powered via reliable 5V USB. Cycle phone Bluetooth.\n• Camera stream blank: Check ribbon cable in FPC connector. Lower resolution to Medium/Low.\n• Motors don\'t spin: Ensure motor battery is turned ON and ground (GND) is shared with ESP32.', style: TextStyle(fontSize: 11, color: Color(0xFF434653), height: 1.4)),
          ],
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _guides.where((g) {
      final matchesCat = selectedCategory == 'all' || g.category == selectedCategory;
      final q = searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          g.title.toLowerCase().contains(q) ||
          g.subtitle.toLowerCase().contains(q) ||
          g.tag.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFFAF9FA);
    final appBarBg = isDark ? const Color(0xFF0F172A) : const Color(0xE6FAF9FA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.transparent;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1B1C1D);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5A5F63);
    final searchFill = isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F3F4);
    final iconBoxBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFD9E2FF);
    final tagBg = isDark ? const Color(0xFF334155) : const Color(0xFFDFE3E8);
    final tagText = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF171C20);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: appBarBg,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 8, offset: const Offset(0, 1)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: Icon(Icons.arrow_back, size: 24, color: textPrimary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "User Guide",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF094CB2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                hintText: "Search guide, features, commands...",
                hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0284C7)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 16, color: textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: searchFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
            const SizedBox(height: 12),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'All (13)', isDark: isDark),
                  _buildCategoryChip('controls', 'Controls', isDark: isDark),
                  _buildCategoryChip('hardware', 'Hardware', isDark: isDark),
                  _buildCategoryChip('connectivity', 'Connectivity', isDark: isDark),
                  _buildCategoryChip('troubleshooting', 'Troubleshooting', isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Accordion List
            ...filtered.map((item) {
              final isExpanded = _expandedItems.contains(item.title) || searchQuery.isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_expandedItems.contains(item.title)) {
                            _expandedItems.remove(item.title);
                          } else {
                            _expandedItems.add(item.title);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: iconBoxBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.icon, size: 22, color: const Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: tagBg,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.tag,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: tagText,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle,
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: item.content,
                      ),
                  ],
                ),
              );
            }),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 40, color: textSecondary),
                      const SizedBox(height: 10),
                      Text("No matching guide topics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String catId, String label, {bool isDark = false}) {
    final isSelected = selectedCategory == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => setState(() => selectedCategory = catId),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFEDEE)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? Colors.transparent : (isDark ? const Color(0xFF334155) : Colors.transparent),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF434653)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _StepRow({required this.step, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1B1C1D);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF434653);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0284C7),
          ),
          child: Center(
            child: Text(step, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: textSecondary),
              children: [
                TextSpan(text: '$title ', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
