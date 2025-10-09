package com.example.prismatic_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.net.HttpURLConnection
import java.net.URL

class BackgroundLocationService : Service(), LocationListener {
    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "location_service_channel"
        private const val CHANNEL_NAME = "Location Service"
        private const val LOCATION_UPDATE_INTERVAL = 5000L // 1 second
        private const val LOCATION_UPDATE_DISTANCE = 0f // 1 meter
    }

    private lateinit var locationManager: LocationManager
    private var handler: Handler? = null
    private var lastKnownLocation: Location? = null
    private var deviceId: String = ""

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("LocationService", "onCreate called - Service starting up")
        
        try {
            // Get device ID
            deviceId = getDeviceId()
            android.util.Log.d("LocationService", "Device ID: $deviceId")
            
            createNotificationChannel()
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
            android.util.Log.d("LocationService", "Foreground service started with notification")
            
            initializeLocationManager()
            startContinuousLocationSending()
            android.util.Log.d("LocationService", "Location tracking initialized - Ready to send location data")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error in onCreate: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("LocationService", "Service started with START_STICKY")
        
        // Ensure location tracking is initialized
        if (!::locationManager.isInitialized) {
            initializeLocationManager()
        }
        
        // Ensure continuous location sending is started
        if (handler == null) {
            startContinuousLocationSending()
        }
        
        // Return START_STICKY to restart service if killed by system
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Location tracking service"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        try {
            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("App is Running")
                .setContentText("Sending location every second - ${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setAutoCancel(false)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
            
            android.util.Log.d("LocationService", "Notification created successfully")
            return notification
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error creating notification: ${e.message}")
            e.printStackTrace()
            
            // Fallback notification
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Location Service")
                .setContentText("Running")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build()
        }
    }

    private fun initializeLocationManager() {
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        
        try {
            // Check if permissions are granted for both fine and background location
            val fineLocationGranted = androidx.core.content.ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.ACCESS_FINE_LOCATION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            val backgroundLocationGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                androidx.core.content.ContextCompat.checkSelfPermission(
                    this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            } else {
                true // Background location permission not required for older Android versions
            }
            
            android.util.Log.d("LocationService", "Fine location permission: $fineLocationGranted")
            android.util.Log.d("LocationService", "Background location permission: $backgroundLocationGranted")
            
            if (fineLocationGranted) {
                // Request location updates with enhanced settings for real devices
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    try {
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
                        android.util.Log.d("LocationService", "GPS location tracking started")
                    } catch (e: Exception) {
                        android.util.Log.e("LocationService", "Error starting GPS tracking: ${e.message}")
                    }
                }
                
                if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    try {
                        locationManager.requestLocationUpdates(
                            LocationManager.NETWORK_PROVIDER,
                            LOCATION_UPDATE_INTERVAL,
                            LOCATION_UPDATE_DISTANCE,
                            this
                        )
                        android.util.Log.d("LocationService", "Network location tracking started")
                    } catch (e: Exception) {
                        android.util.Log.e("LocationService", "Error starting Network tracking: ${e.message}")
                    }
                }
                
                // Get last known location immediately with retry mechanism
                getLastKnownLocationWithRetry()
                
                android.util.Log.d("LocationService", "Location tracking started successfully")
            } else {
                android.util.Log.e("LocationService", "Fine location permission not granted")
            }
            
            if (!backgroundLocationGranted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                android.util.Log.w("LocationService", "Background location permission not granted - may affect kill state tracking")
            }
            
        } catch (e: SecurityException) {
            android.util.Log.e("LocationService", "Permission not granted: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error initializing location manager: ${e.message}")
        }
    }
    
    private fun getLastKnownLocationWithRetry() {
        var retryCount = 0
        val maxRetries = 3
        
        while (retryCount < maxRetries) {
            try {
                val lastKnownLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                if (lastKnownLocation != null && lastKnownLocation.latitude != 0.0 && lastKnownLocation.longitude != 0.0) {
                    this.lastKnownLocation = lastKnownLocation
                    android.util.Log.d("LocationService", "Last known location: ${lastKnownLocation.latitude}, ${lastKnownLocation.longitude}")
                    sendLocationToServer(lastKnownLocation)
                    break
                } else {
                    // Try network provider as fallback
                    val networkLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    if (networkLocation != null && networkLocation.latitude != 0.0 && networkLocation.longitude != 0.0) {
                        this.lastKnownLocation = networkLocation
                        android.util.Log.d("LocationService", "Network last known location: ${networkLocation.latitude}, ${networkLocation.longitude}")
                        sendLocationToServer(networkLocation)
                        break
                    }
                }
                retryCount++
                if (retryCount < maxRetries) {
                    android.util.Log.d("LocationService", "Retrying to get last known location...")
                    Thread.sleep(1000) // Wait 1 second before retry
                }
            } catch (e: SecurityException) {
                android.util.Log.e("LocationService", "Error getting last known location (attempt ${retryCount + 1}): ${e.message}")
                retryCount++
            } catch (e: Exception) {
                android.util.Log.e("LocationService", "Error getting last known location (attempt ${retryCount + 1}): ${e.message}")
                retryCount++
            }
        }
        
        if (retryCount >= maxRetries) {
            android.util.Log.w("LocationService", "Could not get last known location after $maxRetries attempts")
        }
    }

    // LocationListener methods
     override fun onLocationChanged(location: Location) {
        android.util.Log.d("LocationService", "Location changed via Listener: ${location.latitude}, ${location.longitude}")
        lastKnownLocation = location // Update lastKnownLocation from the *real* listener callback
        sendLocationToServer(location)
    }

    override fun onProviderEnabled(provider: String) {
        android.util.Log.d("LocationService", "Provider enabled: $provider")
    }

    override fun onProviderDisabled(provider: String) {
        android.util.Log.d("LocationService", "Provider disabled: $provider")
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        android.util.Log.d("LocationService", "Status changed: $provider, $status")
    }

