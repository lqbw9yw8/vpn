import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Represents an imported VPN configuration profile.
class VpnConfig {
  final String id;
  final String name;
  final String protocol; // VLESS, Trojan, VMess, Hysteria2
  final String server;
  final int port;
  final String uuid; // Password or UUID
  final String sni;
  int? lastPingMs;
  bool isDead;

  VpnConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.uuid,
    required this.sni,
    this.lastPingMs,
    this.isDead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol,
    'server': server,
    'port': port,
    'uuid': uuid,
    'sni': sni,
    'lastPingMs': lastPingMs,
    'isDead': isDead,
  };

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    return VpnConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: json['protocol'] as String,
      server: json['server'] as String,
      port: json['port'] as int,
      uuid: json['uuid'] as String,
      sni: json['sni'] as String,
      lastPingMs: json['lastPingMs'] as int?,
      isDead: json['isDead'] as bool? ?? false,
    );
  }
}

/// Dynamic Configuration Manager (V2RayNG Style Storage and Multi-protocol link parser).
/// Written with high fidelity to handle raw vless:// and trojan:// subscription links.
class ConfigManager {
  static final List<VpnConfig> _inMemoryConfigs = [
    VpnConfig(
      id: "cf-primary-vless",
      name: "آریا پرسرعت اصلی (Aria Primary VLESS)",
      protocol: "VLESS",
      server: "104.16.85.20",
      port: 443,
      uuid: "7c126589-32cc-4971-8975-ad438349fa89",
      sni: "telecom.cf.com",
    ),
    VpnConfig(
      id: "cf-backup-trojan",
      name: "آریا پشتیبان تروجان (Aria Backup Trojan)",
      protocol: "Trojan",
      server: "104.17.210.9",
      port: 443,
      uuid: "9f8e7d6c-5b4a-3f2e-1d0c-9a8b7c6d5e4f",
      sni: "mci.ir",
    )
  ];

  /// Get all imported configurations
  static List<VpnConfig> getConfigs() {
    return _inMemoryConfigs;
  }

  /// Bulk Delete: Clears all stored configs
  static void clearAllConfigs() {
    _inMemoryConfigs.clear();
  }

  /// Adds a new config profile
  static void addConfig(VpnConfig config) {
    _inMemoryConfigs.add(config);
  }

  /// Smart Cleanup: Instantly removes all configs marked as dead or timeout
  static void removeDeadConfigs() {
    _inMemoryConfigs.removeWhere((config) => config.isDead || (config.lastPingMs == null || config.lastPingMs! > 1500));
  }

  /// Real Multi-threaded Loop Ping Test.
  /// Loops through every config, runs a secure TCP handshake/ping and measures speed.
  static Future<void> performRealPingTest({
    required Function(String configId, int? ping) onSingleProgress,
  }) async {
    final List<Future<void>> pingTasks = [];

    for (var config in _inMemoryConfigs) {
      final task = Future(() async {
        try {
          final Stopwatch stopwatch = Stopwatch()..start();
          
          // Connect using standard raw TCP socket check with 1.8 seconds timeout
          final Socket socket = await Socket.connect(
            config.server,
            config.port,
            timeout: const Duration(milliseconds: 1800),
          );
          
          stopwatch.stop();
          socket.destroy();

          final int latency = stopwatch.elapsedMilliseconds;
          config.lastPingMs = latency;
          config.isDead = latency > 1500;
          onSingleProgress(config.id, latency);
        } catch (e) {
          config.lastPingMs = null;
          config.isDead = true;
          onSingleProgress(config.id, null);
        }
      });
      pingTasks.add(task);
    }

    await Future.wait(pingTasks);
  }

  /// Adaptive Parsers: Fully decodes VLESS/Trojan Share Links from system clipboard
  /// Format Example: vless://uuid@server:port?encryption=none&security=reality&sni=sni.com#Name
  static VpnConfig? parseShareLink(String rawLink) {
    try {
      final String trimmed = rawLink.trim();
      if (!trimmed.contains("://")) return null;

      final Uri uri = Uri.parse(trimmed);
      final String scheme = uri.scheme.toUpperCase();
      
      if (scheme == "VLESS") {
        final String uuid = uri.userInfo;
        final String server = uri.host;
        final int port = uri.port;
        
        final Map<String, String> queryParams = uri.queryParameters;
        final String sni = queryParams['sni'] ?? queryParams['peer'] ?? server;
        
        String name = "VLESS_" + server;
        if (uri.fragment.isNotEmpty) {
          name = Uri.decodeComponent(uri.fragment);
        }

        final String id = "imported-vless-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}";
        return VpnConfig(
          id: id,
          name: name,
          protocol: "VLESS",
          server: server,
          port: port,
          uuid: uuid,
          sni: sni,
        );
      } else if (scheme == "TROJAN") {
        final String uuid = uri.userInfo;
        final String server = uri.host;
        final int port = uri.port;
        
        final Map<String, String> queryParams = uri.queryParameters;
        final String sni = queryParams['sni'] ?? queryParams['peer'] ?? server;
        
        String name = "Trojan_" + server;
        if (uri.fragment.isNotEmpty) {
          name = Uri.decodeComponent(uri.fragment);
        }

        final String id = "imported-trojan-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}";
        return VpnConfig(
          id: id,
          name: name,
          protocol: "Trojan",
          server: server,
          port: port,
          uuid: uuid,
          sni: sni,
        );
      }
    } catch (_) {
      // Return null on malformed structures
    }
    return null;
  }
}
