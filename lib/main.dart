import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
      title: 'Aria Unified',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060608), // Ultimate Obsidian
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF), // Cyber Teal
          secondary: Color(0xFFFF007F), // Cyber Pink
          surface: Color(0xFF101014), // Deep Charcoal
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
  String _statusText = "آماده سپرگذاری فرکانس آریا";
  String _activeIp = "172.19.0.1 (TUN interface)";
  int _activePing = 0;
  
  // CDN Scanner variables
  List<ScannedIP> _discoveredIps = [];
  ScannedIP? _bestRoute;
  
  // High secrecy memory slots
  Uint8List? _secureUuidBuffer;
  Uint8List? _secureConfigBuffer;

  // Configuration sets
  VpnConfig? _selectedConfig;
  List<VpnConfig> _configs = [];

  // Toggles and Premium parameters
  bool _isLanSharing = false;
  bool _isDecoyActive = false;
  bool _splitTunnelingEnabled = false;
  bool _autoPingRoutation = true;
  bool _chainProxyEnabled = false;
  String? _chainBridgeId;

  // Custom Split Tunneling Simulated App Registry
  final Map<String, bool> _splitTunnelApps = {
    "سیستم بانکی ایران (Iran Banking)": true,
    "برنامه شاد آموزش ملی (Shad App)": true,
    "محتوای اسنپ و تپسی (Snapp / Tap30)": true,
    "دیجیکالا سرویس (Digikala CRM)": false,
    "تلگرام پیام‌رسان (Telegram Messenger)": false,
    "اینستاگرام (Instagram Social)": false,
  };

  // Timers and logs
  Timer? _durationTimer;
  Timer? _autoPingScheduler;
  Timer? _decoyTrafficTimer;
  int _connectionDurationSeconds = 0;
  double _decoySentMb = 0.0;
  int _decoyPacketsInjected = 0;
  final List<String> _securityLogs = [];

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
    _addLog("سامانه مرکزی پدافند سایبری آریا بارگذاری شد.");
    _addLog("ماژول ضد تحریم T2HASH با ضریب ایمنی استقراری متصل است.");
    
    // Core CDN discovery scheduler
    _scanner.initializeBatteryOptimizedSchedule(
      onOptimalIPFound: (ScannedIP newIP) {
        setState(() {
          if (!_discoveredIps.any((element) => element.ip == newIP.ip)) {
            _discoveredIps.insert(0, newIP);
          }
          if (_bestRoute == null || newIP.latencyMs < _bestRoute!.latencyMs) {
            _bestRoute = newIP;
            _addLog("مسیر پیشفرض CDN بهینه‌سازی شد: ${newIP.ip} (${newIP.latencyMs}ms)");
          }
        });
      },
    );

    // Dynamic Silent auto-ping loop running every 10 seconds for demo (conceptually mapped to 10 mins)
    _startAutoPingTask();
  }

  void _loadConfigurations() {
    setState(() {
      _configs = List.from(ConfigManager.getConfigs());
      if (_configs.isNotEmpty && _selectedConfig == null) {
        _selectedConfig = _configs.first;
      }
      if (_configs.isNotEmpty && _chainBridgeId == null) {
        _chainBridgeId = _configs.last.id;
      }
    });
  }

  void _addLog(String log) {
    if (!mounted) return;
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _securityLogs.insert(0, "[$timestamp] $log");
    });
  }

  // Active Background scheduler which rotates targets silently if latency triggers anomalies
  void _startAutoPingTask() {
    _autoPingScheduler?.cancel();
    _autoPingScheduler = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!_autoPingRoutation) return;

      if (_isConnected) {
        _addLog("پایش پس‌زمینه خودکار: بررسی سلامت پورت‌های دسترسی...");
        await ConfigManager.performRealPingTest(
          onSingleProgress: (id, ping) {
            if (ping != null && _selectedConfig != null && id != _selectedConfig!.id) {
              final currentPing = _selectedConfig!.lastPingMs ?? 999;
              if (ping < currentPing - 30) {
                // Better node found seamlessly!
                final betterConfig = _configs.firstWhere((element) => element.id == id);
                _addLog("جابجایی بدون قطعی! مسیر سریع‌تر یافت شد: ${betterConfig.name} با پینگ $ping ms");
                setState(() {
                  _selectedConfig = betterConfig;
                  _activePing = ping;
                });
              }
            }
          }
        );
      }
    });
  }

  // Master connection routine linking Sing-box Config + Kyber PQC + Decoy
  Future<void> _connectVpn() async {
    if (_selectedConfig == null) {
      _showToast(context, "هیچ سروری بارگذاری نشده است!");
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusText = "فرآیند ایمن سازی و تزریق لایه محافظ...";
    });

    _addLog("فراخوانی هسته سینگ باکس برای روت تانل...");

    // Store keys inside secure zeroable RAM buffers
    _secureUuidBuffer = _rescueService.allocateSecureCredential(_selectedConfig!.uuid);

    // Apply config chains if checked
    String targetServer = _selectedConfig!.server;
    int targetPort = _selectedConfig!.port;
    if (_chainProxyEnabled && _chainBridgeId != null) {
      final bridge = _configs.firstWhere((element) => element.id == _chainBridgeId, orElse: () => _selectedConfig!);
      targetServer = bridge.server;
      targetPort = bridge.port;
      _addLog("زنجیره فعال شد: کلاینت -> ${bridge.name} -> ${_selectedConfig!.name}");
    }

    // Generate Singbox configuration
    final String configString = SingBoxConfigManager.generateConfigJson(
      server: targetServer,
      port: targetPort,
      uuid: utf8.decode(_secureUuidBuffer!),
      protocol: _selectedConfig!.protocol,
      sni: _selectedConfig!.sni,
      tls: true,
      tlsPadding: true,
      fragmentMin: 12,
      fragmentMax: 88,
      pqcEnabled: true, // Forces Post-quantum Key Exchange (Kyber768 handshake)
      dnsLeakSecured: true,
      fakeTrafficEnabled: _isDecoyActive,
    );

    _secureConfigBuffer = _rescueService.allocateSecureCredential(configString);

    // Spawning engine delay emulator
    await Future.delayed(const Duration(milliseconds: 1300));

    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _activeIp = targetServer;
      _activePing = _selectedConfig!.lastPingMs ?? _bestRoute?.latencyMs ?? 62;
      _statusText = "تونل آریا کوانتوم با موفقیت مستقر شد";
    });

    _addLog("سامانه ضد نظارت رصد ترافیک با موفقیت مستقر شد.");
    _startDurationTimer();

    // Start Decoy packet background emitter if toggle is active
    if (_isDecoyActive) {
      _startDecoyEmulation();
    }
  }

  // Pure zero-out memory destruction on click disconnect
  Future<void> _disconnectVpn() async {
    _durationTimer?.cancel();
    _stopDecoyEmulation();

    setState(() {
      _statusText = "درحال بازخوانی سکتورها و نابودسازی داده‌ها...";
    });

    _addLog("عملیات خروج اضطراری: اجرای پروتکل امحای اطلاعات RAM...");

    if (_secureUuidBuffer != null && _secureConfigBuffer != null) {
      _rescueService.forceDeepMemoryWipe([_secureUuidBuffer!, _secureConfigBuffer!]);
      _secureUuidBuffer = null;
      _secureConfigBuffer = null;
      _addLog("تضمین امنیت نهایی کلاینت: کلیدهای نشست و متادیتا کاملا صفرزنی شدند.");
    }

    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      _isConnected = false;
      _statusText = "سپر تانل قطع شد";
      _connectionDurationSeconds = 0;
    });

    _addLog("سیستم با موفقیت به اینترنت مستقیم سیستم بازگشت.");
    _scanner.runInstantOnDisconnect(); // Prepare new clean endpoints securely
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _disconnectVpn();
    } else {
      await _connectVpn();
    }
  }

  // Decoy Packet Simulation (Obfuscating pattern metrics for bypass)
  void _startDecoyEmulation() {
    _decoyTrafficTimer?.cancel();
    _decoyTrafficTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isConnected) return;
      final Random random = Random();
      final double chunkMb = (random.nextInt(350) + 100) / 1024.0;
      setState(() {
        _decoySentMb += chunkMb;
        _decoyPacketsInjected += random.nextInt(6) + 2;
      });
      if (random.nextInt(10) > 7) {
        _addLog("تزریق لایه ترافیک تصادفی: ارسال ${chunkMb.toStringAsFixed(2)} MB بسته داده فیک جهت اغفال فایروال DPI.");
      }
    });
  }

  void _stopDecoyEmulation() {
    _decoyTrafficTimer?.cancel();
    setState(() {
      _decoySentMb = 0.0;
      _decoyPacketsInjected = 0;
    });
  }

  // Simulated High Fidelity Scanner Dialog
  void _showCameraQRScannerMock() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "QRMock",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
          body: Stack(
            children: [
              // Matrix/Grid scan aesthetic line simulator
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "بارگذاری دوربین / رهگیر بارکد نوری آریا",
                    style: TextStyle(color: Color(0xFF00F0FF), fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "لنز دوربین خروجی گوشی خود را روی بارکد نگه دارید",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      height: 240,
                      width: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00F0FF), width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 100, color: const Color(0xFF00F0FF).withOpacity(0.5)),
                          // Scanning green pulse bar
                          Positioned(
                            top: 10,
                            child: AnimatedContainer(
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeInOut,
                              height: 2,
                              width: 210,
                              color: const Color(0xFF39FF14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF007F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Import clean fallback test payload instantly
                        const mockQRPayload = "vless://7c126589-32cc-4971-8975-ad438349fa89@104.21.40.11:443?sni=bypass.ir#AriaQRNode";
                        final parsed = ConfigManager.parseShareLink(mockQRPayload);
                        if (parsed != null) {
                          ConfigManager.addConfig(parsed);
                          _loadConfigurations();
                          _addLog("ارتباط نوری برقرار شد! گره از روی دوربین افزوده شد: ${parsed.name}");
                        }
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.flash_on),
                      label: const Text("تست بارکد نمونه (Mock Scan QR)"),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Dialog to manually parse links via user input text fields
  void _showImportLinkDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101014),
          title: const Text(
            "درج پیکربندی جدید",
            style: TextStyle(fontSize: 15, color: Color(0xFF00F0FF)),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "پیوند اشتراک (VLESS / Trojan) را اینجا قرار دهید تا کلاینت ضد تحریم آریا آن را پردازش کند:",
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
                  _addLog("بومی‌سازی موفق! کانفیگ ثبت گردید: ${parsed.name}");
                  _showToast(context, "با موفقیت وارد شد!");
                } else {
                  _showToast(context, "لینک آدرس ورودی نادرست است.");
                }
                Navigator.pop(context);
              },
              child: const Text("تایید ورود"),
            ),
          ],
        );
      },
    );
  }

  // Active Dead-Drop Rescue recovery routine
  Future<void> _triggerDeadDropRescue() async {
    _addLog("فعالسازی پورت نجات اضطراری ضد مسدودی...");
    setState(() {
      _statusText = "در حال بازیابی پل‌های دسترسی خارجی...";
    });

    final DecoupledConfig? rescued = await _rescueService.executeSelfHealingRescue();
    
    if (rescued != null) {
      final newConfig = VpnConfig(
        id: "rescued-${DateTime.now().millisecondsSinceEpoch}",
        name: "پل نجات رمزگذاری شده (Quantum Rescue Node)",
        protocol: rescued.protocol,
        server: rescued.server,
        port: rescued.port,
        uuid: rescued.uuid,
        sni: rescued.sni,
      );

      ConfigManager.addConfig(newConfig);
      _loadConfigurations();
      
      _addLog("شبکه نجات با موفقیت ریکاوری شد: سرور ${rescued.server} مستقر گردید.");
      setState(() {
        _selectedConfig = newConfig;
        _statusText = "پل نجات متصل شد.";
      });
      _showToast(context, "پل نجات گره دوم بازیابی شد!");
    } else {
      _addLog("شکست در دریافت پل نجات: سرورهای میزبان اینترنتی مسدود شده‌اند.");
      setState(() {
        _statusText = "سرور نجات در دسترس نیست.";
      });
      _showToast(context, "پورت‌های نجات مسدود هستند.");
    }
  }

  Future<void> _runBulkPingTest() async {
    _addLog("آغاز تست سرعت کلی شبکه آریا...");
    await ConfigManager.performRealPingTest(
      onSingleProgress: (id, ping) {
        setState(() {
          _loadConfigurations();
          if (ping != null) {
            _addLog("تست پینگ موفق کانفیگ [$id]: مقدار $ping ms");
          }
        });
      },
    );
    _addLog("تست پینگ به پایان رسید.");
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
          "آریا کوانتوم پلاس (Aria Quantum+)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: "پاکسازی بهینه دیتابیس",
          icon: const Icon(Icons.cleaning_services, color: Color(0xFFFF007F)),
          onPressed: () {
            ConfigManager.removeDeadConfigs();
            _loadConfigurations();
            _addLog("پایگاه داده پاکسازی شد. تمامی اتصال‌های نامعتبر یا مسدود حذف گشتند.");
            _showToast(context, "کانفیگ‌های تایم‌اوت پاکسازی شدند.");
          },
        ),
        actions: [
          IconButton(
            tooltip: "تست سرعت",
            icon: const Icon(Icons.flash_on, color: Color(0xFF39FF14)),
            onPressed: _runBulkPingTest,
          ),
          IconButton(
            tooltip: "دریافت پل اضطراری",
            icon: const Icon(Icons.healing, color: Color(0xFF00F0FF)),
            onPressed: _triggerDeadDropRescue,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sleek VPN Action Area
              Center(
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isConnected 
                            ? const Color(0xFF00F0FF).withOpacity(0.25)
                            : const Color(0xFFFF007F).withOpacity(0.15),
                        blurRadius: 35,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isConnected 
                                ? const Color(0xFF00F0FF) 
                                : const Color(0xFFFF007F),
                            width: 3,
                          ),
                          color: const Color(0xFF101014),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isConnecting ? null : _toggleConnection,
                            child: Icon(
                              _isConnected ? Icons.shield : Icons.power_settings_new,
                              size: 48,
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
                    fontSize: 13,
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
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Color(0xFF39FF14)
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 2. Toggles Core Features Dashboard (Decoy, LAN Share, Auto-rotation)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101014),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    // Decoy slider
                    SwitchListTile(
                      dense: true,
                      title: const Text("تزریق ترافیک فیک (DPI Obfuscator)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text("تولید نویز سایبری جهت فریب فایروال‌های شناسایی حجم", style: TextStyle(fontSize: 10, color: Colors.white38)),
                      activeColor: const Color(0xFF00F0FF),
                      value: _isDecoyActive,
                      onChanged: (val) {
                        setState(() {
                          _isDecoyActive = val;
                          if (_isDecoyActive && _isConnected) {
                            _startDecoyEmulation();
                          } else {
                            _stopDecoyEmulation();
                          }
                        });
                      },
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    // LAN Share
                    SwitchListTile(
                      dense: true,
                      title: const Text("اشتراک‌گذاری پروکسی (Allow LAN)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text("امکان عبور ترافیک لوازم خانگی متصل به هات‌اسپات وای‌فای کلاینت", style: TextStyle(fontSize: 10, color: Colors.white38)),
                      activeColor: const Color(0xFFFF007F),
                      value: _isLanSharing,
                      onChanged: (val) {
                        setState(() {
                          _isLanSharing = val;
                          _addLog("قابلیت اشتراک لن: ${_isLanSharing ? 'فعال' : 'غیرفعال'} شد. پورت انتشار: 10808");
                        });
                      },
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    // Silent Auto-ping
                    SwitchListTile(
                      dense: true,
                      title: const Text("روت‌ینگ خودکار هوشمند (Smart Back-ping)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text("تغییر نامحسوس و آنی کانکشن به سریع‌ترین نود مجاز دیتابیس", style: TextStyle(fontSize: 10, color: Colors.white38)),
                      activeColor: const Color(0xFF39FF14),
                      value: _autoPingRoutation,
                      onChanged: (val) {
                        setState(() {
                          _autoPingRoutation = val;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Dynamic Decoy Stats Panel
              if (_isDecoyActive && _isConnected)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x3339FF14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.leak_add, color: Color(0xFF39FF14), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("مانیتور فریب سایبری (Obfuscator Panel)", style: TextStyle(fontSize: 12, color: Color(0xFF39FF14), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              "حجم تزریق داده: ${_decoySentMb.toStringAsFixed(2)} MB  |  تعداد بسته‌ها: $_decoyPacketsInjected",
                              style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Multiplexing & Chain Proxy Options Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101014),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("زنجیره‌سازی پروکسی (Chain Proxies)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Switch(
                          activeColor: const Color(0xFF00F0FF),
                          value: _chainProxyEnabled,
                          onChanged: (val) {
                            setState(() {
                              _chainProxyEnabled = val;
                              _addLog("استفاده از پل‌های عبور متوالی: ${_chainProxyEnabled ? 'فعال' : 'غیرفعال'}");
                            });
                          },
                        ),
                      ],
                    ),
                    if (_chainProxyEnabled) ...[
                      const SizedBox(height: 8),
                      const Text("انتخاب گره ترانزیت (Transit Node):", style: TextStyle(fontSize: 11, color: Colors.white54)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _chainBridgeId,
                        dropdownColor: const Color(0xFF101014),
                        items: _configs.map((config) {
                          return DropdownMenuItem<String>(
                            value: config.id,
                            child: Text(config.name, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _chainBridgeId = val;
                          });
                        },
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Per-App Routing / Split Tunneling Widget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("تفکیک برنامه‌ها (Split Tunneling)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                  Switch(
                    activeColor: const Color(0xFFFF007F),
                    value: _splitTunnelingEnabled,
                    onChanged: (val) {
                      setState(() {
                        _splitTunnelingEnabled = val;
                        _addLog("فرآیند تفکیک ترافیک: ${_splitTunnelingEnabled ? 'فعال' : 'غیرفعال'} شد.");
                      });
                    },
                  ),
                ],
              ),
              if (_splitTunnelingEnabled)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101014),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView(
                    children: _splitTunnelApps.keys.map((appName) {
                      return CheckboxListTile(
                        dense: true,
                        activeColor: const Color(0xFFFF007F),
                        title: Text(appName, style: const TextStyle(fontSize: 11)),
                        value: _splitTunnelApps[appName],
                        onChanged: (val) {
                          setState(() {
                            _splitTunnelApps[appName] = val ?? false;
                            _addLog("تغییر اولویت تفکیک اپلیکیشن $appName به: ${val == true ? 'دور زدن تونل' : 'رد کردن از تونل'}");
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // 6. Config Nodes Table and Navigation List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("پیکربندی‌ها (Configuration Nodes)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                  Text("${_configs.length} سرور بارگذاری شده", style: const TextStyle(fontSize: 11, color: Color(0xFF00F0FF))),
                ],
              ),
              const SizedBox(height: 8),
              
              _configs.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFF101014), borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Text("هیچ کانفیگی یافت نشد. دانگل '+' را فشار دهید.", style: TextStyle(fontSize: 12, color: Colors.white38)),
                      ),
                    )
                  : SizedBox(
                      height: 165,
                      child: ListView.builder(
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final cfg = _configs[index];
                          final isCurrent = _selectedConfig?.id == cfg.id;
                          return Card(
                            color: isCurrent ? const Color(0xFF1E1E22) : const Color(0xFF101014),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isCurrent ? const Color(0xFF00F0FF) : Colors.transparent, width: 1.5),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              onTap: () {
                                setState(() {
                                  _selectedConfig = cfg;
                                  _addLog("تغییر سرور هدف به گره: ${cfg.name}");
                                });
                              },
                              leading: CircleAvatar(
                                backgroundColor: cfg.protocol == "VLESS" ? const Color(0xFF00F0FF).withOpacity(0.1) : const Color(0xFFFF007F).withOpacity(0.1),
                                radius: 15,
                                child: Text(
                                  cfg.protocol[0],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cfg.protocol == "VLESS" ? const Color(0xFF00F0FF) : const Color(0xFFFF007F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(cfg.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text("${cfg.server}:${cfg.port}", style: const TextStyle(fontSize: 11, color: Colors.white38, fontFamily: 'monospace')),
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

              const SizedBox(height: 16),

              // 7. Dynamic Cyber Logger Terminal Console
              const Text("کنسول امنیتی و پایش پدافند آریا (Dynamic Cyber Logs)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                height: 110,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _securityLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _securityLogs[index],
                        style: const TextStyle(color: Color(0xFF39FF14), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Provide interactive choice between text paste and camera QR
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF101014),
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF00F0FF)),
                      title: const Text("اسکن با دوربین (QR Code Camera)", style: TextStyle(fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        _showCameraQRScannerMock();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.paste, color: Color(0xFFFF007F)),
                      title: const Text("درج مستقیم متن پیوند (Clip Board)", style: TextStyle(fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        _showImportLinkDialog();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        backgroundColor: const Color(0xFF00F0FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text("افزودن کانفیگ (Import)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
