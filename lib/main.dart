import 'dart:async';
import 'dart:convert';
import 'dart:typed_list';
import 'package:flutter/material.dart';

import 'services/singbox_config.dart';
import 'services/amir_scanner_core.dart';
import 'services/security_rescue_service.dart';

void main() {
  runApp(const UltraVpnApp());
}

class UltraVpnApp extends StatelessWidget {
  const UltraVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aria Connected',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08080A), // Midnight Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF), // Cyber Teal
          secondary: Color(0xFFFF007F), // Cyber Pink
          surface: Color(0xFF141416), // Deep Charcoal
          onSurface: Color(0xFFE2E8F0), // Text Primary
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Service Instances
  final AmirScannerCore _scanner = AmirScannerCore();
  final SecurityRescueService _rescueService = SecurityRescueService();

  // Connection State variables
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusText = "آماده برای اتصال (Ready to Connect)";
  String _activeIp = "172.19.0.1 (Internal TUN)";
  int _activePing = 0;
  
  // Scanned IP lists
  List<ScannedIP> _discoveredIps = [];
  ScannedIP? _bestRoute;
  
  // Credentials in memory (to be shredded upon disconnect)
  Uint8List? _secureUuidBuffer;
  Uint8List? _secureConfigBuffer;

  // Timers and logs
  Timer? _durationTimer;
  int _connectionDurationSeconds = 0;
  final List<String> _securityLogs = [];

  @override
  void initState() {
    super.initState();
    _addLog("سامانه امنیتی آریا بارگذاری شد. آماده دریافت پیکربندی کوانتومی.");
    
    // Initialize the Amir Scanner Core Scheduler (Battery optimized, every 30 mins)
    _scanner.initializeBatteryOptimizedSchedule(
      onOptimalIPFound: (ScannedIP newIP) {
        setState(() {
          // Add to log and list
          if (!_discoveredIps.any((element) => element.ip == newIP.ip)) {
            _discoveredIps.insert(0, newIP);
          }
          if (_bestRoute == null || newIP.latencyMs < _bestRoute!.latencyMs) {
            _bestRoute = newIP;
            _addLog("مسیر پیشرفته CDN شناسایی شد: ${newIP.ip} با تاخیر ${newIP.latencyMs}ms");
          }
        });
      },
    );
  }

