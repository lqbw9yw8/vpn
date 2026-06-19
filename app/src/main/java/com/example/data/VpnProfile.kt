package com.example.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "vpn_profiles")
data class VpnProfile(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val server: String,
    val port: Int,
    val uuid: String,
    val protocol: String, // VLESS, VMess, Trojan, Shadowsocks, Hysteria2
    val tls: Boolean = true,
    val sni: String = "",
    val path: String = "",
    val latency: Int? = null,
    val fragmentMin: Int = 10,
    val fragmentMax: Int = 100,
    val tcpWindow: Int = 65536,
    val tlsPadding: Boolean = true,
    val pqcEnabled: Boolean = false,
    val isRescueNode: Boolean = false
) {
    fun toShareUri(): String {
        return "$protocol://$uuid@$server:$port?sni=$sni&tls=${if (tls) "1" else "0"}&path=$path#$name"
    }

    companion object {
        fun fromShareUri(uri: String): VpnProfile? {
            return try {
                val protoPart = uri.substringBefore("://")
                val rest = uri.substringAfter("://")
                val userAndServer = rest.substringBefore("?")
                val queryParams = rest.substringAfter("?", "").substringBefore("#")
                val namePart = rest.substringAfter("#", "Imported Node")

                val uuid = userAndServer.substringBefore("@")
                val serverPort = userAndServer.substringAfter("@")
                val server = serverPort.substringBefore(":")
                val port = serverPort.substringAfter(":", "443").toIntOrNull() ?: 443

                var sni = ""
                var path = ""
                var tls = true

                queryParams.split("&").forEach { param ->
                    val pair = param.split("=")
                    if (pair.size == 2) {
                        when (pair[0]) {
                            "sni" -> sni = pair[1]
                            "path" -> path = pair[1]
                            "tls" -> tls = pair[1] == "1"
                        }
                    }
                }

                VpnProfile(
                    name = namePart,
                    server = server,
                    port = port,
                    uuid = uuid,
                    protocol = protoPart.uppercase(),
                    tls = tls,
                    sni = sni,
                    path = path
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}
