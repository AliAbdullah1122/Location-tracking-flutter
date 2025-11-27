package com.example.prismatic_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.provider.Settings
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.ConnectivityManager
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.net.HttpURLConnection
import java.net.URL

class BackgroundLocationService : Service(), LocationListener {

    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "location_service_channel"
        private const val CHANNEL_NAME = "Location Service"
        private const val LOCATION_UPDATE_INTERVAL = 1000L // 1 sec - more frequent updates to track device movement
        private const val LOCATION_UPDATE_DISTANCE = 0f // Update on ANY movement (even 0 meters) to track exact current location
    }

    private lateinit var locationManager: LocationManager
    private var handler: Handler? = null
    private var lastKnownLocation: Location? = null
    private var deviceId: String = ""
    private lateinit var dbHelper: LocationDatabaseHelper
    private var connectivityReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("LocationService", "onCreate called")

        deviceId = getDeviceId()
        dbHelper = LocationDatabaseHelper(this)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        initializeLocationManager()
        startContinuousLocationSending()
        registerNetworkReceiver()

        android.util.Log.d("LocationService", "Service initialized successfully")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!::locationManager.isInitialized) initializeLocationManager()
        if (handler == null) startContinuousLocationSending()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Location tracking service" }

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App is Running")
            .setContentText("Tracking location every 2 min")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .build()
    }

    private fun initializeLocationManager() {
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            if (ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    LOCATION_UPDATE_INTERVAL,
                    LOCATION_UPDATE_DISTANCE,
                    this
                )
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    LOCATION_UPDATE_INTERVAL,
                    LOCATION_UPDATE_DISTANCE,
                    this
                )
                getLastKnownLocationWithRetry()
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error initializing location: ${e.message}")
        }
    }

    private fun getLastKnownLocationWithRetry() {
        // Don't send old cached location on startup - wait for fresh location from 2-minute loop
        // This ensures we always send current live location, not old cached location
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        for (p in providers) {
            try {
                val loc = locationManager.getLastKnownLocation(p)
                if (loc != null) {
                    lastKnownLocation = loc
                    // Don't send immediately - let the 2-minute loop send current location
                    android.util.Log.d("LocationService", "Initial location obtained, will send current location in 2-minute loop")
                    break
                }
            } catch (e: Exception) {
                android.util.Log.e("LocationService", "Error getting last location: ${e.message}")
            }
        }
    }

    override fun onLocationChanged(location: Location) {
        lastKnownLocation = location
    }

    /**
     * Try to obtain a fresh location fix from GPS/Network within the given timeout.
     * Falls back to null if no update arrives in time. Caller decides how to proceed.
     */
    private fun getFreshLocationBlocking(timeoutMs: Long = 5000L): Location? {
        return try {
            if (ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return null
            }

            var freshLocation: Location? = null
            val lock = Object()
            val tempListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    synchronized(lock) {
                        if (freshLocation == null) {
                            freshLocation = location
                            lock.notifyAll()
                        }
                    }
                }
            }

            // Request updates from both providers to get whichever comes first
            try {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    0L,
                    0f,
                    tempListener,
                    Looper.getMainLooper()
                )
            } catch (_: Exception) { }
            try {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    0L,
                    0f,
                    tempListener,
                    Looper.getMainLooper()
                )
            } catch (_: Exception) { }

            // Wait for the first incoming update or timeout
            synchronized(lock) {
                if (freshLocation == null) {
                    try {
                        lock.wait(timeoutMs)
                    } catch (_: InterruptedException) { }
                }
            }

            // Stop temporary updates
            try { locationManager.removeUpdates(tempListener) } catch (_: Exception) { }

            // If we got a fresh fix, also update lastKnownLocation for future fallback
            if (freshLocation != null) {
                lastKnownLocation = freshLocation
            }
            freshLocation
        } catch (_: Exception) {
            null
        }
    }

    private fun startContinuousLocationSending() {
        handler = Handler(Looper.getMainLooper())
        handler?.postDelayed(object : Runnable {
            override fun run() {
                try {
                    // ALWAYS get EXACT CURRENT location every 2 minutes - ensure it's the LIVE location where device is NOW
                    var locationToSend: Location? = null
                    var freshestLocation: Location? = null
                    var freshestTime: Long = 0
                    
                    // FIRST: Try to get actively requested FRESH location (this ensures we get current location)
                    locationToSend = getFreshLocationBlocking(5000L) // 5 seconds to get fresh location
                    if (locationToSend != null) {
                        freshestLocation = locationToSend
                        freshestTime = locationToSend.time
                        lastKnownLocation = locationToSend
                        android.util.Log.d("LocationService", "Got FRESH location from active request: lat=${locationToSend.latitude}, lng=${locationToSend.longitude}")
                    }
                    
                    // SECOND: Check lastKnownLocation - only use if it's very recent (less than 5 seconds old)
                    // This ensures we use CURRENT location, not stale one
                    if (lastKnownLocation != null) {
                        val age = System.currentTimeMillis() - lastKnownLocation!!.time
                        if (age < 5000 && lastKnownLocation!!.time > freshestTime) { // Less than 5 seconds old and newer than what we have
                            freshestLocation = lastKnownLocation
                            freshestTime = lastKnownLocation!!.time
                            android.util.Log.d("LocationService", "Using RECENT lastKnownLocation (age: ${age}ms): lat=${freshestLocation?.latitude}, lng=${freshestLocation?.longitude}")
                        } else if (age >= 5000) {
                            android.util.Log.w("LocationService", "lastKnownLocation is too old (age: ${age}ms) - not using it")
                        }
                    }
                    
                    // Use the freshest location found
                    locationToSend = freshestLocation
                    
                    // THIRD PRIORITY: Fallback to providers (to ensure we always send)
                    if (locationToSend == null) {
                        try {
                            val gpsLoc = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                            val networkLoc = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                            
                            // Use the one with the most recent timestamp
                            if (gpsLoc != null && networkLoc != null) {
                                locationToSend = if (gpsLoc.time > networkLoc.time) gpsLoc else networkLoc
                            } else if (gpsLoc != null) {
                                locationToSend = gpsLoc
                            } else if (networkLoc != null) {
                                locationToSend = networkLoc
                            }
                            
                            if (locationToSend != null) {
                                lastKnownLocation = locationToSend
                                android.util.Log.d("LocationService", "Using provider location as fallback: lat=${locationToSend.latitude}, lng=${locationToSend.longitude}")
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("LocationService", "Error getting location from providers: ${e.message}")
                        }
                    }
                    
                    // ALWAYS send EXACT CURRENT location every 2 minutes (only when online)
                    if (locationToSend != null) {
                        if (isInternetAvailable()) {
                            // Internet available - ALWAYS send EXACT CURRENT location to API every 2 minutes
                            sendLocationToServer(locationToSend)
                            updateNotificationWithLocation(locationToSend)
                            android.util.Log.d("LocationService", "✅ Online - Sent EXACT CURRENT location to API: lat=${locationToSend.latitude}, lng=${locationToSend.longitude}")
                        } else {
                            // No internet - DO NOT store offline lat/lng to local database
                            // val jsonData = buildLocationJson(locationToSend)
                            // dbHelper.insertLocation(jsonData)
                            android.util.Log.d("LocationService", "⚠️ Offline - NOT storing location (offline storage disabled)")
                        }
                    } else {
                        android.util.Log.w("LocationService", "No location available - will retry in 2 minutes")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "Error in loop: ${e.message}")
                }

                // Repeat every 2 minutes - ALWAYS call API every 2 minutes
                handler?.postDelayed(this, 120000)
            }
        }, 2000)
    }

    private fun updateNotificationWithLocation(location: Location) {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App is Running")
            .setContentText(
                "Lat: %.6f, Lng: %.6f".format(location.latitude, location.longitude)
            )
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildLocationJson(location: Location): String {
    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val token = prefs.getString("flutter.access_token", null)
    var userId = prefs.getString("flutter.user_id", "0") ?: "0"
    val userJson = prefs.getString("flutter.App Is Login", null)

    if (!userJson.isNullOrEmpty()) {
        try {
            val obj = org.json.JSONObject(userJson)
            userId = obj.optString("id", userId)
        } catch (_: Exception) {}
    }

    val currentTime = java.text.SimpleDateFormat(
        "yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault()
    ).format(java.util.Date())

    val batteryStatus = registerReceiver(
        null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
    )
    val level = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1
    val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale.toFloat()).toInt() else -1
    val status = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1) ?: -1
    val isCharging = status == android.os.BatteryManager.BATTERY_STATUS_CHARGING ||
            status == android.os.BatteryManager.BATTERY_STATUS_FULL

        return """
        {
            "lat": ${location.latitude},
            "long": ${location.longitude},
            "user_id": "$userId",
            "token": "$token",
            "player_id": "$deviceId",
            "status": "app",
            "app_state": "kill_state",
            "check_in": false,
            "check_out": false,
            "time": "$currentTime",
            "timestamp": "$currentTime",
            "battery_level": $batteryPct,
            "is_charging": $isCharging
        }
    """.trimIndent()
    }

    private fun sendLocationToServer(location: Location) {
        val jsonData = buildLocationJson(location)

    Thread {
        try {
            if (isInternetAvailable()) {
                    // Send current location only (stored locations are handled by the 2-minute loop)
                sendJsonToServer(jsonData)
                android.util.Log.d("LocationService", "Current location sent: $jsonData")
            } else {
                // 🔹 No internet → Save current location locally
                android.util.Log.w("LocationService", "No internet - saving current location")
                dbHelper.insertLocation(jsonData)
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error sending location: ${e.message}")
            // 🔹 If send failed for any reason, save locally
            dbHelper.insertLocation(jsonData)
        }
    }.start()
}


    private fun sendJsonToServer(jsonData: String) {
        val url = URL("https://softwareworkmanservices.com.pk/api/check-out")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.outputStream.use { it.write(jsonData.toByteArray()) }
        val responseCode = conn.responseCode
        android.util.Log.d("LocationService", "Response Code: $responseCode")
        conn.disconnect()
    }

    private fun isInternetAvailable(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val active = cm.activeNetworkInfo
            active != null && active.isConnected
        } catch (e: Exception) {
            false
        }
    }

    // ✅ Detect when internet becomes available again
    // When internet restores, send CURRENT location to API (NOT stored offline data)
