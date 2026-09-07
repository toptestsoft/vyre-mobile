import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/models/subscription.dart';
import 'package:vyre/services/server_selector.dart';

ServerRow row(String name, int ms) => ServerRow(remark: name, config: 'cfg-$name', delayMs: ms);

void main() {
  const sel = ServerSelector();

  group('sort', () {
    test('-1 никогда не первый', () {
      final sorted = sel.sort([row('bad', -1), row('slow', 100), row('fast', 20)]);
      expect(sorted.first.remark, 'fast');
      expect(sorted.last.remark, 'bad');
    });
    test('delay 0 валиден', () {
      final sorted = sel.sort([row('zero', 0), row('x', 5)]);
      expect(sorted.first.remark, 'zero');
    });
    test('пустой список', () => expect(sel.sort([]), isEmpty));
  });

  group('selectBest', () {
    test('все недоступны → null', () {
      expect(sel.selectBest(sel.sort([row('a', -1), row('b', -1)])), isNull);
    });
    test('выбирает минимальную задержку', () {
      final best = sel.selectBest(sel.sort([row('a', 80), row('b', 30)]));
      expect(best?.remark, 'b');
    });
    test('fallbackAny спасает при полной недоступности', () {
      expect(sel.fallbackAny([row('a', -1)]), isNotNull);
    });
  });
}
