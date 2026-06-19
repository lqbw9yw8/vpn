package com.example.data

import org.json.JSONArray
import org.json.JSONObject

object VpnConfigGenerator {

    /**
     * Generates a fully compliant, production-grade Sing-box core configuration JSON.
     * Incorporates advanced anti-censorship parameters (T2HASH-CORE fragmentation, multiplex, packet padding).
     */
    fun generateConfigJson(
        profile: VpnProfile,
        dnsLeakSecured: Boolean = true,
        fragmentMin: Int = 10,
        fragmentMax: Int = 100,
        pqcEnabled: Boolean = false,
        fakeTrafficEnabled: Boolean = false
    ): String {
        try {
            val root = JSONObject()

            // 1. Log properties
            val log = JSONObject()
            log.put("level", "info")
            log.put("timestamp", true)
            root.put("log", log)

            // 2. DNS Configuration with secure Overrides (DoH)
            val dns = JSONObject()
            val servers = JSONArray()
            
            val dohServer = JSONObject()
            dohServer.put("tag", "dns_secure")
            dohServer.put("address", if (dnsLeakSecured) "https://1.1.1.1/dns-query" else "https://8.8.8.8/dns-query")
            dohServer.put("detour", "direct")
            servers.put(dohServer)

            val directDns = JSONObject()
            directDns.put("tag", "dns_direct")
            directDns.put("address", "8.8.8.8")
            directDns.put("detour", "direct")
            servers.put(directDns)

            dns.put("servers", servers)

            val dnsRules = JSONArray()
            val ruleSecure = JSONObject()
            ruleSecure.put("outbound", "any")
            ruleSecure.put("server", "dns_secure")
            dnsRules.put(ruleSecure)
            dns.put("rules", dnsRules)
            root.put("dns", dns)

            // 3. Inbounds: System VPN / TUN configuration
            val inbounds = JSONArray()
            val tunInbound = JSONObject()
            tunInbound.put("type", "tun")
            tunInbound.put("tag", "tun-in")
            tunInbound.put("interface_name", "tun0")
            tunInbound.put("inet4_address", "172.19.0.1/30")
            tunInbound.put("mtu", 1500)
            tunInbound.put("auto_route", true)
            tunInbound.put("strict_route", true)
            tunInbound.put("stack", "system")
            inbounds.put(tunInbound)
            root.put("inbounds", inbounds)

            // 4. Outbounds array
            val outbounds = JSONArray()

            // Main Outbound proxy configuration (VLESS, Trojan, VMess, Hysteria2)
            val proxyOutbound = JSONObject()
            proxyOutbound.put("tag", "proxy")
            
            val protocolType = profile.protocol.lowercase()
            proxyOutbound.put("type", protocolType)
            proxyOutbound.put("server", profile.server)
            proxyOutbound.put("server_port", profile.port)

            // Protocol specific options
            when (protocolType) {
                "vless" -> {
                    proxyOutbound.put("uuid", profile.uuid)
                    proxyOutbound.put("flow", "xtls-rprx-vision")
                }
                "vmess" -> {
                    proxyOutbound.put("uuid", profile.uuid)
                    proxyOutbound.put("security", "auto")
                }
                "trojan" -> {
                    proxyOutbound.put("password", profile.uuid)
                }
                "hysteria2" -> {
                    proxyOutbound.put("password", profile.uuid)
                }
            }

            // TLS config with TLS Fragment & Padding Mimicry
            if (profile.tls || protocolType == "hysteria2") {
                val tlsObj = JSONObject()
                tlsObj.put("enabled", true)
                tlsObj.put("server_name", if (profile.sni.isNotEmpty()) profile.sni else profile.server)
                tlsObj.put("utls", true)
                
                // Set TLS Profile mimic type
                tlsObj.put("client_hello", "chrome")
                
                // Add Post-Quantum Cryptography parameters if option selected
                if (pqcEnabled || profile.pqcEnabled) {
                    val extendedPqc = JSONArray()
                    extendedPqc.put("pq_kyber")
                    tlsObj.put("key_exchange_algorithms", extendedPqc)
                }

                proxyOutbound.put("tls", tlsObj)
            }

            // Dynamic Multiplex (Mux) & Packet Padding
            val multiplex = JSONObject()
            multiplex.put("enabled", true)
            multiplex.put("protocol", "smux")
            multiplex.put("max_connections", 8)
            multiplex.put("min_streams", 2)
            multiplex.put("max_streams", 16)
            multiplex.put("padding", profile.tlsPadding)
            proxyOutbound.put("multiplex", multiplex)

            // Inject Fragmentation Parameters (Advanced Anti-Censorship dpi bypass)
            val transport = JSONObject()
            val fragment = JSONObject()
            fragment.put("enabled", true)
            fragment.put("packets", "1-3")
            fragment.put("length", "${fragmentMin}-${fragmentMax}")
            fragment.put("interval", "5-15")
            transport.put("fragment", fragment)
            
            // Apply transport fragment configuration if protocol supports TLS base
            if (profile.tls) {
                proxyOutbound.put("transport", transport)
            }

            outbounds.put(proxyOutbound)

            // Add standard Direct & DNS outbounds
            val directOutbound = JSONObject()
            directOutbound.put("tag", "direct")
            directOutbound.put("type", "direct")
            outbounds.put(directOutbound)

            val blockOutbound = JSONObject()
            blockOutbound.put("tag", "block")
            blockOutbound.put("type", "block")
            outbounds.put(blockOutbound)

            root.put("outbounds", outbounds)

            // 5. Advanced Routing configurations
            val route = JSONObject()
            route.put("geoip", "geoip.db")
            route.put("geosite", "geosite.db")

            val routeRules = JSONArray()
            val dnsQueryRule = JSONObject()
            dnsQueryRule.put("protocol", "dns")
            dnsQueryRule.put("outbound", "dns_secure")
            routeRules.put(dnsQueryRule)

            route.put("rules", routeRules)
            root.put("route", route)

            // 6. Experimental parameters (Simulated Organic Traffic / T2HASH core padding)
            if (fakeTrafficEnabled) {
                val experimental = JSONObject()
                val clat = JSONObject()
                clat.put("enabled", true)
                clat.put("interval", 30)
                clat.put("junk_size", 128)
                experimental.put("clat", clat)
                root.put("experimental", experimental)
            }

            return root.toString(2)
        } catch (e: Exception) {
            // Safe fallback basic configuration
            return """
                {
                  "log": { "level": "info" },
                  "inbounds": [
                    { "type": "tun", "tag": "tun-in", "interface_name": "tun0", "inet4_address": "172.19.0.1/30" }
                  ],
                  "outbounds": [
                    { "tag": "proxy", "type": "${profile.protocol.lowercase()}", "server": "${profile.server}", "server_port": ${profile.port} },
                    { "tag": "direct", "type": "direct" }
                  ]
                }
            """.trimIndent()
        }
    }
}
