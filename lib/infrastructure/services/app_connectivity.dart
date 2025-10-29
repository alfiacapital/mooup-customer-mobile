import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

abstract class AppConnectivity {
  AppConnectivity._();

  static Future<bool> connectivity() async {
    try {
      // Defer to avoid iOS 18 launch-time plugin crash
      if (WidgetsBinding.instance.lifecycleState == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.ethernet) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        return true;
      }
      return false;
    } catch (_) {
      // Fail open at startup instead of crashing
      return true;
    }
  }
}
