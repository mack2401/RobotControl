package com.ibots.ibots_remote_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ibots.ibots_remote_app/wifi"
    private val SENSOR_CHANNEL = "com.ibots.ibots_remote_app/sensors"
    private val PERMISSION_REQUEST_CODE = 4412
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var methodChannel: MethodChannel? = null
    private var sensorChannel: MethodChannel? = null
    private var sensorManager: SensorManager? = null
    private var sensorListener: SensorEventListener? = null
    private var lastSensorEmitTime = 0L
    private var persistentTcpSocket: java.net.Socket? = null
    private var tcpWriter: java.io.OutputStreamWriter? = null
    private var tcpHost: String? = null
    private var tcpPort: Int = 8080
    private var lastWorkingFormat: String? = null

    private fun startSensors() {
        if (sensorManager == null) {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        }
        val sm = sensorManager ?: return
        stopSensors()

        val rotSensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val accelSensor = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        val rotationMatrix = FloatArray(9)
        val orientationAngles = FloatArray(3)

        sensorListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val now = System.currentTimeMillis()
                // Throttle sensor emits to ~35Hz for smooth 60fps Flutter animations
                if (now - lastSensorEmitTime < 28) return
                lastSensorEmitTime = now

                var pitch = 0.0
                var roll = 0.0
                var yaw = 0.0

                if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                    SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                    SensorManager.getOrientation(rotationMatrix, orientationAngles)
                    yaw = Math.toDegrees(orientationAngles[0].toDouble())
                    pitch = Math.toDegrees(orientationAngles[1].toDouble())
                    roll = Math.toDegrees(orientationAngles[2].toDouble())
                } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                    val ax = event.values[0].toDouble()
                    val ay = event.values[1].toDouble()
                    val az = event.values[2].toDouble()
                    pitch = Math.toDegrees(Math.atan2(ay, Math.sqrt(ax * ax + az * az)))
                    roll = Math.toDegrees(Math.atan2(-ax, az))
                }

                runOnUiThread {
                    sensorChannel?.invokeMethod("onSensorUpdate", mapOf(
                        "pitch" to pitch,
                        "roll" to roll,
                        "yaw" to yaw
                    ))
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        if (rotSensor != null) {
            sm.registerListener(sensorListener, rotSensor, SensorManager.SENSOR_DELAY_GAME)
        } else if (accelSensor != null) {
            sm.registerListener(sensorListener, accelSensor, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    private fun stopSensors() {
        sensorListener?.let {
            try {
                sensorManager?.unregisterListener(it)
            } catch (_: Exception) {}
        }
        sensorListener = null
    }

    @Synchronized
    private fun getOrConnectTcp(connectivityManager: ConnectivityManager?, host: String, port: Int): java.io.OutputStreamWriter? {
        val s = persistentTcpSocket
        if (s != null && s.isConnected && !s.isClosed && tcpHost == host && tcpPort == port && tcpWriter != null) {
            return tcpWriter
        }
        closeTcp()

        var wifiNetwork: Network? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && connectivityManager != null) {
            // Priority 1: Check for network with 192.168.4.x (ESP SoftAP)
            for (net in connectivityManager.allNetworks) {
                val lp = connectivityManager.getLinkProperties(net)
                val hasEspIp = lp?.linkAddresses?.any { 
                    it.address.hostAddress?.startsWith("192.168.4.") == true 
                } == true
                if (hasEspIp) {
                    wifiNetwork = net
                    break
                }
            }
            // Priority 2: Any Wi-Fi transport network
            if (wifiNetwork == null) {
                for (net in connectivityManager.allNetworks) {
                    val caps = connectivityManager.getNetworkCapabilities(net)
                    if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                        wifiNetwork = net
                        break
                    }
                }
            }
            // Bind process so all routes prefer this Wi-Fi
            if (wifiNetwork != null) {
                try {
                    connectivityManager.bindProcessToNetwork(wifiNetwork)
                } catch (_: Exception) {}
            }
        }

        try {
            val newSocket = java.net.Socket()
            if (wifiNetwork != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    wifiNetwork.bindSocket(newSocket)
                } catch (_: Exception) {}
            }
            newSocket.tcpNoDelay = true
            newSocket.connect(java.net.InetSocketAddress(host, port), 2500)
            persistentTcpSocket = newSocket
            tcpHost = host
            tcpPort = port
            tcpWriter = java.io.OutputStreamWriter(newSocket.getOutputStream(), java.nio.charset.StandardCharsets.UTF_8)

            startTcpReader(newSocket)
            android.util.Log.d("MainActivity", "Connected persistent TCP to $host:$port")
            return tcpWriter
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to connect TCP to $host:$port: ${e.message}")
            closeTcp()
            // Fallback attempt without explicit socket binding
            if (wifiNetwork != null) {
                try {
                    val fallbackSocket = java.net.Socket()
                    fallbackSocket.tcpNoDelay = true
                    fallbackSocket.connect(java.net.InetSocketAddress(host, port), 2500)
                    persistentTcpSocket = fallbackSocket
                    tcpHost = host
                    tcpPort = port
                    tcpWriter = java.io.OutputStreamWriter(fallbackSocket.getOutputStream(), java.nio.charset.StandardCharsets.UTF_8)
                    startTcpReader(fallbackSocket)
                    android.util.Log.d("MainActivity", "Connected fallback TCP to $host:$port")
                    return tcpWriter
                } catch (ex: Exception) {
                    android.util.Log.e("MainActivity", "Fallback TCP failed: ${ex.message}")
                    closeTcp()
                }
            }
            return null
        }
    }

    private fun startTcpReader(socket: java.net.Socket) {
        Thread {
            try {
                val reader = java.io.BufferedReader(java.io.InputStreamReader(socket.getInputStream(), java.nio.charset.StandardCharsets.UTF_8))
                val buffer = CharArray(1024)
                while (!socket.isClosed && socket.isConnected) {
                    val read = reader.read(buffer, 0, buffer.size)
                    if (read == -1) break
                    val text = String(buffer, 0, read)
                    runOnUiThread {
                        methodChannel?.invokeMethod("onDataReceived", text)
                    }
                }
            } catch (_: Exception) {}
            finally {
                if (persistentTcpSocket == socket) {
                    closeTcp()
                }
            }
        }.apply { isDaemon = true; start() }
    }

    @Synchronized
    private fun closeTcp() {
        try {
            tcpWriter?.close()
        } catch (_: Exception) {}
        try {
            persistentTcpSocket?.close()
        } catch (_: Exception) {}
        tcpWriter = null
        persistentTcpSocket = null
        tcpHost = null
    }

    override fun onPause() {
        stopSensors()
        super.onPause()
    }

    override fun onDestroy() {
        stopSensors()
        closeTcp()
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val sChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SENSOR_CHANNEL)
        sensorChannel = sChannel
        sChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSensors" -> {
                    startSensors()
                    result.success(true)
                }
                "stopSensors" -> {
                    stopSensors()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

            when (call.method) {
                "checkPermissions" -> {
                    val fineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    var nearbyWifi = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        nearbyWifi = ContextCompat.checkSelfPermission(this, Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(fineLocation && nearbyWifi)
                }

                "requestPermissions" -> {
                    val perms = mutableListOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
                    }
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(this, perms.toTypedArray(), PERMISSION_REQUEST_CODE)
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "isWifiEnabled" -> {
                    result.success(wifiManager?.isWifiEnabled ?: false)
                }

                "isLocationEnabled" -> {
                    val lm = applicationContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    var locEnabled = false
                    if (lm != null) {
                        locEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            lm.isLocationEnabled
                        } else {
                            @Suppress("DEPRECATION")
                            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                        }
                    }
                    result.success(locEnabled)
                }

                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "getPhoneSavedWifiNetworks" -> {
                    val list = mutableListOf<Map<String, Any>>()
                    if (wifiManager != null) {
                        try {
                            @Suppress("DEPRECATION")
                            val configs = wifiManager.configuredNetworks
                            android.util.Log.d("MainActivity", "wifiManager.configuredNetworks count: ${configs?.size}")
                            if (configs != null) {
                                for (config in configs) {
                                    var s = config.SSID ?: ""
                                    if (s.startsWith("\"") && s.endsWith("\"") && s.length >= 2) {
                                        s = s.substring(1, s.length - 1)
                                    }
                                    if (s.isNotEmpty() && s != "<unknown ssid>") {
                                        list.add(hashMapOf(
                                            "ssid" to s,
                                            "bssid" to (config.BSSID ?: ""),
                                            "networkId" to config.networkId
                                        ))
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Error getting configuredNetworks: ${e.message}")
                        }
                    }
                    result.success(list)
                }

                "openWifiSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val intent = Intent(Settings.Panel.ACTION_WIFI)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("ERROR", ex.message, null)
                        }
                    }
                }

                "connectToWifi" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""

                    if (ssid.isEmpty()) {
                        result.error("INVALID_SSID", "SSID cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    if (connectivityManager == null) {
                        result.error("UNAVAILABLE", "ConnectivityManager is unavailable", null)
                        return@setMethodCallHandler
                    }

                    // Clean up any existing connection callback first
                    activeNetworkCallback?.let {
                        try {
                            connectivityManager.unregisterNetworkCallback(it)
                        } catch (_: Exception) {}
                        activeNetworkCallback = null
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        try {
                            // 1. Suggest network credentials to system
                            if (wifiManager != null) {
                                try {
                                    val suggestionBuilder = WifiNetworkSuggestion.Builder().setSsid(ssid)
                                    if (password.isNotEmpty()) {
                                        suggestionBuilder.setWpa2Passphrase(password)
                                    }
                                    wifiManager.addNetworkSuggestions(listOf(suggestionBuilder.build()))
                                } catch (_: Exception) {}
                            }

                            // 2. Request direct peer-to-peer / AP connection via WifiNetworkSpecifier
                            val specifierBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
                            if (password.isNotEmpty()) {
                                if (password.length in 8..63) {
                                    specifierBuilder.setWpa2Passphrase(password)
                                } else {
                                    result.error("INVALID_PASSWORD", "Password must be at least 8 characters", null)
                                    return@setMethodCallHandler
                                }
                            }
                            val specifier = specifierBuilder.build()

                            val request = NetworkRequest.Builder()
                                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                                .setNetworkSpecifier(specifier)
                                .build()

                            var responded = false
                            val timeoutHandler = Handler(Looper.getMainLooper())
                            val callback = object : ConnectivityManager.NetworkCallback() {
                                override fun onAvailable(network: Network) {
                                    super.onAvailable(network)
                                    try {
                                        connectivityManager.bindProcessToNetwork(network)
                                    } catch (_: Exception) {}
                                    if (!responded) {
                                        responded = true
                                        timeoutHandler.removeCallbacksAndMessages(null)
                                        runOnUiThread {
                                            result.success(true)
                                        }
                                    }
                                }

                                override fun onUnavailable() {
                                    super.onUnavailable()
                                    if (!responded) {
                                        responded = true
                                        timeoutHandler.removeCallbacksAndMessages(null)
                                        runOnUiThread {
                                            result.success(false)
                                        }
                                    }
                                }
                            }

                            activeNetworkCallback = callback
                            connectivityManager.requestNetwork(request, callback)

                            // 25 second fallback timeout in case user ignores prompt
                            timeoutHandler.postDelayed({
                                if (!responded) {
                                    responded = true
                                    runOnUiThread {
                                        result.success(false)
                                    }
                                }
                            }, 25000)

                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        // Legacy Android < 10
                        @Suppress("DEPRECATION")
                        try {
                            val conf = android.net.wifi.WifiConfiguration()
                            conf.SSID = "\"$ssid\""
                            if (password.isNotEmpty()) {
                                conf.preSharedKey = "\"$password\""
                            } else {
                                conf.allowedKeyManagement.set(android.net.wifi.WifiConfiguration.KeyMgmt.NONE)
                            }
                            val netId = wifiManager?.addNetwork(conf) ?: -1
                            if (netId != -1) {
                                wifiManager?.disconnect()
                                wifiManager?.enableNetwork(netId, true)
                                wifiManager?.reconnect()
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }

                "bindProcessToWifi" -> {
                    if (connectivityManager == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val networks = connectivityManager.allNetworks
                            var bound = false
                            for (net in networks) {
                                val caps = connectivityManager.getNetworkCapabilities(net)
                                if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                    connectivityManager.bindProcessToNetwork(net)
                                    bound = true
                                    break
                                }
                            }
                            result.success(bound)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "connectTcp" -> {
                    val host = call.argument<String>("host") ?: "192.168.4.1"
                    val port = call.argument<Int>("port") ?: 8080
                    if (port == 80) {
                        // Port 80 is HTTP REST WebServer. DO NOT open a persistent TCP socket!
                        // A raw TCP socket on port 80 blocks the ESP32 WebServer client slot.
                        Thread {
                            var reachable = false
                            try {
                                val url = java.net.URL("http://$host:$port/")
                                val conn = url.openConnection() as java.net.HttpURLConnection
                                conn.connectTimeout = 1200
                                conn.readTimeout = 1200
                                conn.requestMethod = "GET"
                                conn.setRequestProperty("Connection", "close")
                                val code = conn.responseCode
                                try { conn.inputStream?.close() } catch (_: Exception) {}
                                conn.disconnect()
                                reachable = (code in 200..499)
                            } catch (e: Exception) {
                                try {
                                    val pingSock = java.net.Socket()
                                    pingSock.connect(java.net.InetSocketAddress(host, port), 800)
                                    pingSock.close()
                                    reachable = true
                                } catch (_: Exception) {}
                            }
                            runOnUiThread {
                                result.success(reachable)
                            }
                        }.start()
                    } else {
                        Thread {
                            val writer = getOrConnectTcp(connectivityManager, host, port)
                            runOnUiThread {
                                result.success(writer != null)
                            }
                        }.start()
                    }
                }

                "disconnectTcp" -> {
                    lastWorkingFormat = null
                    closeTcp()
                    result.success(true)
                }

                "sendWifiCommand" -> {
                    val host = call.argument<String>("host") ?: "192.168.4.1"
                    val port = call.argument<Int>("port") ?: 8080
                    val cmd = call.argument<String>("cmd") ?: ""
                    val path = call.argument<String>("path") ?: "/cmd?val="

                    Thread {
                        var sent = false
                        val trimmedCmd = cmd.trim()

                        // Priority 1: If port is 80 (HTTP WebServer), send HTTP GET request
                        if (port == 80) {
                            var wifiNetwork: Network? = null
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && connectivityManager != null) {
                                for (net in connectivityManager.allNetworks) {
                                    val caps = connectivityManager.getNetworkCapabilities(net)
                                    if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                        wifiNetwork = net
                                        break
                                    }
                                }
                            }

                            // Build candidate URLs paired with format keys for learning/caching
                            val candidates = mutableListOf<Pair<String, String>>()
                            val encodedVal = java.net.URLEncoder.encode(trimmedCmd, "UTF-8")
                            val upper = trimmedCmd.uppercase()
                            val lower = trimmedCmd.lowercase()

                            // Word / Direct candidates
                            candidates.add(Pair("http://$host:$port/$trimmedCmd", "DIRECT_WORD"))
                            candidates.add(Pair("http://$host:$port/$lower", "DIRECT_LOWER"))
                            candidates.add(Pair("http://$host:$port$path$encodedVal", "QUERY_CMD"))

                            when (upper) {
                                "F", "1", "FORWARD" -> {
                                    candidates.add(Pair("http://$host:$port/forward", "DIRECT_LOWER"))
                                    candidates.add(Pair("http://$host:$port/FORWARD", "DIRECT_WORD"))
                                    candidates.add(Pair("http://$host:$port/F", "DIRECT_CHAR"))
                                    candidates.add(Pair("http://$host:$port/action?go=forward", "ACTION_GO"))
                                    candidates.add(Pair("http://$host:$port/?State=FORWARD", "STATE_WORD"))
                                    candidates.add(Pair("http://$host:$port/?State=F", "STATE_CHAR"))
                                }
                                "B", "2", "BACKWARD" -> {
                                    candidates.add(Pair("http://$host:$port/backward", "DIRECT_LOWER"))
                                    candidates.add(Pair("http://$host:$port/BACKWARD", "DIRECT_WORD"))
                                    candidates.add(Pair("http://$host:$port/B", "DIRECT_CHAR"))
                                    candidates.add(Pair("http://$host:$port/action?go=backward", "ACTION_GO"))
                                    candidates.add(Pair("http://$host:$port/?State=BACKWARD", "STATE_WORD"))
                                    candidates.add(Pair("http://$host:$port/?State=B", "STATE_CHAR"))
                                }
                                "L", "3", "LEFT" -> {
                                    candidates.add(Pair("http://$host:$port/left", "DIRECT_LOWER"))
                                    candidates.add(Pair("http://$host:$port/LEFT", "DIRECT_WORD"))
                                    candidates.add(Pair("http://$host:$port/L", "DIRECT_CHAR"))
                                    candidates.add(Pair("http://$host:$port/action?go=left", "ACTION_GO"))
                                    candidates.add(Pair("http://$host:$port/?State=LEFT", "STATE_WORD"))
                                    candidates.add(Pair("http://$host:$port/?State=L", "STATE_CHAR"))
                                }
                                "R", "4", "RIGHT" -> {
                                    candidates.add(Pair("http://$host:$port/right", "DIRECT_LOWER"))
                                    candidates.add(Pair("http://$host:$port/RIGHT", "DIRECT_WORD"))
                                    candidates.add(Pair("http://$host:$port/R", "DIRECT_CHAR"))
                                    candidates.add(Pair("http://$host:$port/action?go=right", "ACTION_GO"))
                                    candidates.add(Pair("http://$host:$port/?State=RIGHT", "STATE_WORD"))
                                    candidates.add(Pair("http://$host:$port/?State=R", "STATE_CHAR"))
                                }
                                "S", "0", "STOP" -> {
                                    candidates.add(Pair("http://$host:$port/stop", "DIRECT_LOWER"))
                                    candidates.add(Pair("http://$host:$port/STOP", "DIRECT_WORD"))
                                    candidates.add(Pair("http://$host:$port/S", "DIRECT_CHAR"))
                                    candidates.add(Pair("http://$host:$port/action?go=stop", "ACTION_GO"))
                                    candidates.add(Pair("http://$host:$port/?State=STOP", "STATE_WORD"))
                                    candidates.add(Pair("http://$host:$port/?State=S", "STATE_CHAR"))
                                }
                            }

                            // If we know which format worked previously, prioritize it first!
                            val orderedCandidates = if (lastWorkingFormat != null) {
                                val priority = candidates.filter { it.second == lastWorkingFormat }
                                val rest = candidates.filter { it.second != lastWorkingFormat }
                                priority + rest
                            } else {
                                candidates
                            }

                            for ((urlStr, formatKey) in orderedCandidates) {
                                try {
                                    val url = java.net.URL(urlStr)
                                    val conn = if (wifiNetwork != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                        wifiNetwork.openConnection(url) as java.net.HttpURLConnection
                                    } else {
                                        url.openConnection() as java.net.HttpURLConnection
                                    }
                                    conn.connectTimeout = 400
                                    conn.readTimeout = 400
                                    conn.requestMethod = "GET"
                                    conn.setRequestProperty("Connection", "close")
                                    val responseCode = conn.responseCode
                                    try {
                                        conn.inputStream?.close()
                                    } catch (_: Exception) {}
                                    conn.disconnect()
                                    if (responseCode in 200..299) {
                                        sent = true
                                        lastWorkingFormat = formatKey
                                        android.util.Log.d("MainActivity", "Sent HTTP GET to $urlStr (status $responseCode, format $formatKey)")
                                        break
                                    }
                                } catch (e: Exception) {
                                    // Try next candidate endpoint
                                }
                            }
                        }

                        // Priority 2: Persistent TCP writer for socket servers (port 8080 or TCP fallback)
                        // CRITICAL: NEVER open persistent raw TCP socket on port 80, as it locks up the ESP32 WebServer!
                        if (!sent && port != 80) {
                            try {
                                val writer = getOrConnectTcp(connectivityManager, host, port)
                                if (writer != null) {
                                    writer.write(cmd)
                                    writer.flush()
                                    sent = true
                                    android.util.Log.d("MainActivity", "Sent TCP cmd '$cmd' to $host:$port")
                                }
                            } catch (e: Exception) {
                                android.util.Log.w("MainActivity", "Write error, retrying connect: ${e.message}")
                                closeTcp()
                                try {
                                    val writer = getOrConnectTcp(connectivityManager, host, port)
                                    if (writer != null) {
                                        writer.write(cmd)
                                        writer.flush()
                                        sent = true
                                    }
                                } catch (ex: Exception) {
                                    android.util.Log.e("MainActivity", "Retry failed: ${ex.message}")
                                }
                            }
                        }

                        runOnUiThread {
                            result.success(sent)
                        }
                    }.start()
                }

                "disconnectWifi" -> {
                    lastWorkingFormat = null
                    closeTcp()
                    activeNetworkCallback?.let {
                        try {
                            connectivityManager?.unregisterNetworkCallback(it)
                        } catch (_: Exception) {}
                        activeNetworkCallback = null
                    }
                    try {
                        connectivityManager?.bindProcessToNetwork(null)
                    } catch (_: Exception) {}
                    result.success(true)
                }

                "getConnectedWifi" -> {
                    if (wifiManager == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    var ssid = ""
                    var bssid = ""
                    var rssi = -50
                    var linkSpeed = 0
                    var frequency = 2400

                    // 1. On Android 10+ (Q+), modern WifiInfo is acquired through ConnectivityManager & NetworkCapabilities
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && connectivityManager != null) {
                        for (net in connectivityManager.allNetworks) {
                            val caps = connectivityManager.getNetworkCapabilities(net)
                            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                val info = caps.transportInfo as? android.net.wifi.WifiInfo
                                if (info != null) {
                                    val s = info.ssid ?: ""
                                    if (s.isNotEmpty() && s != "<unknown ssid>") {
                                        ssid = s
                                        bssid = info.bssid ?: ""
                                        rssi = info.rssi
                                        linkSpeed = info.linkSpeed
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                            frequency = info.frequency
                                        }
                                        break
                                    }
                                }
                            }
                        }
                    }

                    // 2. Legacy fallback
                    val legacyInfo = wifiManager.connectionInfo
                    if (legacyInfo != null) {
                        if (ssid.isEmpty() || ssid == "<unknown ssid>") {
                            ssid = legacyInfo.ssid ?: ""
                        }
                        if (bssid.isEmpty()) bssid = legacyInfo.bssid ?: ""
                        if (rssi == -50) rssi = legacyInfo.rssi
                        if (linkSpeed == 0) linkSpeed = legacyInfo.linkSpeed
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && frequency == 2400) {
                            frequency = legacyInfo.frequency
                        }
                    }

                    if (ssid.startsWith("\"") && ssid.endsWith("\"") && ssid.length >= 2) {
                        ssid = ssid.substring(1, ssid.length - 1)
                    }

                    // Try dhcpInfo first
                    var ipStr = "0.0.0.0"
                    var gatewayStr = "192.168.4.1"

                    val dhcp = wifiManager.dhcpInfo
                    if (dhcp != null && dhcp.ipAddress != 0) {
                        val ipInt = dhcp.ipAddress
                        ipStr = String.format("%d.%d.%d.%d", ipInt and 0xff, ipInt shr 8 and 0xff, ipInt shr 16 and 0xff, ipInt shr 24 and 0xff)
                    } else if (legacyInfo != null && legacyInfo.ipAddress != 0) {
                        val ipInt = legacyInfo.ipAddress
                        ipStr = String.format("%d.%d.%d.%d", ipInt and 0xff, ipInt shr 8 and 0xff, ipInt shr 16 and 0xff, ipInt shr 24 and 0xff)
                    }

                    if (dhcp != null && dhcp.gateway != 0) {
                        val gatewayInt = dhcp.gateway
                        gatewayStr = String.format("%d.%d.%d.%d", gatewayInt and 0xff, gatewayInt shr 8 and 0xff, gatewayInt shr 16 and 0xff, gatewayInt shr 24 and 0xff)
                    }

                    // If IP is still 0.0.0.0, find wlan0 network interface
                    if (ipStr == "0.0.0.0") {
                        try {
                            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
                            while (interfaces.hasMoreElements()) {
                                val iface = interfaces.nextElement()
                                if (iface.name.startsWith("wlan") || iface.name.startsWith("ap")) {
                                    val addrs = iface.inetAddresses
                                    while (addrs.hasMoreElements()) {
                                        val addr = addrs.nextElement()
                                        if (!addr.isLoopbackAddress && addr is java.net.Inet4Address) {
                                            ipStr = addr.hostAddress ?: "0.0.0.0"
                                            break
                                        }
                                    }
                                }
                                if (ipStr != "0.0.0.0") break
                            }
                        } catch (_: Exception) {}
                    }

                    // If phone is connected to Wi-Fi (IP is assigned) but SSID was restricted by OS, give a recognizable name based on gateway
                    if ((ssid.isEmpty() || ssid == "<unknown ssid>") && ipStr != "0.0.0.0") {
                        ssid = if (ipStr.startsWith("192.168.4.")) "ESP Hotspot" else "Connected Wi-Fi"
                    }

                    if (ssid.isEmpty() || ssid == "<unknown ssid>" || ipStr == "0.0.0.0") {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val map = hashMapOf(
                        "ssid" to ssid,
                        "bssid" to bssid,
                        "ip" to ipStr,
                        "gateway" to gatewayStr,
                        "linkSpeed" to linkSpeed,
                        "rssi" to rssi,
                        "frequency" to frequency
                    )
                    result.success(map)
                }

                "getScanResults" -> {
                    if (wifiManager == null) {
                        result.success(emptyList<Map<String, Any>>())
                        return@setMethodCallHandler
                    }
                    val scanList = wifiManager.scanResults ?: emptyList<ScanResult>()
                    val list = scanList
                        .filter { it.SSID != null && it.SSID.isNotEmpty() }
                        .map { scan ->
                            hashMapOf(
                                "ssid" to scan.SSID,
                                "bssid" to (scan.BSSID ?: ""),
                                "level" to scan.level,
                                "frequency" to scan.frequency,
                                "capabilities" to (scan.capabilities ?: "")
                            )
                        }
                    result.success(list)
                }

                "startScan" -> {
                    if (wifiManager == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val success = wifiManager.startScan()
                        result.success(success)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val fineIndex = permissions.indexOf(Manifest.permission.ACCESS_FINE_LOCATION)
            val fineGranted = fineIndex != -1 && grantResults.getOrNull(fineIndex) == PackageManager.PERMISSION_GRANTED
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(fineGranted || allGranted)
            pendingPermissionResult = null
        }
    }
}
