import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onstite/core/app_constants.dart';

class AppVersionInfo {
  final bool updateRequired;
  final bool forceUpdate;
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String releaseNotes;

  const AppVersionInfo({
    required this.updateRequired,
    required this.forceUpdate,
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        updateRequired: json['update_required'] as bool? ?? false,
        forceUpdate: json['force_update'] as bool? ?? false,
        versionCode: json['version_code'] as int? ?? 0,
        versionName: json['version_name'] as String? ?? '',
        apkUrl: json['apk_url'] as String? ?? '',
        releaseNotes: json['release_notes'] as String? ?? '',
      );
}

class AppVersionService {
  /// Checks if this device needs an update.
  /// [buildNumber] is the app's current build number (from pubspec version+build).
  /// [agentId] is the logged-in user's UUID (for scope-targeted updates).
  static Future<AppVersionInfo?> check({
    required int buildNumber,
    String? agentId,
  }) async {
    try {
      final params = {
        'app_type': 'agent',
        'build_number': buildNumber.toString(),
        if (agentId != null && agentId.isNotEmpty) 'agent_id': agentId,
      };
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/app/version/check')
          .replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return AppVersionInfo.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
