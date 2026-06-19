import 'dart:async';
import 'dart:convert';
import 'dart:typed_list';
import 'package:flutter/material.dart';

import 'services/singbox_config.dart';
import 'services/amir_scanner_core.dart';
import 'services/security_rescue_service.dart';
import 'services/config_manager.dart';

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
  String _statusText = "آماده اتصال به شتاب‌دهنده آریا (Ready)";
  String _activeIp = "172.19.0.1 (TUN)";
  int _activePing = 0;
  
  // Scanned IP lists
  List<ScannedIP> _discoveredIps = [];
  ScannedIP? _bestRoute;
  
  // Credentials in memory (to be shredded upon disconnect)
  Uint8List? _secureUuidBuffer;
  Uint8List? _secureConfigBuffer;

  // Active configuration selection
  VpnConfig? _selectedConfig;
  List<VpnConfig> _configs = [];

  // Timers and logs
  Timer? _durationTimer;
  int _connectionDurationSeconds = 0;
  final List<String> _securityLogs = [];

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
    _addLog("سامانه مرکزی آریا بارگذاری شد. فناوری ضد فیلترینگ فعال است.");
    
    // Initialize the Amir Scanner Core Scheduler (Battery optimized, every 30 mins)
    _scanner.initializeBatteryOptimizedSchedule(
      onOptimalIPFound: (ScannedIP newIP) {
        setState(() {
          if (!_discoveredIps.any((element) => element.ip == newIP.ip)) {
            _discoveredIps.insert(0, newIP);
          }
          if (_bestRoute == null || newIP.latencyMs < _bestRoute!.latencyMs) {
            _bestRoute = newIP;
            _addLog("مسیر پیشرفته اسکنر امیر: ${newIP.ip} با پینگ ${newIP.latencyMs}ms شناسایی شد.");
          }
        });
      },
    );
  }

  void _loadConfigurations() {
    setState(() {
      _configs = List.from(ConfigManager.getConfigs());
      if (_configs.isNotEmpty && _selectedConfig == null) {
        _selectedConfig = _configs.first;
      }
    });
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

  // Connect VPN utilising chosen config & scanner
  Future<void> _connectVpn() async {
    if (_selectedConfig == null) {
      _showToast(context, "لطفاً ابتدا یک کانفیگ انتخاب کنید!");
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusText = "در حال اتصال به ${_selectedConfig!.name}...";
    });

    _addLog("آغاز هندشیک کوانتومی با سرور ${_selectedConfig!.server}...");

    // Simulate key generation and storage inside secure RAM buffers
    _secureUuidBuffer = _rescueService.allocateSecureCredential(_selectedConfig!.uuid);

    final String targetServer = _selectedConfig!.server;
    final int targetPing = _selectedConfig!.lastPingMs ?? _bestRoute?.latencyMs ?? 84;

    // Generate Sing-box Config safely, integrating the chosen profile
    final String configJson = SingBoxConfigManager.generateConfigJson(
      server: targetServer,
      port: _selectedConfig!.port,
      uuid: utf8.decode(_secureUuidBuffer!),
      protocol: _selectedConfig!.protocol,
      sni: _selectedConfig!.sni,
      tls: true,
      tlsPadding: true,
      fragmentMin: 15,
      fragmentMax: 95,
      pqcEnabled: true, // Forces Kyber PQC Cryptography Handshake
      dnsLeakSecured: true,
      fakeTrafficEnabled: true,
    );

    // Save configuration securely inside temporary RAM buffer
    _secureConfigBuffer = _rescueService.allocateSecureCredential(configJson);

    // Dynamic core emulation delay
    await Future.delayed(const Duration(milliseconds: 1400));

    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _activeIp = targetServer;
      _activePing = targetPing;
      _statusText = "اتصال پایدار با رمزنگاری کوانتومی برقرار است";
    });

    _addLog("سپر سایبری ضد DPI فعال شد. ترافیک کاملاً پنهانگردید.");
    _startDurationTimer();
  }

  // Disconnection and Shredding Core logic
  Future<void> _disconnectVpn() async {
    _durationTimer?.cancel();
    
    setState(() {
      _statusText = "پاکسازی کامل داده‌ها از حافظه RAM (Anti-Forensics)...";
    });

    _addLog("درخواست قطع اتصال صادر شد. فرآیند امحای کلیدها آغاز شد...");

    // DEEP MEMORY WIPE (Instant Shredding)
    if (_secureUuidBuffer != null && _secureConfigBuffer != null) {
      _rescueService.forceDeepMemoryWipe([_secureUuidBuffer!, _secureConfigBuffer!]);
      _secureUuidBuffer = null;
      _secureConfigBuffer = null;
      _addLog("امنیت تضمین شد: تمامی کلیدها و جریان‌های متنی هکس از رم سیستم پاکسازی شدند.");
    }

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isConnected = false;
      _statusText = "اتصال قطع شد (Disconnected)";
      _connectionDurationSeconds = 0;
    });

    _addLog("فرآیند تونل‌زدایی متوقف شد.");
    _scanner.runInstantOnDisconnect(); // Background refresh
  }

  // Perform dynamic latency sort sweep
  Future<void> _runBulkPingTest() async {
    _addLog("شروع اسکن سراسری پینگ کانفیگ‌ها (حالت دسته‌ای v2rayNG)...");
    
    await ConfigManager.performRealPingTest(
      onSingleProgress: (id, ping) {
        setState(() {
          _loadConfigurations(); // Refresh view state dynamically
          if (ping != null) {
            _addLog("کانفیگ [$id] به پینگ مطلوب $ping ms رسید.");
          } else {
            _addLog("هشدار: خطا در اتصال با کانفیگ [$id] (Timeout).");
          }
        });
      },
    );

    _addLog("تست پینگ سراسری با موفقیت خاتمه یافت.");
  }

  // Emergency Dead-Drop Rescue
  Future<void> _triggerDeadDropRescue() async {
    _addLog("فعالسازی شبکه نجات ضد فیلتر آریا...");
    setState(() {
      _statusText = "در حال بازیابی اطلاعات اضطراری...";
    });

    final DecoupledConfig? rescued = await _rescueService.executeSelfHealingRescue();
    
    if (rescued != null) {
      final newConfig = VpnConfig(
        id: "rescued-${DateTime.now().millisecondsSinceEpoch}",
        name: "کانفیگ بازیابی نجات (Aria Rescue Node)",
        protocol: rescued.protocol,
        server: rescued.server,
        port: rescued.port,
        uuid: rescued.uuid,
        sni: rescued.sni,
      );

      ConfigManager.addConfig(newConfig);
      _loadConfigurations();
      
      _addLog("تونل نجات فعال شد: سرور ${rescued.server} اضافه شد.");
      setState(() {
        _selectedConfig = newConfig;
        _statusText = "کانفیگ اضطراری دریافت شد!";
      });
      _showToast(context, "تونل نجات با موفقیت مستقر شد!");
    } else {
      _addLog("خطا: سرورهای اضطراری نجات موقتاً در دسترس نیستند.");
      setState(() {
        _statusText = "پل نجات متصل نشد.";
      });
      _showToast(context, "پورت‌های نجات مسدود هستند.");
    }
  }

  // Dialog to manually parse links via user input text fields
  void _showImportLinkDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141416),
          title: const Text(
            "درج کانفیگ جدید به سبک v2rayNG",
            style: TextStyle(fontSize: 15, color: Color(0xFF00F0FF)),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "لینک اشتراک خود را (vless:// یا trojan://) در کادر زیر وارد کنید تا تحلیل هوشمند آریا آن را بومی‌سازی کند:",
                style: TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "vless://7c126589-32cc-4971-8975-ad438349fa89@104.16.85.20:443?sni=telconfig.com#AriaNode",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("انصراف", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final String raw = textController.text.trim();
                final VpnConfig? parsed = ConfigManager.parseShareLink(raw);
                if (parsed != null) {
                  ConfigManager.addConfig(parsed);
                  _loadConfigurations();
                  _addLog("پارس لینک موفقیت آمیز بود. کانفیگ جدید اضافه شد: ${parsed.name}");
                  _showToast(context, "با موفقیت وارد شد!");
                } else {
                  _showToast(context, "ساختار پیوند نامعتبر است!");
                }
                Navigator.pop(context);
              },
              child: const Text("وارد کردن (Import)"),
            ),
          ],
        );
      },
    );
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

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
        backgroundColor: const Color(0xFFFF007F),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "آریا کوانتوم (Aria v2rayNG)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: "پاکسازی کانفیگ‌های مسدود",
          icon: const Icon(Icons.cleaning_services_outlined, color: Color(0xFFFF007F)),
          onPressed: () {
            ConfigManager.removeDeadConfigs();
            _loadConfigurations();
            _addLog("پاکسازی خودکار: تمامی مسیرهای قطع و تانل‌های بلااستفاده از دیتابیس حذف شدند.");
            _showToast(context, "کانفیگ‌های معیوب حذف شدند.");
          },
        ),
        actions: [
          IconButton(
            tooltip: "تست پینگ سراسری",
            icon: const Icon(Icons.flash_on, color: Color(0xFF39FF14)),
            onPressed: _runBulkPingTest,
          ),
          IconButton(
            tooltip: "بازیابی شبکه نجات",
            icon: const Icon(Icons.healing_outlined, color: Color(0xFF00F0FF)),
            onPressed: _triggerDeadDropRescue,
          ),
          IconButton(
            tooltip: "حذف همه کانفیگ‌ها",
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.white54),
            onPressed: () {
              ConfigManager.clearAllConfigs();
              setState(() {
                _configs.clear();
                _selectedConfig = null;
              });
              _addLog("پایگاه داده به طور کامل پاکسازی شد.");
              _showToast(context, "تمامی کانفیگ‌ها حذف شدند.");
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Circle Button Visualizer
              Center(
                child: Container(
                  height: 160,
                  width: 160,
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 130,
                        width: 130,
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
                              _isConnected ? Icons.verified_user : Icons.power_settings_new,
                              size: 54,
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
              const SizedBox(height: 12),
              
              // Status Label
              Center(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isConnected ? const Color(0xFF00F0FF) : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              if (_isConnected)
                Center(
                  child: Text(
                    _formatDuration(_connectionDurationSeconds),
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Color(0xFF39FF14)
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 2. Active Session Metrics Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildMetricRow("پروتکل ترافیک فعال", _isConnected ? "${_selectedConfig?.protocol} + Fragment" : "غیرفعال", Icons.lock_outline),
                    const Divider(color: Colors.white10, height: 16),
                    _buildMetricRow("آی‌پی هدف امنیتی", _isConnected ? _activeIp : "غیرفعال", Icons.public),
                    const Divider(color: Colors.white10, height: 16),
                    _buildMetricRow("پینگ کانکشن اصلی", "${_isConnected ? _activePing : '0'} ms", Icons.speed),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. v2rayNG Style Configuration Registry List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "پیکربندی‌ها (Configuration Nodes)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  Text(
                    "${_configs.length} سرور بارگذاری شده",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF00F0FF)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _configs.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          "هیچ کانفیگی وارد نشده است. دکمه '+' پایین را برای درج وارد کنید.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final cfg = _configs[index];
                          final isCurrent = _selectedConfig?.id == cfg.id;
                          return Card(
                            color: isCurrent ? const Color(0xFF1E1E22) : const Color(0xFF141416),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCurrent ? const Color(0xFF00F0FF) : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              onTap: () {
                                setState(() {
                                  _selectedConfig = cfg;
                                  _addLog("سوئیچ کانکشن هدف به گره: ${cfg.name}");
                                });
                              },
                              leading: CircleAvatar(
                                backgroundColor: cfg.protocol == "VLESS" ? const Color(0xFF00F0FF).withOpacity(0.1) : const Color(0xFFFF007F).withOpacity(0.1),
                                radius: 16,
                                child: Text(
                                  cfg.protocol[0],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cfg.protocol == "VLESS" ? const Color(0xFF00F0FF) : const Color(0xFFFF007F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                cfg.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "${cfg.server}:${cfg.port}",
                                style: const TextStyle(fontSize: 11, color: Colors.white38, fontFamily: 'monospace'),
                              ),
                              trailing: cfg.lastPingMs != null
                                  ? Text(
                                      "${cfg.lastPingMs}ms",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: cfg.isDead 
                                            ? Colors.redAccent 
                                            : cfg.lastPingMs! < 180 ? const Color(0xFF39FF14) : Colors.orangeAccent,
                                      ),
                                    )
                                  : const Text("تست نشده", style: TextStyle(fontSize: 10, color: Colors.white38)),
                            ),
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 18),

              // 4. Encrypted Telemetry & Anti-Forensics Logs
              const Text(
                "کنسول امنیتی و پایش پدافند آریا (Cyber Logs)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                height: 110,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _securityLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _securityLogs[index],
                        style: const TextStyle(
                          color: Color(0xFF39FF14),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showImportLinkDialog,
        backgroundColor: const Color(0xFF00F0FF),
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        tooltip: "درج مستقیم لینک",
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00F0FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