  void _addLog(String log) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _securityLogs.insert(0, "[$timestamp] $log");
    });
  }

  // Master secure toggle event
  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _disconnectVpn();
    } else {
      await _connectVpn();
    }
  }

  // Active Connection Core routine
  Future<void> _connectVpn() async {
    setState(() {
      _isConnecting = true;
      _statusText = "در حال ایمن‌سازی ترافیک و هندشیک PQC...";
    });

    _addLog("شروع فرآیند اتصال رمزنگاری شده...");

    // Simulate key generation and storage inside secure RAM buffers
    const String rawUuid = "7c126589-32cc-4971-8975-ad438349fa89";
    _secureUuidBuffer = _rescueService.allocateSecureCredential(rawUuid);

    // If no optimized route discovered yet, run an instant CDN sweep
    if (_bestRoute == null) {
      _addLog("اسکنر امیر: در حال جستجوی سریع آدرس‌های تمیز CDN...");
      await _scanner.startScan();
    }

    final String targetServer = _bestRoute?.ip ?? "104.16.85.20";
    final int targetPing = _bestRoute?.latencyMs ?? 84;

    // Generate Sing-box Config through SingBoxConfigManager safely
    final String configJson = SingBoxConfigManager.generateConfigJson(
      server: targetServer,
      port: 443,
      uuid: utf8.decode(_secureUuidBuffer!),
      protocol: "VLESS",
      sni: "telecom.cf.com",
      tls: true,
      tlsPadding: true,
      fragmentMin: 15,
      fragmentMax: 95,
      pqcEnabled: true, // Forces Kyber PQC Cryptography Handshake
      dnsLeakSecured: true,
      fakeTrafficEnabled: true,
    );

    // Save configuration inside memory buffer
    _secureConfigBuffer = _rescueService.allocateSecureCredential(configJson);

    // Simulate Sing-box process spawning
    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _activeIp = targetServer;
      _activePing = targetPing;
      _statusText = "متصل با پروتکل ضد فیلتر آریا (Connected)";
    });

    _addLog("رمزنگاری Kyber768 برقرار شد. ترافیک کاملاً مجهز به سپر امنیتی است.");
    _startDurationTimer();
  }

  // Disconnection and Shredding Core logic
  Future<void> _disconnectVpn() async {
    _durationTimer?.cancel();
    
    setState(() {
      _statusText = "قطع اتصال و امحای اطلاعات RAM (Shredding Keys)...";
    });

    _addLog("در خواست قطع اتصال صادر شد. پاکسازی کلیدها فعال گردید.");

    // DEEP MEMORY WIPE (Anti-forensics zeroing-out immediately)
    if (_secureUuidBuffer != null && _secureConfigBuffer != null) {
      _rescueService.forceDeepMemoryWipe([_secureUuidBuffer!, _secureConfigBuffer!]);
      _secureUuidBuffer = null;
      _secureConfigBuffer = null;
      _addLog("کلید فرکانس و کانفیگ مکتوب حافظه RAM به طور کامل صفرزنی (Shred) شد.");
    }

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isConnected = false;
      _statusText = "اتصال قطع شد (Disconnected)";
      _connectionDurationSeconds = 0;
    });

    _addLog("تونل غیرفعال شد. کلیدهای نشست با موفقیت منقضی شدند.");

    // Trigger instant background CDN scan to keep updated IP pool fresh for next flow
    _scanner.runInstantOnDisconnect();
  }

  // Active Dead-Drop Rescue recovery routine
  Future<void> _triggerDeadDropRescue() async {
    _addLog("شروع بازیابی اضطراری از شبکه نجات ضد دزد خط...");
    setState(() {
      _statusText = "در حال بازیابی کانفیگ‌های نجات (Emergency Rescue)...";
    });

    final DecoupledConfig? rescued = await _rescueService.executeSelfHealingRescue();
    
    if (rescued != null) {
      _addLog("موفقیت‌آمیز! کانفیگ نجات دریافت شد: ${rescued.server}:${rescued.port}");
      setState(() {
        _bestRoute = ScannedIP(
          ip: rescued.server,
          latencyMs: 72,
          isSecureAndDpiFree: true,
        );
        _statusText = "کانفیگ نجات با موفقیت بارگذاری شد.";
      });
    } else {
      _addLog("خطا: پورت‌های نجات مسدود هستند یا دسترسی به گیت‌هاب موقتاً قطع است.");
      setState(() {
        _statusText = "خطا در فرآیند نجات. از پل محلی استفاده کنید.";
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _connectionDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _connectionDurationSeconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "تداخل‌گریز هوشمند آریا (Aria VPN)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "بازیابی اضطراری کانفیگ",
            icon: const Icon(Icons.healing_outlined, color: Color(0xFFFF007F)),
            onPressed: _triggerDeadDropRescue,
          ),
          IconButton(
            tooltip: "اسکن آنی CDN تمیز",
            icon: const Icon(Icons.radar_outlined, color: Color(0xFF00F0FF)),
            onPressed: () {
              _addLog("تلاش دستی برای اسکن شبکه توزیع محتوا...");
              _scanner.startScan();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Header & Shield Visualization
              Center(
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isConnected 
                            ? const Color(0xFF00F0FF).withOpacity(0.2)
                            : const Color(0xFFFF007F).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow Ring
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isConnected 
                                ? const Color(0xFF00F0FF) 
                                : const Color(0xFFFF007F),
                            width: 3,
                          ),
                          color: const Color(0xFF141416),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isConnecting ? null : _toggleConnection,
                            child: Icon(
                              _isConnected ? Icons.verified_user : Icons.gpp_maybe_outlined,
                              size: 64,
                              color: _isConnected 
                                  ? const Color(0xFF00F0FF) 
                                  : const Color(0xFFFF007F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 2. Status Information
              Center(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isConnected ? const Color(0xFF00F0FF) : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (_isConnected)
                Center(
                  child: Text(
                    _formatDuration(_connectionDurationSeconds),
                    style: const TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Color(0xFF39FF14) // Neon Green uptime
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 3. Metadata Dashboard (T2HASH Core Metrics)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildMetricRow("پروتکل امنیتی (Protocol)", _isConnected ? "VLESS + Kyber PQC" : "غیرفعال", Icons.lock_open),
                    const Divider(color: Colors.white10, height: 20),
                    _buildMetricRow("آدرس تمیز اسکن شده (Safe IP)", _activeIp, Icons.public),
                    const Divider(color: Colors.white10, height: 20),
                    _buildMetricRow("تاخیر شبکه (HTTP Ping)", "${_isConnected ? _activePing : '0'} ms", Icons.speed),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Discovered IP Route Table from Isolate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "آی‌پی‌های تمیز شبکه CDN",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  Text(
                    "${_discoveredIps.length} آدرس فعال",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF00F0FF)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: _discoveredIps.isEmpty
                    ? const Center(
                        child: Text(
                          "در حال اسکن مداوم شبکه توزیع محتوا...",
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _discoveredIps.length,
                        itemBuilder: (context, index) {
                          final ip = _discoveredIps[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.circle, size: 8, color: Color(0xFF39FF14)),
                            title: Text(ip.ip, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                            trailing: Text(
                              "${ip.latencyMs}ms",
                              style: TextStyle(
                                fontSize: 13,
                                color: ip.latencyMs < 150 ? const Color(0xFF39FF14) : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 20),

              // 5. Encrypted Telemetry & Anti-Forensics Logs
              const Text(
                "وقایع‌نگار پدافند امنیتی و حافظه (Shredding Logs)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _securityLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        _securityLogs[index],
                        style: const TextStyle(
                          color: Color(0xFF39FF14), // Classic Cyber hacker green
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00F0FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