private fun registerNetworkReceiver() {
    connectivityReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (isInternetAvailable()) {
                    android.util.Log.d("LocationService", "Internet restored - sending CURRENT lat/lng to API")
                Thread {
                    try {
                        // DO NOT send stored offline data - only send current location
                        // val unsentList = dbHelper.getUnsentLocations()
                        // if (unsentList.isNotEmpty()) {
                        //     android.util.Log.d(
                        //         "LocationService",
                        //             "Sending ${unsentList.size} stored locations to API in order"
                        //     )
                        //         
                        //         // Send all stored locations in order (oldest first) - ensure no duplicates
                        //         unsentList.forEach { (id, json) ->
                        //             try {
                        //                 android.util.Log.d("LocationService", "Sending stored location ID $id to API (in order)")
                        //                 sendJsonToServer(json)
                        //                 // Mark as sent immediately after successful send to prevent duplicate sends
                        //                 dbHelper.markAsSent(id)
                        //             } catch (e: Exception) {
                        //                 android.util.Log.e(
                        //                     "LocationService",
                        //                     "Failed to send stored location ID $id: ${e.message}"
                        //                 )
                        //             }
                        //         }
                        //         
                        //         // After all stored locations are sent successfully, clear them from database
                        //         // This ensures data sent from local database is NOT sent again
                        //         dbHelper.clearSent()
                        //         android.util.Log.d("LocationService", "All stored locations sent in order - database cleared (no duplicates will be sent)")
                        //     } else {
                        //         android.util.Log.d("LocationService", "No stored locations - database is empty")
                        //     }
                            
                            // Send CURRENT location (from active listeners, not cached)
                            var currentLocation = getFreshLocationBlocking(3000L) // Try fresh location first
                            
                            // If no fresh location, use lastKnownLocation (updated every 1 second by onLocationChanged - this is CURRENT location)
                            if (currentLocation == null && lastKnownLocation != null) {
                                currentLocation = lastKnownLocation
                            }
                            
                            if (currentLocation != null) {
                                lastKnownLocation = currentLocation // Update for reference
                                android.util.Log.d("LocationService", "Internet restored - sending CURRENT lat/lng to API: lat=${currentLocation.latitude}, lng=${currentLocation.longitude}")
                                sendLocationToServer(currentLocation)
                                updateNotificationWithLocation(currentLocation)
                            } else {
                                android.util.Log.w("LocationService", "Internet restored but no current location available")
                            }
                            
                            // After sending current location, the 2-minute loop will continue normally
                            android.util.Log.d("LocationService", "Internet restored - will continue sending current lat/lng every 2 minutes")
                    } catch (e: Exception) {
                        android.util.Log.e("LocationService", "Error in network receiver: ${e.message}")
                    }
                }.start()
            }
        }
    }
    registerReceiver(connectivityReceiver, IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION))
}


    private fun getDeviceId(): String {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        } catch (e: Exception) {
            "unknown_device"
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler?.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(connectivityReceiver)
        } catch (_: Exception) {}
        try {
            locationManager.removeUpdates(this)
        } catch (_: Exception) {}
        android.util.Log.d("LocationService", "Service destroyed")
    }
}