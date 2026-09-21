package com.toptestsoft.vyre

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.vyre.vpn/android_vpn"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "isAlwaysOnVpnEnabled" -> {
          val alwaysOn = Settings.Secure.getString(contentResolver, Settings.Secure.ALWAYS_ON_VPN_APP)
          result.success(alwaysOn == packageName)
        }
        "isLockdownEnabled" -> {
          try {
            val lockdown = Settings.Secure.getInt(contentResolver, "always_on_vpn_lockdown", 0)
            result.success(lockdown == 1)
          } catch (e: Exception) {
            result.success(false)
          }
        }
        "requestAlwaysOnVpn" -> {
          try {
            val intent = Intent(Settings.ACTION_VPN_SETTINGS)
            val manager = packageManager
            val activity = intent.resolveActivity(manager)
            if (activity != null) {
              startActivity(intent)
              result.success(true)
            } else {
              result.success(false)
            }
          } catch (e: Exception) {
            result.success(false)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
