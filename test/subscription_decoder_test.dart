import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/utils/helpers.dart';

void main() {
  test('обычный base64', () {
    final raw = base64Encode(utf8.encode('vless://x\nvmess://y'));
    expect(SubscriptionDecoder.decode(raw), contains('vless://x'));
  });
  test('url-safe без padding', () {
    final raw = 'vless://??>>';
    final enc = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    expect(SubscriptionDecoder.decode(enc), contains('vless://'));
  });
  test('BOM отбрасывается', () {
    final raw = '\uFEFF' + base64Encode(utf8.encode('ss://z'));
    expect(SubscriptionDecoder.decode(raw), contains('ss://'));
  });
  test('мусор возвращает исходный текст', () {
    expect(SubscriptionDecoder.decode('!!!not-base64!!!'), contains('!!!'));
  });
  test('пустая строка', () => expect(SubscriptionDecoder.decode(''), isEmpty));
}
