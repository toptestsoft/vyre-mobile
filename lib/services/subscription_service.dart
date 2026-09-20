import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import '../models/vpn_state.dart';
import '../utils/helpers.dart'; // SubscriptionDecoder
import 'subscription_cache.dart';
import 'subscription_exceptions.dart';

class SubscriptionService {
  SubscriptionService(this._cache);
  final SubscriptionCache _cache;

  static const _schemes = ['vless://', 'vmess://', 'trojan://', 'ss://', 'socks://', 'hy2://', 'hysteria2://'];
  static bool isSingleLink(String url) =>
      _schemes.any((s) => url.toLowerCase().startsWith(s));

  /// Скачать тело подписки (2 попытки, лимит 5 МБ, кэш при успехе).
  Future<String> fetch(String url) async {
    Object? last;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final body = await _fetchOnce(url);
        await _cache.write(url, body);
        return body;
      } on SubscriptionException {
        rethrow;
      } catch (e) {
        last = e;
        if (attempt == 1) await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    // offline-first: сеть мертва — отдаём кэш
    final cached = await _cache.read(url);
    if (cached != null) return cached;
    throw SubscriptionException('Не удалось загрузить подписку: $last');
  }

  Future<String> _fetchOnce(String url, {int redirectCount = 0}) async {
    if (redirectCount > 5) {
      throw const SubscriptionRedirectException('Превышен лимит редиректов (максимум 5)');
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false
        ..headers['User-Agent'] = 'VYRE/2.0';

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.isRedirect) {
        final loc = response.headers['location'];
        final target = loc == null ? null : Uri.parse(url).resolve(loc);

        if (target == null || !(target.scheme == 'https' || target.scheme == 'http')) {
          throw const SubscriptionRedirectException('Подписка редиректит на небезопасный адрес');
        }

        final currentScheme = Uri.parse(url).scheme;
        if (currentScheme == 'https' && target.scheme == 'http') {
          throw const SubscriptionRedirectException('Запрещён редирект с HTTPS на HTTP');
        }

        return await _fetchOnce(target.toString(), redirectCount: redirectCount + 1);
      }

      final ct = response.headers['content-type'] ?? '';
      if (ct.contains('text/html')) {
        throw const SubscriptionException('Сервер вернул HTML вместо подписки (капча/блок?)');
      }

      if (response.statusCode != 200) {
        throw SubscriptionException('Ошибка загрузки подписки: ${response.statusCode}');
      }

      if (response.bodyBytes.length > 5 * 1024 * 1024) {
        throw const SubscriptionSizeLimitException('Ответ слишком большой (лимит 5 МБ)');
      }

      return response.body;
    } on SubscriptionException {
      rethrow;
    } on TimeoutException {
      throw const SubscriptionTimeoutException('Таймаут при загрузке подписки');
    } on http.ClientException {
      throw const SubscriptionException('Ошибка сети при загрузке подписки');
    } catch (e) {
      throw SubscriptionException('Не удалось загрузить подписку: $e');
    } finally {
      client.close();
    }
  }

  /// Декодирование + построчный парсинг с подсчётом брака.
  ParseResult parse(String body, {required bool isSingleLink}) {
    if (isSingleLink) {
      try {
        return ParseResult(servers: [parseOne(body)]);
      } catch (_) {
        return const ParseResult(servers: [], invalidCount: 1);
      }
    }
    var text = body.trim();
    if (!text.contains('://') && !text.contains('{')) {
      text = SubscriptionDecoder.decode(text);
    }
    final servers = <V2RayURL>[];
    var invalid = 0;
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        servers.add(parseOne(t));
      } catch (_) {
        invalid++;
      }
    }
    if (invalid > 0) debugPrint('VYRE sub: отброшено невалидных строк: $invalid');
    return ParseResult(servers: servers, invalidCount: invalid);
  }

  V2RayURL parseOne(String line) => FlutterV2ray.parseFromURL(line);

  /// Адаптер: возвращает `List<V2RayURL>` для совместимости со State.
  List<V2RayURL> parseToV2RayUrls(String body, {required bool isSingleLink}) {
    final result = parse(body, isSingleLink: isSingleLink);
    return result.servers.cast<V2RayURL>();
  }
}