import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vyre/utils/constants.dart';

class UpdateService {
  static const String _repo = 'toptestsoft/vyre-mobile';

  /// Проверяет обновления через GitHub Releases API
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Определяет ABI устройства
  static Future<String> getDeviceAbi() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      const priority = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
      for (final arch in priority) {
        if (info.supportedAbis.contains(arch)) return arch;
      }
      return 'arm64-v8a';
    } catch (_) {
      return 'arm64-v8a';
    }
  }

  /// Возвращает URL APK для текущей архитектуры
  static Future<String?> getDownloadUrlForDevice() async {
    final release = await checkForUpdates();
    if (release == null) return null;
    final abi = await getDeviceAbi();
    final assets = release['assets'] as List<dynamic>;
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains(abi)) {
        return asset['browser_download_url'] as String;
      }
    }
    return null;
  }

  /// Получить текущую версию приложения
  static String getVersion(Map<String, dynamic> release) {
    return (release['tag_name'] as String).replaceFirst('v', '');
  }

  /// Скачивает APK во временную папку и предлагает установить
  static Future<void> downloadAndInstallApk(BuildContext context, String url) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/vyre_update.apk');

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0a0a1a),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Скачивание обновления', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: kAccentCyan),
              SizedBox(height: 16),
              Text('Пожалуйста подождите...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    try {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 30);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Ошибка скачивания: ${response.statusCode}');
      }

      final sink = file.openWrite();
      await response.listen(
        (chunk) {
          sink.add(chunk);
        },
        onDone: () => sink.close(),
        onError: (e) => sink.close(),
        cancelOnError: true,
      ).asFuture();

      client.close();

      if (!context.mounted) return;
      Navigator.pop(context);

       // Открыть файл для установки
      try {
        await launchUrl(Uri.file(file.path));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('APK скачан и готов к установке.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия файла: $e')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка скачивания: $e')),
      );
    }
  }

  /// Показать диалог обновления
  static void showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> release,
  ) {
    final version = getVersion(release);
    final body = release['body'] as String? ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Доступно обновление',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Версия $version доступна для загрузки.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = await getDownloadUrlForDevice();
              if (url != null) {
                await downloadAndInstallApk(context, url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Не удалось определить APK для устройства')),
                );
              }
            },
            child: const Text('Скачать и установить',
                style: TextStyle(color: Color(0xFF7c4dff))),
          ),
        ],
      ),
    );
  }
}
