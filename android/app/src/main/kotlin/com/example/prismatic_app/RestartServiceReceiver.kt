package com.example.prismatic_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager

class RestartServiceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("RestartServiceReceiver", "Received broadcast: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                android.util.Log.d("RestartServiceReceiver", "Device boot completed - launching app automatically")
                // Add delay to ensure system is fully ready
                Handler(Looper.getMainLooper()).postDelayed({
                    // Launch the app automatically
                    launchApp(context)
                }, 15000) // 15 second delay after boot to ensure system is fully ready
            }
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                android.util.Log.d("RestartServiceReceiver", "App updated - launching app")
                // Add delay to ensure app is fully ready
                Handler(Looper.getMainLooper()).postDelayed({
                    launchApp(context)
                }, 5000) // 5 second delay after update
            }
        }
    }
    
    private fun startNativeLocationService(context: Context) {
        android.util.Log.d("RestartServiceReceiver", "Attempting to start native location service after reboot...")
        
        // Try multiple times to ensure service starts after reboot
        var retryCount = 0
        val maxRetries = 3
        
        val startServiceRunnable = object : Runnable {
            override fun run() {
                if (retryCount < maxRetries) {
                    try {
                        android.util.Log.d("RestartServiceReceiver", "Starting native service attempt ${retryCount + 1}")
                        
                        // Acquire wake lock to ensure service starts properly
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        val wakeLock = powerManager.newWakeLock(
                            PowerManager.PARTIAL_WAKE_LOCK,
                            "PrismaticApp::RestartServiceReceiver"
                        )
                        wakeLock.acquire(30000) // Hold wake lock for 30 seconds
                        
                        val serviceIntent = Intent(context, BackgroundLocationService::class.java)
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                            android.util.Log.d("RestartServiceReceiver", "Started native foreground service successfully")
                        } else {
                            context.startService(serviceIntent)
                            android.util.Log.d("RestartServiceReceiver", "Started native service successfully")
                        }
                        
                        // Release wake lock after a delay
                        Handler(Looper.getMainLooper()).postDelayed({
                            try {
                                if (wakeLock.isHeld) {
                                    wakeLock.release()
                                    android.util.Log.d("RestartServiceReceiver", "Wake lock released")
                                }
                            } catch (e: Exception) {
                                android.util.Log.e("RestartServiceReceiver", "Error releasing wake lock: ${e.message}")
                            }
                        }, 5000)
                        
                        // If successful, don't retry
                        retryCount = maxRetries
                        
                    } catch (e: Exception) {
                        android.util.Log.e("RestartServiceReceiver", "Failed to start native service attempt ${retryCount + 1}: ${e.message}")
                        e.printStackTrace()
                        
                        retryCount++
                        if (retryCount < maxRetries) {
                            // Wait 5 seconds before retry
                            android.util.Log.d("RestartServiceReceiver", "Retrying in 5 seconds...")
                            Handler(Looper.getMainLooper()).postDelayed(this, 5000)
                        } else {
                            android.util.Log.e("RestartServiceReceiver", "Failed to start native service after $maxRetries attempts")
                        }
                    }
                }
            }
        }
        
        // Start the first attempt
        Handler(Looper.getMainLooper()).post(startServiceRunnable)
    }
    
    private fun launchApp(context: Context) {
        try {
            android.util.Log.d("RestartServiceReceiver", "Launching app automatically after reboot...")
            
            // Launch the app normally - this will start MainActivity and all services
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                launchIntent.putExtra("auto_launched", true)
                context.startActivity(launchIntent)
                android.util.Log.d("RestartServiceReceiver", "App launched successfully after reboot")
            } else {
                android.util.Log.e("RestartServiceReceiver", "Could not get launch intent for package")
            }
            
        } catch (e: Exception) {
            android.util.Log.e("RestartServiceReceiver", "Failed to launch app: ${e.message}")
            e.printStackTrace()
        }
    }
}
