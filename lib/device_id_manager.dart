import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdManager {
  static const String _deviceIdKey = 'device_unique_id';

  static Future<String> getDeviceUniqueId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_deviceIdKey);

    if (storedId != null) {
      return storedId;
    }

    String deviceId;
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Use 'id' instead of 'androidId'
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    } else {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }
}
