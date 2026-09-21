import 'dart:async';
import 'package:flutter/services.dart';

class AndroidVpnService {
  static const MethodChannel _channel = MethodChannel('com.vyre.vpn/android_vpn');

  Future<bool> isAlwaysOnVpnEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlwaysOnVpnEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    } on Exception {
      return false;
    }
  }

  Future<bool> requestAlwaysOnVpn() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestAlwaysOnVpn');
      return result ?? false;
    } on PlatformException {
      return false;
    } on Exception {
      return false;
    }
  }

  Future<bool> isLockdownEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLockdownEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    } on Exception {
      return false;
    }
  }
}
