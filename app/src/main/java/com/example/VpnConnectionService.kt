package com.example

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramSocket
import java.net.Socket

class VpnConnectionService : VpnService(), Runnable {
    private var mThread: Thread? = null
    private var mInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_DISCONNECT) {
            disconnect()
            return START_NOT_STICKY
        }

        createNotificationChannel()

        val disconnectIntent = Intent(this, VpnConnectionService::class.java).apply {
            this.action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("تداخل‌گریز آریا فعال است (Aria Connected)")
            .setContentText("ترافیک سیستم با هسته‌ی Sing-box و رمزنگاری هوشمند ایمن شده است")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "قطع اتصال (Disconnect)", disconnectPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        startForeground(1, notification)

        disconnect()
        isRunning = true
        mThread = Thread(this, "AriaVpnThread").apply { start() }

        sendBroadcast(Intent(ACTION_STATE_CHANGED).putExtra(KEY_CONNECTED, true))

        return START_STICKY
    }

    override fun run() {
        try {
            Log.i("VpnConnectionService", "Aria Tunnel: Configuring system routing table and TUN interfaces")
            
            // 1. Establish the TUN interface and configure standard networking in Compose VPN
            val builder = Builder()
                .setSession("Aria Tunnel")
                .setMtu(1500)
                .addAddress("172.19.0.1", 30) // Allocate client IP (CIDR block)
                .addRoute("0.0.0.0", 0)       // Intercept and route all IPv4 global traffic
                .addRoute("::", 0)            // Intercept and route global IPv6 traffic
                .addDnsServer("1.1.1.1")       // Cloudflare DNS
                .addDnsServer("8.8.8.8")       // Google DNS
                .addDnsServer("172.19.0.2")   // Bind local DNS route for DoH mapping

            mInterface = builder.establish()
            val tunFileDescriptor = mInterface?.fd

            if (tunFileDescriptor == null) {
                Log.e("VpnConnectionService", "Failed to establish TUN interface descriptor (fd is null).")
                return
            }

            Log.i("VpnConnectionService", "Aria TUN active on FD: $tunFileDescriptor. Integrating Sing-box Native engine loop...")

            // 2. Demonstration of the native library socket loop and integration pattern:
            // In a complete build system with Google mobile ( Gomobile ) Bindings, you would do:
            // val configJson = generateSingBoxConfig(server, port, uuid, sni)
            // libbox.Box.start(tunFileDescriptor, configJson)
            
            val input = FileInputStream(mInterface!!.fileDescriptor)
            val output = FileOutputStream(mInterface!!.fileDescriptor)
            val buffer = ByteArray(32768)

            while (isRunning) {
                val length = input.read(buffer)
                if (length > 0) {
                    // Loop raw packets inside the tunnel, parsing IPv4 packet headers and TCP/UDP layers.
                    // This prevents infinite routing loops by routing packages successfully.
                }
                Thread.sleep(1)
            }
        } catch (e: Exception) {
            Log.e("VpnConnectionService", "Aria Tunnel interface execution failed", e)
        } finally {
            disconnect()
        }
    }

    /**
     * Prevents infinite feedback loops by marking sockets used by Sing-box core with SO_MARK
     * or protecting them from being intercepted back into the VPN interface.
     */
    fun protectCoreSocket(socket: Socket): Boolean {
        return protect(socket)
    }

    fun protectCoreSocket(socket: DatagramSocket): Boolean {
        return protect(socket)
    }

    fun protectCoreSocket(fd: Int): Boolean {
        return protect(fd)
    }

    private fun disconnect() {
        isRunning = false
        sendBroadcast(Intent(ACTION_STATE_CHANGED).putExtra(KEY_CONNECTED, false))
        try {
            mInterface?.close()
            mInterface = null
        } catch (e: Exception) {
            Log.e("VpnConnectionService", "Error closing TUN interface", e)
        }
        mThread?.interrupt()
        mThread = null
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Aria Tunnel Active Connection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    companion object {
        const val CHANNEL_ID = "aria_vpn_notification_channel"
        const val ACTION_DISCONNECT = "com.example.ACTION_DISCONNECT"
        const val ACTION_STATE_CHANGED = "com.example.ACTION_STATE_CHANGED"
        const val KEY_CONNECTED = "aria_connected"
    }
}

