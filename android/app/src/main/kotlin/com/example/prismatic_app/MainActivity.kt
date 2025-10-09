package com.example.prismatic_app

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.prismatic_app/location_service"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if auto-launched after reboot
        val autoLaunched = intent.getBooleanExtra("auto_launched", false)
        if (autoLaunched) {
            android.util.Log.d("MainActivity", "onCreate - auto-launched after reboot, starting services normally")
            // Start services normally - all existing logic will work
            Handler(Looper.getMainLooper()).postDelayed({
                startLocationService()
                android.util.Log.d("MainActivity", "Services started after auto-launch from reboot")
            }, 2000)
        } else {
            // Start the kill state location service immediately
            android.util.Log.d("MainActivity", "onCreate - starting location service")
            startLocationService()
        }
    }

    override fun onResume() {
        super.onResume()
        // Ensure service is running when app resumes
        android.util.Log.d("MainActivity", "onResume - ensuring location service is running")
        startLocationService()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Don't stop the service when activity is destroyed - let it run in background
        android.util.Log.d("MainActivity", "onDestroy - keeping location service running")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    startLocationService()
                    result.success(true)
                }
                "stopLocationService" -> {
                    stopLocationService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startLocationService() {
        try {
            android.util.Log.d("MainActivity", "Attempting to start native location service...")
            val serviceIntent = Intent(this, BackgroundLocationService::class.java)
            
            // Add extra flags to ensure service starts properly
            serviceIntent.putExtra("source", "MainActivity")
            serviceIntent.putExtra("timestamp", System.currentTimeMillis())
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
                android.util.Log.d("MainActivity", "Started native foreground service (API >= 26)")
            } else {
                startService(serviceIntent)
                android.util.Log.d("MainActivity", "Started native service (API < 26)")
            }
            
            android.util.Log.d("MainActivity", "Native location service start command sent successfully")
            
            // Verify service started by checking if it's running
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                android.util.Log.d("MainActivity", "Verifying native service is running...")
                // Additional verification could be added here if needed
            }, 2000)
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error starting native location service: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun stopLocationService() {
        try {
            val serviceIntent = Intent(this, BackgroundLocationService::class.java)
            stopService(serviceIntent)
            android.util.Log.d("MainActivity", "Location service stopped")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping location service: ${e.message}")
        }
    }
    
    private fun initializeFlutterServices() {
        try {
            android.util.Log.d("MainActivity", "Initializing Flutter services after reboot...")
            
            // Start Flutter background service
            val flutterServiceIntent = Intent(this, id.flutter.flutter_background_service.BackgroundService::class.java)
            flutterServiceIntent.putExtra("action", "start")
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(flutterServiceIntent)
                android.util.Log.d("MainActivity", "Started Flutter foreground service after reboot")
            } else {
                startService(flutterServiceIntent)
                android.util.Log.d("MainActivity", "Started Flutter service after reboot")
            }
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error initializing Flutter services: ${e.message}")
            e.printStackTrace()
        }
    }
}