private fun startContinuousLocationSending() {
        handler = Handler(Looper.getMainLooper())
        handler?.postDelayed(object : Runnable {
            override fun run() {
                // The primary goal is to get the freshest location before sending.
                // The LocationListener updates lastKnownLocation when a new fix is available,
                // but for 1-second interval, we will check getLastKnownLocation for the most current fix.
                
                var locationToSend: Location? = null
                
                try {
                    // 1. Try GPS provider first for best accuracy
                    var freshLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    
                    if (freshLocation == null || freshLocation.latitude == 0.0 && freshLocation.longitude == 0.0) {
                        // 2. Fallback to Network provider
                        freshLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    }
                    
                    if (freshLocation != null && (lastKnownLocation == null || freshLocation.time > lastKnownLocation!!.time - 5000)) {
                        // Use the fresh location if it's new enough (within last 5 seconds)
                        // or if we didn't have a last known location.
                        locationToSend = freshLocation
                        lastKnownLocation = freshLocation // Update the stored last known location
                        android.util.Log.d("LocationService", "Continuous sender: Updated lastKnownLocation from getLastKnownLocation.")
                    } else if (lastKnownLocation != null) {
                        // If getLastKnownLocation is null or too old, use the last one received from onLocationChanged
                        locationToSend = lastKnownLocation
                        android.util.Log.d("LocationService", "Continuous sender: Using lastKnownLocation from Listener.")
                    }
                    
                } catch (e: SecurityException) {
                    android.util.Log.e("LocationService", "Error getting last known location in continuous sender: ${e.message}")
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "Error getting location in continuous sender: ${e.message}")
                }


                if (locationToSend != null) {
                    android.util.Log.d("LocationService", "Sending continuous location (1s loop): ${locationToSend.latitude}, ${locationToSend.longitude}")
                    sendLocationToServer(locationToSend)
                    
                    // Update notification with current location
                    updateNotificationWithLocation(locationToSend)
                } else {
                    android.util.Log.d("LocationService", "No valid location available for continuous sending in 1s loop - waiting for GPS lock")
                }
                
                // Schedule next execution every 1 second
                handler?.postDelayed(this, 1000) // 1 second
            }
        }, 1000) // Start after 1 second
    }

    private fun updateNotificationWithLocation(location: Location) {
        try {
            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("App is Running")
                .setContentText("Lat: ${String.format("%.6f", location.latitude)}, Lng: ${String.format("%.6f", location.longitude)} - ${java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())}")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setAutoCancel(false)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()

            startForeground(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error updating notification: ${e.message}")
        }
    }

private fun sendLocationToServer(location: Location) {

     val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val userJson = prefs.getString("flutter.App Is Login", null)
    val token = prefs.getString("flutter.access_token", null)
   var userId = prefs.getString("flutter.user_id", "0") ?: "0"  // make it var
    if (userJson != null && userJson.isNotEmpty()) {
        try {
            val jsonObj = org.json.JSONObject(userJson)
               userId = jsonObj.optString("id", userId)    // depends on your User model JSON
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error parsing user JSON: ${e.message}")
        }
    }

    val currentTime = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault()).format(java.util.Date())

    // This method will send location data to your server
    android.util.Log.d("LocationService", "Lat: ${location.latitude}, Lng: ${location.longitude}")
    
    // Send location data to your existing API endpoint
    Thread {
        try {
            val url = URL("https://softwareworkmanservices.com.pk/api/check-out")
            val connection = url.openConnection() as HttpURLConnection
            
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            
            // ✅ Get battery info
            val batteryStatus = registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
            val level = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale.toFloat()).toInt() else -1
            val status = batteryStatus?.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging = status == android.os.BatteryManager.BATTERY_STATUS_CHARGING || status == android.os.BatteryManager.BATTERY_STATUS_FULL

            // Get current time in the same format as Flutter
            val currentTime = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault()).format(java.util.Date())
            
            val jsonData = """
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
            
            android.util.Log.d("LocationService", "Sending JSON: $jsonData")
            
            val outputStream = connection.outputStream
            outputStream.write(jsonData.toByteArray())
            outputStream.flush()
            outputStream.close()
            
            val responseCode = connection.responseCode
            android.util.Log.d("LocationService", "API Response Code: $responseCode")
            
            // Read response body for debugging
            if (responseCode != 200) {
                val errorStream = connection.errorStream
                if (errorStream != null) {
                    val errorResponse = errorStream.bufferedReader().use { it.readText() }
                    android.util.Log.e("LocationService", "Error Response: $errorResponse")
                }
            } else {
                val responseStream = connection.inputStream
                val responseBody = responseStream.bufferedReader().use { it.readText() }
                android.util.Log.d("LocationService", "Success Response: $responseBody")
            }
            
            connection.disconnect()
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error sending location: ${e.message}")
            e.printStackTrace()
        }
    }.start()
}


    override fun onDestroy() {
        super.onDestroy()
        
        // Stop continuous location sending
        handler?.removeCallbacksAndMessages(null)
        
        try {
            locationManager.removeUpdates(this)
        } catch (e: SecurityException) {
            android.util.Log.e("LocationService", "Error removing location updates: ${e.message}")
        }
        
        android.util.Log.d("LocationService", "Service destroyed")
    }
    
    private fun getDeviceId(): String {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "Error getting device ID: ${e.message}")
            "unknown_device"
        }
    }
}