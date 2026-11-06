import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';

class FirmwareSnippet {
  final int id;
  final String title;
  final String badge;
  final String category; // 'motion', 'lighting', 'comm', 'sensors'
  final String description;
  final IconData icon;
  final String? code;
  final String note;
  final bool isSpecialNotice;

  const FirmwareSnippet({
    required this.id,
    required this.title,
    required this.badge,
    required this.category,
    required this.description,
    required this.icon,
    this.code,
    required this.note,
    this.isSpecialNotice = false,
  });
}

class CodeExamplesScreen extends StatefulWidget {
  const CodeExamplesScreen({super.key});

  @override
  State<CodeExamplesScreen> createState() => _CodeExamplesScreenState();
}

class _CodeExamplesScreenState extends State<CodeExamplesScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  // Track expanded cards. IDs 0, 101, 102 start expanded by default.
  final Set<int> _expandedCards = {0, 101, 102};

  // Track copied state per card id (id -> timer)
  final Map<int, bool> _copiedStates = {};

  final List<FirmwareSnippet> _snippets = const [
    // 101. ESP32 Wi-Fi Mode 1: Local Network (Station / Router Mode)
    FirmwareSnippet(
      id: 101,
      title: "📶 ESP32 Wi-Fi Mode 1: Local Network (Router Mode)",
      badge: "Local Router",
      category: "comm",
      description: "ESP32 & phone connect to the same Wi-Fi router. Low-latency HTTP webserver with /cmd and /status JSON telemetry.",
      icon: Icons.router,
      code: '''#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>

// Enter your home / office Wi-Fi router credentials:
const char* ssid = "YOUR_ROUTER_SSID";
const char* password = "YOUR_ROUTER_PASSWORD";

WebServer server(80);

// Hardware Output Pins (Adjust according to your robot board)
const int IN1 = 18, IN2 = 19, IN3 = 22, IN4 = 23; // L298N / TB6612 Motor Driver
const int LED_PIN  = 2;                            // Onboard LED / Headlights
const int HORN_PIN = 4;                            // Buzzer / Siren

void drive(int m1, int m2, int m3, int m4) {
  digitalWrite(IN1, m1); digitalWrite(IN2, m2);
  digitalWrite(IN3, m3); digitalWrite(IN4, m4);
}

// Low-latency command handler: /cmd?val=<CMD>
void handleCmd() {
  if (server.hasArg("val")) {
    String cmd = server.arg("val");
    Serial.println("[CMD] " + cmd);

    if (cmd == "F" || cmd == "FORWARD" || cmd == "1")       { drive(HIGH, LOW, HIGH, LOW); }
    else if (cmd == "B" || cmd == "BACKWARD" || cmd == "2") { drive(LOW, HIGH, LOW, HIGH); }
    else if (cmd == "L" || cmd == "LEFT" || cmd == "3")     { drive(LOW, HIGH, HIGH, LOW); }
    else if (cmd == "R" || cmd == "RIGHT" || cmd == "4")    { drive(HIGH, LOW, LOW, HIGH); }
    else if (cmd == "S" || cmd == "STOP" || cmd == "0")     { drive(LOW, LOW, LOW, LOW); }
    else if (cmd == "H1") { digitalWrite(HORN_PIN, HIGH); }
    else if (cmd == "H0") { digitalWrite(HORN_PIN, LOW); }
    else if (cmd == "L1") { digitalWrite(LED_PIN, HIGH); }
    else if (cmd == "L0") { digitalWrite(LED_PIN, LOW); }

    server.send(200, "text/plain", "OK");
  } else {
    server.send(400, "text/plain", "Missing val");
  }
}

// Telemetry endpoint polled by iBots Remote app
void handleStatus() {
  float battery = 8.4; // Replace with analogRead voltage divider
  int distance = 45;   // Replace with HC-SR04 sonar reading
  int temp = 38;       // Replace with sensor reading
  
  String json = "{\\"battery\\":" + String(battery, 1) + 
                ",\\"distance\\":" + String(distance) + 
                ",\\"temp\\":" + String(temp) + 
                ",\\"name\\":\\"ESP32 LAN Robot\\",\\"status\\":\\"online\\"}";
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(LED_PIN, OUTPUT); pinMode(HORN_PIN, OUTPUT);
  drive(LOW, LOW, LOW, LOW);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\\nWi-Fi Connected!");
  Serial.print("ESP32 Local IP: ");
  Serial.println(WiFi.localIP());

  // Setup mDNS responder so the app can find http://esp32.local
  if (MDNS.begin("esp32")) {
    Serial.println("mDNS responder started: http://esp32.local");
  }

  server.on("/cmd", handleCmd);
  server.on("/status", handleStatus);
  server.on("/", []() {
    server.send(200, "text/plain", "iBots ESP32 LAN Server Ready");
  });

  server.begin();
  Serial.println("HTTP Server running on port 80");
}

void loop() {
  server.handleClient();
  delay(2);
}''',
      note: "Mode 1: Both ESP32 and phone connect to the same Wi-Fi router. Best for local control without cloud server.",
    ),

    // 102. ESP32 Wi-Fi Mode 2: Hotspot (SoftAP Mode)
    FirmwareSnippet(
      id: 102,
      title: "📶 ESP32 Wi-Fi Mode 2: Hotspot (SoftAP Mode)",
      badge: "Direct AP",
      category: "comm",
      description: "ESP32 creates its own Wi-Fi Access Point (SSID: ESP32_iBots_Robot). Phone connects directly to 192.168.4.1 without any router.",
      icon: Icons.wifi_tethering,
      code: '''#include <WiFi.h>
#include <WebServer.h>

// Default Hotspot credentials:
const char* ap_ssid = "ESP32_iBots_Robot";
const char* ap_pass = "12345678";

WebServer server(80);

const int IN1 = 18, IN2 = 19, IN3 = 22, IN4 = 23; // Motor Driver Pins
const int LED_PIN  = 2;                            // Status LED
const int HORN_PIN = 4;                            // Buzzer

void drive(int m1, int m2, int m3, int m4) {
  digitalWrite(IN1, m1); digitalWrite(IN2, m2);
  digitalWrite(IN3, m3); digitalWrite(IN4, m4);
}

void handleCmd() {
  if (server.hasArg("val")) {
    String cmd = server.arg("val");
    Serial.println("[AP CMD] " + cmd);

    if (cmd == "F" || cmd == "FORWARD" || cmd == "1")       { drive(HIGH, LOW, HIGH, LOW); }
    else if (cmd == "B" || cmd == "BACKWARD" || cmd == "2") { drive(LOW, HIGH, LOW, HIGH); }
    else if (cmd == "L" || cmd == "LEFT" || cmd == "3")     { drive(LOW, HIGH, HIGH, LOW); }
    else if (cmd == "R" || cmd == "RIGHT" || cmd == "4")    { drive(HIGH, LOW, LOW, HIGH); }
    else if (cmd == "S" || cmd == "STOP" || cmd == "0")     { drive(LOW, LOW, LOW, LOW); }
    else if (cmd == "H1") { digitalWrite(HORN_PIN, HIGH); }
    else if (cmd == "H0") { digitalWrite(HORN_PIN, LOW); }
    else if (cmd == "L1") { digitalWrite(LED_PIN, HIGH); }
    else if (cmd == "L0") { digitalWrite(LED_PIN, LOW); }

    server.send(200, "text/plain", "OK");
  } else {
    server.send(400, "text/plain", "Missing val");
  }
}

void handleStatus() {
  float battery = 8.4;
  int distance = 45;
  int temp = 36;
  String json = "{\\"battery\\":" + String(battery, 1) + 
                ",\\"distance\\":" + String(distance) + 
                ",\\"temp\\":" + String(temp) + 
                ",\\"name\\":\\"ESP32 Hotspot\\",\\"status\\":\\"online\\"}";
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(LED_PIN, OUTPUT); pinMode(HORN_PIN, OUTPUT);
  drive(LOW, LOW, LOW, LOW);

  // Initialize ESP32 Access Point (Default Gateway: 192.168.4.1)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_pass);

  Serial.println("\\n==================================");
  Serial.println("ESP32 Hotspot (SoftAP) Initialized");
  Serial.print("SSID: "); Serial.println(ap_ssid);
  Serial.print("Password: "); Serial.println(ap_pass);
  Serial.print("Gateway IP: "); Serial.println(WiFi.softAPIP());
  Serial.println("==================================");

  server.on("/cmd", handleCmd);
  server.on("/status", handleStatus);
  server.on("/", []() {
    server.send(200, "text/plain", "iBots ESP32 Hotspot Online");
  });

  server.begin();
  Serial.println("HTTP Server active at http://192.168.4.1:80");
}

void loop() {
  server.handleClient();
  delay(2);
}''',
      note: "Mode 2: Works anywhere without a router. Phone connects directly to ESP32_iBots_Robot (pass: 12345678).",
    ),

    // 103. ESP32-S3 LiteWing Quadcopter UDP Flight Controller
    FirmwareSnippet(
      id: 103,
      title: "🛸 LiteWing ESP32-S3 Quadcopter UDP Flight Controller & Motor Calibration",
      badge: "Drone Core",
      category: "comm",
      description: "Circuit Digest LiteWing & ESP-Drone flight firmware. Supports 30Hz CRTP UDP commander frames, real-time 4-motor precision calibration multipliers (M1-M4), live motor bench testing, and bidirectional telemetry.",
      icon: Icons.flight,
      code: '''#include <WiFi.h>
#include <WiFiUdp.h>
#include <Preferences.h>

// --- LiteWing Wi-Fi SoftAP Configuration ---
const char* ap_ssid = "LiteWing_AP";
const char* ap_pass = "12345678";
const IPAddress local_IP(192, 168, 43, 42); // Default LiteWing AP IP
const IPAddress gateway(192, 168, 43, 1);
const IPAddress subnet(255, 255, 255, 0);

WiFiUDP udp;
const unsigned int localUdpPort = 2390; // Default CRTP UDP Port

// --- 4-Motor PWM Pins (LiteWing Coreless / FET Driver) ---
const int MOTOR_FL = 4;  // M1: Front-Left  (CW)
const int MOTOR_FR = 5;  // M2: Front-Right (CCW)
const int MOTOR_RL = 6;  // M3: Rear-Left   (CCW)
const int MOTOR_RR = 7;  // M4: Rear-Right  (CW)

// PWM Properties (16kHz for silent, smooth coreless motor drive)
const int pwmFreq = 16000;
const int pwmResolution = 10; // 0 - 1023

// --- Real-World 4-Motor Precision Calibration Parameters ---
Preferences prefs;
float calFL = 1.00f; // Multiplier (0.70 to 1.30)
float calFR = 1.00f;
float calRL = 1.00f;
float calRR = 1.00f;
int minIdlePwm = 80;  // Minimum spin speed when armed
int maxOutputPwm = 1023; // Headroom cap

// Flight & Safety Watchdog
unsigned long lastPacketTime = 0;
const unsigned long WATCHDOG_TIMEOUT_MS = 600;
bool isArmed = false;
bool isBenchTesting = false;

// Current Motor Outputs (0 - 1023)
int outFL = 0, outFR = 0, outRL = 0, outRR = 0;

// Packet buffer
uint8_t packetBuffer[256];

void loadCalibrations() {
  prefs.begin("litewing", true);
  calFL = prefs.getFloat("calFL", 1.00f);
  calFR = prefs.getFloat("calFR", 1.00f);
  calRL = prefs.getFloat("calRL", 1.00f);
  calRR = prefs.getFloat("calRR", 1.00f);
  minIdlePwm = prefs.getInt("idlePwm", 80);
  maxOutputPwm = prefs.getInt("maxPwm", 1023);
  prefs.end();
  Serial.printf("Calibrations Loaded: FL:%.2f FR:%.2f RL:%.2f RR:%.2f Idle:%d\\n",
                calFL, calFR, calRL, calRR, minIdlePwm);
}

void saveCalibrations() {
  prefs.begin("litewing", false);
  prefs.putFloat("calFL", calFL);
  prefs.putFloat("calFR", calFR);
  prefs.putFloat("calRL", calRL);
  prefs.putFloat("calRR", calRR);
  prefs.putInt("idlePwm", minIdlePwm);
  prefs.putInt("maxPwm", maxOutputPwm);
  prefs.end();
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\\n--- LiteWing ESP32-S3 Flight Controller Starting ---");

  // Configure 4 Motor PWM Channels
  ledcAttach(MOTOR_FL, pwmFreq, pwmResolution);
  ledcAttach(MOTOR_FR, pwmFreq, pwmResolution);
  ledcAttach(MOTOR_RL, pwmFreq, pwmResolution);
  ledcAttach(MOTOR_RR, pwmFreq, pwmResolution);
  cutAllMotors();

  // Load persistent motor calibrations from NVS flash
  loadCalibrations();

  // Start Access Point
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(local_IP, gateway, subnet);
  WiFi.softAP(ap_ssid, ap_pass);

  Serial.print("LiteWing AP Online! SSID: ");
  Serial.println(ap_ssid);
  Serial.print("Drone IP: ");
  Serial.println(WiFi.softAPIP());

  udp.begin(localUdpPort);
  Serial.printf("UDP Commander listening on port %d\\n", localUdpPort);
}

void cutAllMotors() {
  outFL = outFR = outRL = outRR = 0;
  ledcWrite(MOTOR_FL, 0);
  ledcWrite(MOTOR_FR, 0);
  ledcWrite(MOTOR_RL, 0);
  ledcWrite(MOTOR_RR, 0);
}

void applyMotorOutputs(int fl, int fr, int rl, int rr) {
  outFL = constrain(fl, 0, maxOutputPwm);
  outFR = constrain(fr, 0, maxOutputPwm);
  outRL = constrain(rl, 0, maxOutputPwm);
  outRR = constrain(rr, 0, maxOutputPwm);

  ledcWrite(MOTOR_FL, outFL);
  ledcWrite(MOTOR_FR, outFR);
  ledcWrite(MOTOR_RL, outRL);
  ledcWrite(MOTOR_RR, outRR);
}

void parseCrtpCommander(uint8_t* buf, int len) {
  if (len < 15 || buf[0] != 0x30) return; // CRTP Commander (Port 3, Chan 0)

  float roll, pitch, yawRate;
  uint16_t thrust;

  memcpy(&roll, &buf[1], 4);
  memcpy(&pitch, &buf[5], 4);
  memcpy(&yawRate, &buf[9], 4);
  memcpy(&thrust, &buf[13], 2);

  if (thrust > 1200) {
    isArmed = true;
  } else {
    isArmed = false;
  }

  if (isArmed) {
    // Map 0-65535 thrust to 0-1023 PWM
    int basePwm = map(thrust, 0, 65535, 0, 1023);
    int rAdj = (int)(roll * 5.5f);
    int pAdj = (int)(pitch * 5.5f);
    int yAdj = (int)(yawRate * 3.5f);

    // LiteWing Quad-X Motor Mixing + Individual 4-Motor Calibration Multipliers
    int rawFL = (int)((basePwm - pAdj + rAdj + yAdj) * calFL);
    int rawFR = (int)((basePwm - pAdj - rAdj - yAdj) * calFR);
    int rawRL = (int)((basePwm + pAdj + rAdj - yAdj) * calRL);
    int rawRR = (int)((basePwm + pAdj - rAdj + yAdj) * calRR);

    // Clamp within min idle spin threshold and max limit
    int mFL = max(rawFL, minIdlePwm);
    int mFR = max(rawFR, minIdlePwm);
    int mRL = max(rawRL, minIdlePwm);
    int mRR = max(rawRR, minIdlePwm);

    applyMotorOutputs(mFL, mFR, mRL, mRR);
  } else {
    cutAllMotors();
  }
}

void parseAsciiCommand(char* str, IPAddress remoteIp, uint16_t remotePort) {
  if (strncmp(str, "CMD:ARM", 7) == 0) {
    isArmed = true;
  } else if (strncmp(str, "CMD:DISARM", 10) == 0 || strncmp(str, "CMD:EMERGENCY", 13) == 0) {
    isArmed = false;
    isBenchTesting = false;
    cutAllMotors();
  } else if (strncmp(str, "CMD:MOTOR_CAL:", 14) == 0) {
    // Format: CMD:MOTOR_CAL:<fl_pct>,<fr_pct>,<rl_pct>,<rr_pct>,<idle>,<max>
    int fl, fr, rl, rr, idle, maxP;
    if (sscanf(str + 14, "%d,%d,%d,%d,%d,%d", &fl, &fr, &rl, &rr, &idle, &maxP) >= 4) {
      calFL = fl / 100.0f;
      calFR = fr / 100.0f;
      calRL = rl / 100.0f;
      calRR = rr / 100.0f;
      if (idle > 0) minIdlePwm = idle;
      if (maxP > 0) maxOutputPwm = maxP;
      saveCalibrations();
      Serial.printf("Updated Calibrations: FL:%.2f FR:%.2f RL:%.2f RR:%.2f\\n",
                    calFL, calFR, calRL, calRR);
    }
  } else if (strncmp(str, "CMD:MOTOR_TEST:", 15) == 0) {
    // Format: CMD:MOTOR_TEST:<motorIndex>,<pwm>
    int mIdx, pwm;
    if (sscanf(str + 15, "%d,%d", &mIdx, &pwm) == 2) {
      isBenchTesting = (pwm > 0);
      pwm = constrain(pwm, 0, maxOutputPwm);
      if (mIdx == 0) applyMotorOutputs(pwm, pwm, pwm, pwm);
      else if (mIdx == 1) applyMotorOutputs(pwm, 0, 0, 0);
      else if (mIdx == 2) applyMotorOutputs(0, pwm, 0, 0);
      else if (mIdx == 3) applyMotorOutputs(0, 0, pwm, 0);
      else if (mIdx == 4) applyMotorOutputs(0, 0, 0, pwm);
    }
  } else if (strncmp(str, "CMD:PING", 8) == 0) {
    // Send PONG heartbeat reply with battery and 4-motor outputs
    char resp[128];
    snprintf(resp, sizeof(resp), "{\\"bat\\":4.12,\\"m\\":[%d,%d,%d,%d],\\"status\\":\\"OK\\"}\\n",
             outFL, outFR, outRL, outRR);
    udp.beginPacket(remoteIp, remotePort);
    udp.write((const uint8_t*)resp, strlen(resp));
    udp.endPacket();
  }
}

void loop() {
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    lastPacketTime = millis();
    IPAddress remoteIp = udp.remoteIP();
    uint16_t remotePort = udp.remotePort();

    int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
    if (len > 0) {
      if (packetBuffer[0] == 0x30) {
        parseCrtpCommander(packetBuffer, len);
      } else {
        packetBuffer[len] = '\\0';
        parseAsciiCommand((char*)packetBuffer, remoteIp, remotePort);
      }
    }
  }

  // SAFETY WATCHDOG: If no packets received within timeout, kill motors!
  if (!isBenchTesting && (millis() - lastPacketTime > WATCHDOG_TIMEOUT_MS)) {
    if (isArmed) {
      cutAllMotors();
      isArmed = false;
    }
  }

  delay(2);
}''',
      note: "LiteWing Drone: Dual Mode 2 stick flight with full 4-motor calibration support, NVS flash persistence, and bench testing over UDP port 2390.",
    ),

    // 0. Full Master Sketch (HC-05 + Arduino)
    FirmwareSnippet(
      id: 0,
      title: "★ Master All-in-One Arduino + HC-05 Sketch",
      badge: "Full System",
      category: "all",
      description: "Controls Motors (F/B/L/R/S), Headlights, Horn, Relays, Keypad, Gamepad & Telemetry Heartbeat simultaneously over HC-05.",
      icon: Icons.auto_awesome,
      code: '''#include <SoftwareSerial.h>

// HC-05 Pins: Pin 2 = RX (to HC-05 TXD), Pin 3 = TX (to HC-05 RXD via 1k/2k divider)
SoftwareSerial bt(2, 3);

// Hardware Output Pins
const int LED_PIN     = 13; // Built-in Status & Headlight LED
const int HORN_PIN    = 8;  // Piezo Buzzer / Siren
const int IN1 = 4, IN2 = 5, IN3 = 6, IN4 = 7; // L298N Motor Driver
const int RELAYS[4]   = {A1, A2, A3, A4};     // 4-Channel Relays

unsigned long lastTelemetry = 0;

void setup() {
  Serial.begin(9600);
  bt.begin(9600); // Default HC-05 baud rate
  bt.setTimeout(50); // Fast non-blocking read response

  pinMode(LED_PIN, OUTPUT);
  pinMode(HORN_PIN, OUTPUT);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  for (int i = 0; i < 4; i++) {
    pinMode(RELAYS[i], OUTPUT);
    digitalWrite(RELAYS[i], HIGH); // Relays active-LOW
  }

  stopMotors();
  Serial.println("iBots Remote: Master Controller Online");
  bt.println("[SYS] iBots Remote Online!");
}

void drive(int m1, int m2, int m3, int m4) {
  digitalWrite(IN1, m1); digitalWrite(IN2, m2);
  digitalWrite(IN3, m3); digitalWrite(IN4, m4);
}

void stopMotors() {
  drive(LOW, LOW, LOW, LOW);
}

void loop() {
  // 1. Process incoming commands from iBots Remote App
  if (bt.available()) {
    String cmd = bt.readStringUntil('\\n');
    cmd.trim();
    if (cmd.length() == 0) return;

    Serial.print("App CMD: "); Serial.println(cmd);

    // --- A. MOVEMENT & GAMEPAD ('F', 'B', 'L', 'R', 'S') ---
    if (cmd == "F" || cmd == "FORWARD") {
      drive(HIGH, LOW, HIGH, LOW); // Forward
      bt.println("[ACK] FORWARD");
    } else if (cmd == "B" || cmd == "REVERSE") {
      drive(LOW, HIGH, LOW, HIGH); // Reverse
      bt.println("[ACK] REVERSE");
    } else if (cmd == "L" || cmd == "LEFT") {
      drive(LOW, HIGH, HIGH, LOW); // Turn Left
      bt.println("[ACK] LEFT");
    } else if (cmd == "R" || cmd == "RIGHT") {
      drive(HIGH, LOW, LOW, HIGH); // Turn Right
      bt.println("[ACK] RIGHT");
    } else if (cmd == "S" || cmd == "STOP") {
      stopMotors();
      bt.println("[ACK] STOP");
    }

    // --- B. HEADLIGHTS & LED ('W' / 'w' or '1' / '0') ---
    else if (cmd == "W" || cmd == "1" || cmd == "LIGHT ON") {
      digitalWrite(LED_PIN, HIGH);
      bt.println("[ACK] LIGHTS ON");
    } else if (cmd == "w" || cmd == "0" || cmd == "LIGHT OFF") {
      digitalWrite(LED_PIN, LOW);
      bt.println("[ACK] LIGHTS OFF");
    }

    // --- C. HORN / BUZZER ('H' / 'h') ---
    else if (cmd == "H" || cmd == "HORN ON") {
      tone(HORN_PIN, 1000);
      bt.println("[ACK] HORN ACTIVE");
    } else if (cmd == "h" || cmd == "HORN OFF") {
      noTone(HORN_PIN);
      bt.println("[ACK] HORN OFF");
    }

    // --- D. DANCE CHOREOGRAPHY ('X') ---
    else if (cmd == "X" || cmd == "DANCE") {
      for (int i = 0; i < 3; i++) {
        drive(HIGH, LOW, LOW, HIGH); delay(200);
        drive(LOW, HIGH, HIGH, LOW); delay(200);
      }
      stopMotors();
      bt.println("[ACK] DANCE FINISHED");
    }

    // --- E. RELAYS ('a'-'d' ON, 'A'-'D' OFF) ---
    else if (cmd.length() == 1 && cmd[0] >= 'a' && cmd[0] <= 'd') {
      int idx = cmd[0] - 'a';
      digitalWrite(RELAYS[idx], LOW); // Turn ON (active-LOW)
      bt.print("[ACK] RELAY "); bt.print(idx + 1); bt.println(" ON");
    } else if (cmd.length() == 1 && cmd[0] >= 'A' && cmd[0] <= 'D') {
      int idx = cmd[0] - 'A';
      digitalWrite(RELAYS[idx], HIGH); // Turn OFF
      bt.print("[ACK] RELAY "); bt.print(idx + 1); bt.println(" OFF");
    }

    // --- F. KEYPAD & TERMINAL STRINGS ---
    else {
      bt.print("[ACK] RX: "); bt.println(cmd);
    }
  }

  // 2. Periodic Live Telemetry Heartbeat (every 3 seconds)
  if (millis() - lastTelemetry > 3000) {
    lastTelemetry = millis();
    bt.println("[SYS] BATT: 8.4V | STATUS: READY");
  }
}''',
      note: "Connect HC-05: Pin 2 (Soft RX) -> HC-05 TXD, Pin 3 (Soft TX) -> HC-05 RXD (via 1k/2k divider).",
    ),

    // 1. LED Control
    FirmwareSnippet(
      id: 1,
      title: "1. LED Control",
      badge: "GPIO",
      category: "lighting",
      description: "Turn an onboard or external LED ON/OFF via single byte signals.",
      icon: Icons.lightbulb_outline_rounded,
      code: '''#define LED_PIN 13
#include <SoftwareSerial.h>
SoftwareSerial bt(2, 3);

void setup() {
  bt.begin(9600);
  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  if (bt.available() > 0) {
    char cmd = bt.read();
    if (cmd == '1' || cmd == 'W') {
      digitalWrite(LED_PIN, HIGH); // Turn ON
      bt.println("[ACK] LED ON");
    } else if (cmd == '0' || cmd == 'w') {
      digitalWrite(LED_PIN, LOW);  // Turn OFF
      bt.println("[ACK] LED OFF");
    }
  }
}''',
      note: "Note: Standard Arduino boards default onboard status LED to Digital Pin 13.",
    ),

    // 2. Car Controller
    FirmwareSnippet(
      id: 2,
      title: "2. Car Controller",
      badge: "L298N",
      category: "motion",
      description: "Forward, Reverse, Left, Right & Stop motor driver H-Bridge sequencing.",
      icon: Icons.directions_car_outlined,
      code: '''// Left & Right Motor Driver Pins (L298N/TB6612)
const int IN1 = 4, IN2 = 5, IN3 = 6, IN4 = 7;

void setup() {
  Serial.begin(9600);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
}

void drive(int a1, int a2, int b1, int b2) {
  digitalWrite(IN1, a1); digitalWrite(IN2, a2);
  digitalWrite(IN3, b1); digitalWrite(IN4, b2);
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    switch(c) {
      case 'F': drive(HIGH, LOW, HIGH, LOW); break;
      case 'B': drive(LOW, HIGH, LOW, HIGH); break;
      case 'L': drive(LOW, HIGH, HIGH, LOW); break;
      case 'R': drive(HIGH, LOW, LOW, HIGH); break;
      default:  drive(LOW, LOW, LOW, LOW);   break;
    }
  }
}''',
      note: "Connect IN1-IN4 to standard PWM or digital I/O. Add ENA/ENB jumpers to VCC for full speed.",
    ),

    // 3. Horn Control
    FirmwareSnippet(
      id: 3,
      title: "3. Horn Control",
      badge: "PWM / Tone",
      category: "lighting",
      description: "Triggers an active or passive piezoelectric buzzer on request.",
      icon: Icons.volume_up_outlined,
      code: '''const int BUZZER_PIN = 8;

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER_PIN, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    char ch = Serial.read();
    if (ch == 'H') {
      tone(BUZZER_PIN, 1000); // 1kHz acoustic pulse
    } else if (ch == 'h') {
      noTone(BUZZER_PIN);
    }
  }
}''',
      note: "For active buzzers without tone generation, substitute tone() with digitalWrite(BUZZER_PIN, HIGH).",
    ),

    // 4. Light Control
    FirmwareSnippet(
      id: 4,
      title: "4. Light Control",
      badge: "MOSFET / LED",
      category: "lighting",
      description: "Operates high-intensity front headlight beams ('W' / 'w').",
      icon: Icons.wb_incandescent_outlined,
      code: '''const int HEADLIGHT_PIN = 9;

void setup() {
  Serial.begin(9600);
  pinMode(HEADLIGHT_PIN, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    char lightCmd = Serial.read();
    if (lightCmd == 'W') {
      digitalWrite(HEADLIGHT_PIN, HIGH); // Headlights ON
    } else if (lightCmd == 'w') {
      digitalWrite(HEADLIGHT_PIN, LOW);  // Headlights OFF
    }
  }
}''',
      note: "Use an N-channel logic MOSFET (e.g. IRLZ44N) if operating 12V automotive-style LED strips.",
    ),

    // 5. Dance Mode
    FirmwareSnippet(
      id: 5,
      title: "5. Dance Mode",
      badge: "Choreography",
      category: "motion",
      description: "Automated celebratory routine with random spins and directional pivots.",
      icon: Icons.music_note_outlined,
      code: '''void performDance() {
  for (int step = 0; step < 4; step++) {
    drive(HIGH, LOW, LOW, HIGH); // Spin right
    delay(200);
    drive(LOW, HIGH, HIGH, LOW); // Spin left
    delay(200);
  }
  drive(LOW, LOW, LOW, LOW);   // Finished
}

void loop() {
  if (Serial.available()) {
    if (Serial.read() == 'X') {
      performDance();
    }
  }
}''',
      note: "Ensure sufficient battery discharge headroom to prevent MCU brownout during rapid reversals.",
    ),

    // 6. Virtual Gamepad
    FirmwareSnippet(
      id: 6,
      title: "6. Virtual Gamepad",
      badge: "D-PAD & Actions",
      category: "motion",
      description: "Maps directional triggers and action buttons (Δ, □, ○, ×) to actuators.",
      icon: Icons.sports_esports_outlined,
      code: '''void loop() {
  if (Serial.available()) {
    char padKey = Serial.read();
    switch(padKey) {
      case 'F': /* Forward */ break;
      case 'B': /* Reverse */ break;
      case 'T': // Triangle (Turbo Boost)
        analogWrite(ENA_PIN, 255); break;
      case 'S': // Square (Claw Actuator Open)
        gripperServo.write(45); break;
      case 'C': // Circle (Claw Actuator Close)
        gripperServo.write(120); break;
      case 'X': // Cross (Brake)
        drive(LOW, LOW, LOW, LOW); break;
    }
  }
}''',
      note: "Include <Servo.h> on standard AVR boards to link gripper servo pins to Square/Circle actions.",
    ),

    // 7. Switch Panel
    FirmwareSnippet(
      id: 7,
      title: "7. Switch Panel",
      badge: "Relay 10CH",
      category: "lighting",
      description: "Independent toggling of up to 10 digital relay channels via 'a'-'j' & 'A'-'J'.",
      icon: Icons.toggle_on_outlined,
      code: '''const int RELAYS[10] = {22, 23, 24, 25, 26, 27, 28, 29, 30, 31};

void setup() {
  Serial.begin(9600);
  for (int i = 0; i < 10; i++) {
    pinMode(RELAYS[i], OUTPUT);
    digitalWrite(RELAYS[i], HIGH); // Opto-isolated relay boards are active-LOW
  }
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c >= 'a' && c <= 'j') {
      digitalWrite(RELAYS[c - 'a'], LOW);  // ON
    } else if (c >= 'A' && c <= 'J') {
      digitalWrite(RELAYS[c - 'A'], HIGH); // OFF
    }
  }
}''',
      note: "Most multi-channel relay modules use active-LOW optocouplers. Adjust logic levels if using high-side switches.",
    ),

    // 8. Text Terminal
    FirmwareSnippet(
      id: 8,
      title: "8. Text Terminal",
      badge: "ASCII Parser",
      category: "comm",
      description: "Full string command decoding via newline delimiter (e.g. \"FORWARD\\n\").",
      icon: Icons.terminal_rounded,
      code: '''void loop() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\\n');
    cmd.trim();

    if (cmd == "FORWARD") {
      drive(HIGH, LOW, HIGH, LOW);
    } else if (cmd == "STOP") {
      drive(LOW, LOW, LOW, LOW);
    } else if (cmd == "HORN ON") {
      tone(8, 1000);
    }
  }
}''',
      note: "Set Serial.setTimeout(50) in setup() to avoid blocking delays during line parsing.",
    ),

    // 9. Voice Control
    FirmwareSnippet(
      id: 9,
      title: "9. Voice Control",
      badge: "NLP Matcher",
      category: "comm",
      description: "Matches recognized mobile speech phrases to hardware execution paths.",
      icon: Icons.mic_none_rounded,
      code: '''void loop() {
  if (Serial.available()) {
    String phrase = Serial.readStringUntil('\\n');
    phrase.toLowerCase();
    phrase.trim();

    if (phrase.indexOf("forward") >= 0) {
      drive(HIGH, LOW, HIGH, LOW);
    } else if (phrase.indexOf("dance") >= 0) {
      performDance();
    } else if (phrase.indexOf("lights on") >= 0) {
      digitalWrite(9, HIGH);
    }
  }
}''',
      note: "indexOf keyword matching allows the controller to accept complex sentences gracefully.",
    ),

    // 10. Virtual Keypad
    FirmwareSnippet(
      id: 10,
      title: "10. Virtual Keypad",
      badge: "4x4 Matrix",
      category: "comm",
      description: "Processes 4x4 matrix keystrokes (0-9, A-D, *, #) for numeric PIN payloads.",
      icon: Icons.dialpad_rounded,
      code: '''String pinBuffer = "";
const String ACCESS_PIN = "1234";

void loop() {
  if (Serial.available()) {
    char key = Serial.read();
    if (key == '#') { // Submit key
      if (pinBuffer == ACCESS_PIN) {
        Serial.println("AUTH_OK");
      }
      pinBuffer = "";
    } else if (key == '*') {
      pinBuffer = ""; // Clear buffer
    } else {
      pinBuffer += key;
    }
  }
}''',
      note: "Great for security enclosures or arming sequence validations before motion enabling.",
    ),

    // 11. Telemetry
    FirmwareSnippet(
      id: 11,
      title: "11. Telemetry",
      badge: "HC-SR04 / Batt",
      category: "sensors",
      description: "Computes obstacle distance in cm and maps analog battery voltage.",
      icon: Icons.sensors_rounded,
      code: '''const int TRIG = 11, ECHO = 12, BATT_PIN = A0;

void loop() {
  // Ultrasonic ping
  digitalWrite(TRIG, LOW); delayMicroseconds(2);
  digitalWrite(TRIG, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG, LOW);
  long duration = pulseIn(ECHO, HIGH);
  int distanceCm = duration * 0.034 / 2;

  // Battery ADC map
  int raw = analogRead(BATT_PIN);
  int battPct = map(raw, 600, 850, 0, 100);

  // Emit structured telemetry line
  Serial.print("DIST:"); Serial.print(distanceCm);
  Serial.print(";BATT:"); Serial.println(battPct);
  delay(100);
}''',
      note: "Ensure a proper voltage divider (e.g. 10k/2.2k) protects the 5V/3.3V analog reference pin.",
    ),

    // 12. ESP32-CAM
    FirmwareSnippet(
      id: 12,
      title: "12. ESP32-CAM",
      badge: "MJPEG Stream",
      category: "sensors",
      description: "Full camera web server & low-latency video feed initialization template.",
      icon: Icons.videocam_outlined,
      code: '''#include "esp_camera.h"
#include <WiFi.h>
#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

void startCameraServer();

void setup() {
  Serial.begin(115200);
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM; config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_SVGA;
  config.jpeg_quality = 12;
  config.fb_count = 2;

  esp_camera_init(&config);
  WiFi.softAP("iBots-ESP32", "12345678");
  startCameraServer();
}''',
      note: "Stream is served on port 81 (e.g. http://192.168.4.1:81/stream) with frame-rate sync.",
    ),

    // 13. Settings and Profile
    FirmwareSnippet(
      id: 13,
      title: "13. Settings & Profile",
      badge: "App Level",
      category: "comm",
      description: "Application configuration scope and client profile storage details.",
      icon: Icons.manage_accounts_outlined,
      isSpecialNotice: true,
      note: "Configure transmission rates, baud rates, and IP addresses via the app's Settings tab.",
    ),

    // 14. Robotic Arm Control
    FirmwareSnippet(
      id: 14,
      title: "14. Robotic Arm Control",
      badge: "PCA9685 / Servos",
      category: "motion",
      description: "Multi-axis positional servo kinematics & I2C PWM expander driver.",
      icon: Icons.precision_manufacturing_outlined,
      code: '''#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

#define SERVOMIN  150 // Minimum pulse length count (0 deg)
#define SERVOMAX  600 // Maximum pulse length count (180 deg)

void setup() {
  Serial.begin(9600);
  pwm.begin();
  pwm.setPWMFreq(60);  // Analog servos run at ~60 Hz
  // Center initial servos to 90 degrees
  setServoAngle(0, 90);
  setServoAngle(1, 90);
  setServoAngle(2, 90);
}

void setServoAngle(uint8_t n, int angle) {
  int pulselen = map(angle, 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(n, 0, pulselen);
}

void loop() {
  if (Serial.available()) {
    // Protocol format: [ChannelChar][AngleInt], e.g. A90, B180, C45
    char ch = Serial.read();
    int angle = Serial.parseInt();
    if (ch >= 'A' && ch <= 'Z') {
      uint8_t servoNum = ch - 'A';
      setServoAngle(servoNum, constrain(angle, 0, 180));
    }
  }
}''',
      note: "Supports multi-axis servo PWM expander (PCA9685 I2C) or direct ESP32 LEDC servo channels from 0° to 180°.",
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCard(int id) {
    setState(() {
      if (_expandedCards.contains(id)) {
        _expandedCards.remove(id);
      } else {
        _expandedCards.add(id);
      }
    });
  }

  void _copySnippetCode(FirmwareSnippet snippet) {
    final text = snippet.code ?? snippet.description;
    Clipboard.setData(ClipboardData(text: text));

    setState(() {
      _copiedStates[snippet.id] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied '${snippet.title}' code to clipboard!"),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _copiedStates[snippet.id] = false;
        });
      }
    });
  }

  void _copyAllVisibleCode(List<FirmwareSnippet> visibleList) {
    final buffer = StringBuffer();
    for (final s in visibleList) {
      if (s.code != null) {
        buffer.writeln("// ==========================================");
        buffer.writeln("// ${s.title} [${s.badge}]");
        buffer.writeln("// ==========================================");
        buffer.writeln(s.code);
        buffer.writeln();
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied all firmware code sketches to clipboard!"),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _snippets.where((s) {
      final matchesCategory = _selectedCategory == 'all' || s.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final inTitle = s.title.toLowerCase().contains(query);
      final inBadge = s.badge.toLowerCase().contains(query);
      final inDesc = s.description.toLowerCase().contains(query);
      final inCode = (s.code ?? '').toLowerCase().contains(query);
      return inTitle || inBadge || inDesc || inCode;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isSearchVisible ? 120 : 64),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF20F172A) : const Color(0xF2FFFFFF),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x33000000) : const Color(0x0A0F172A),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Back button + iBots Logo + Title
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: "Go back",
                                icon: Icon(
                                  Icons.arrow_back,
                                  size: 22,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                                onPressed: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Scaffold.of(context).openDrawer();
                                  }
                                },
                              ),
                              Image.network(
                                'https://lh3.googleusercontent.com/aida/AEtjO1X_HZjZRVzQSC59dnSb5cJtKHeSqeTngqeS63MpQvCUjbzTCu_YGk3MfzZkiubFfQTBBCajtUoN9HRwNvqecyWTtAUhoqExyAKykIYiOE5k25mdrfBJ5UeeNSDtsXCrfjZNhsgH0RmvrQsc-W8-jnr2mkxVqnI0__44c2Bjsu560-IlXD0yo5--D6LotdmnK4bqzOEGoipO86UH1_bAuc6-ECmxtHqZ42n_tHf57SLJNVQac5-bnY5xVNp6226wtwxLnqTG-X2o2TA',
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Text(
                                  "IBOTS",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Code Examples",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right: Search + Copy All + Avatar
                        Row(
                          children: [
                            IconButton(
                              tooltip: "Search code",
                              icon: Icon(
                                _isSearchVisible ? Icons.close : Icons.search,
                                size: 20,
                                color: _isSearchVisible
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearchVisible = !_isSearchVisible;
                                  if (!_isSearchVisible) {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }
                                });
                              },
                            ),
                            IconButton(
                              tooltip: "Copy all visible sketches",
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 19,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                              onPressed: () => _copyAllVisibleCode(filtered),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                              borderRadius: BorderRadius.circular(9999),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Color(0x262563EB), blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                                child: const Icon(Icons.person, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: "Search firmware, sensors, commands...",
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF2563EB)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          // Top Utility Banner
          _buildTopUtilityBanner(isDark),
          const SizedBox(height: 14),

          // Cards Stack
          ...filtered.map((snippet) => _buildCodeCard(snippet, isDark)),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      "No firmware snippets match '$_searchQuery'",
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Try filtering by another category or clearing search.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopUtilityBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Firmware Snippets",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  "SAMPLE CODE v2.4",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Optimized C++/Arduino sketches for low-latency robotics. Fully compatible with BLE, Classic BT & Serial UART over HC-05/06 or ESP32 native hardware interfaces.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip("all", "All (14)", isDark),
                const SizedBox(width: 6),
                _buildCategoryChip("motion", "Motion & Motors", isDark),
                const SizedBox(width: 6),
                _buildCategoryChip("lighting", "Lighting & GPIO", isDark),
                const SizedBox(width: 6),
                _buildCategoryChip("comm", "Communication", isDark),
                const SizedBox(width: 6),
                _buildCategoryChip("sensors", "Sensors & CAM", isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedCategory == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(9999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x262563EB), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard(FirmwareSnippet snippet, bool isDark) {
    final isExpanded = _expandedCards.contains(snippet.id);
    final isCopied = _copiedStates[snippet.id] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header (clickable accordion)
          InkWell(
            onTap: () => _toggleCard(snippet.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFDBEAFE)),
                    ),
                    child: Icon(snippet.icon, size: 20, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  // Title + Badge + Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                snippet.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                snippet.badge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snippet.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Actions: Copy + Chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!snippet.isSpecialNotice)
                        InkWell(
                          onTap: () => _copySnippetCode(snippet),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isCopied ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCopied ? Icons.check_rounded : Icons.content_copy_rounded,
                              size: 17,
                              color: isCopied ? const Color(0xFF059669) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 22,
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Card Body (Accordion Content)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snippet.isSpecialNotice)
                    _buildSpecialNoticeBody(snippet)
                  else ...[
                    // Code block with syntax styling
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildSyntaxHighlightedText(snippet.code ?? ''),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Note box
                    _buildInfoNote(snippet.note),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialNoticeBody(FirmwareSnippet snippet) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "No Hardware Firmware Required",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Operator profile editing, color theme persistence, button layout mappings, and local client preferences are managed entirely inside the mobile app storage layer.",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.tune, color: Color(0xFF2563EB), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Configure transmission rates, baud rates, and IP addresses via the app's Settings tab.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(String note) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF1E3A8A),
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// High-fidelity C++/Arduino syntax highlighting matching Stitch HTML
  Widget _buildSyntaxHighlightedText(String code) {
    final lines = code.split('\n');
    final List<TextSpan> lineSpans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      lineSpans.add(_highlightLine(line));
      if (i < lines.length - 1) {
        lineSpans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(
      TextSpan(children: lineSpans),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.5,
        color: Color(0xFF0F172A),
      ),
    );
  }

  TextSpan _highlightLine(String line) {
    // 1. Comments
    if (line.trimLeft().startsWith('//')) {
      return TextSpan(
        text: line,
        style: const TextStyle(color: Color(0xFF94A3B8)),
      );
    }

    // 2. Preprocessor directives (#define, #include)
    if (line.trimLeft().startsWith('#')) {
      return TextSpan(
        text: line,
        style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
      );
    }

    // Token regex: strings, chars, numbers, keywords, functions, identifiers
    final regex = RegExp(
      r'(\/\*.*?\*\/)|(\/\/.*$)|(".*?"|'
      r"'.*?')"
      r'|(\b(?:void|int|const|char|long|uint8_t|bool|float|double|String|Adafruit_PWMServoDriver|camera_config_t)\b)'
      r'|(\b(?:if|else|switch|case|default|break|return|for|while)\b)'
      r'|(\b(?:setup|loop|pinMode|begin|read|digitalWrite|drive|tone|noTone|performDance|analogWrite|write|readStringUntil|trim|toLowerCase|indexOf|println|delayMicroseconds|delay|pulseIn|analogRead|map|print|setPWMFreq|setServoAngle|setPWM|constrain|startCameraServer|esp_camera_init|softAP|parseInt)\b)'
      r'|(\b(?:HIGH|LOW|OUTPUT|INPUT|CAMERA_MODEL_AI_THINKER|LEDC_CHANNEL_0|LEDC_TIMER_0|PIXFORMAT_JPEG|FRAMESIZE_SVGA|SERVOMIN|SERVOMAX)\b)'
      r'|(\b\d+(\.\d+)?\b)',
      multiLine: true,
    );

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(line)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: line.substring(lastMatchEnd, match.start),
          style: const TextStyle(color: Color(0xFF1E293B)),
        ));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('/*') || matchedText.startsWith('//')) {
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF94A3B8))));
      } else if (matchedText.startsWith('"') || matchedText.startsWith("'")) {
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w500)));
      } else if (match.group(4) != null) {
        // Types
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)));
      } else if (match.group(5) != null) {
        // Control keywords
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)));
      } else if (match.group(6) != null) {
        // Functions
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w500)));
      } else if (match.group(7) != null) {
        // Constants
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)));
      } else if (match.group(8) != null) {
        // Numbers
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFFD97706))));
      } else {
        spans.add(TextSpan(text: matchedText, style: const TextStyle(color: Color(0xFF1E293B))));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastMatchEnd),
        style: const TextStyle(color: Color(0xFF1E293B)),
      ));
    }

    return TextSpan(children: spans);
  }
}
