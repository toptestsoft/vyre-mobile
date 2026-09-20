import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';

class UpdateService {
  static const String _repoOwner = 'toptestsoft';
  static const String _repoName = 'vyre-mobile';

  static Future<UpdateInfo> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final client = http.Client();
      try {
        final response = await client.get(url).timeout(const Duration(seconds: 10));

        if (response.bodyBytes.length > 1 * 1024 * 1024) {
          return _noUpdate(error: 'Ответ слишком большой');
        }

        if (response.statusCode != 200) {
          return _noUpdate(error: 'Сервер недоступен (${response.statusCode})');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestTag = (data['tag_name'] as String? ?? '').trim();
        final latestVersion = latestTag.startsWith('v')
            ? latestTag.substring(1)
            : latestTag;

        if (latestVersion.isEmpty) {
          return _noUpdate(error: 'Не удалось определить версию релиза');
        }

        final assets = data['assets'] as List<dynamic>? ?? [];
        String? downloadUrl;
        for (final asset in assets) {
          final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }

        final releaseNotes = (data['body'] as String? ?? '').trim();

        if (_compareVersions(latestVersion, currentVersion) <= 0) {
          return UpdateInfo(
            hasUpdate: false,
            version: latestVersion,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
            error: null,
          );
        }

        return UpdateInfo(
          hasUpdate: true,
          version: latestVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          error: null,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return _noUpdate(error: 'Ошибка проверки обновлений: $e');
    }
  }

  static UpdateInfo _noUpdate({String? error}) => UpdateInfo(
        hasUpdate: false,
        version: '',
        releaseNotes: '',
        downloadUrl: null,
        error: error,
      );

  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).whereType<int>().toList();
    final partsB = b.split('.').map(int.tryParse).whereType<int>().toList();

    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < maxLen; i++) {
      final x = i < partsA.length ? partsA[i] : 0;
      final y = i < partsB.length ? partsB[i] : 0;
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }
}
