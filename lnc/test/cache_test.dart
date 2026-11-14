import 'common.dart';
import 'package:lnc/cache.dart';
import 'package:lnc/log.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    // echo the library logs as tidy one-liners for visibility
    Log.logger = DefaultLogger(TidyPrinter());
    Log.level = Log.DEBUG;
    Log.colorful = true;
  });

  group('CacheHolder', () {

    const base = 1000.0;
    const life = 100.0;

    test('stores the value and expires after the life span', () {
      final holder = CacheHolder<String>('value', life, now: base);

      expect(holder.value, 'value');
      expect(holder.isAlive(now: base), isTrue);
      expect(holder.isAlive(now: base + life - 1), isTrue);
      // expired exactly at `now + life`
      expect(holder.isAlive(now: base + life), isFalse);
      // deprecated only after twice the life span
      expect(holder.isDeprecated(now: base + life * 2), isFalse);
      expect(holder.isDeprecated(now: base + life * 2 + 1), isTrue);
    });

    test('a null value is cacheable', () {
      final holder = CacheHolder<String>(null, life, now: base);

      expect(holder.value, isNull);
      expect(holder.isAlive(now: base), isTrue);
    });

    test('updateValue refreshes the value and the expiry', () {
      final holder = CacheHolder<String>('old', life, now: base);

      holder.updateValue('new', now: base + life);

      expect(holder.value, 'new');
      expect(holder.isAlive(now: base + life), isTrue);
      expect(holder.isAlive(now: base + life * 2), isFalse);
    });

    test('updateValue(null) keeps the holder alive while clearing the value', () {
      final holder = CacheHolder<String>('old', life, now: base);

      holder.updateValue(null, now: base + life);

      expect(holder.value, isNull);
      expect(holder.isAlive(now: base + life), isTrue);
    });

    test('renewal extends the expiry without touching the value', () {
      final holder = CacheHolder<String>('value', life, now: base);

      holder.renewal(50, now: base + life);

      expect(holder.value, 'value');
      expect(holder.isAlive(now: base + life), isTrue);
      expect(holder.isAlive(now: base + life + 50), isFalse);
    });

    test('renewal(null) falls back to 120 seconds', () {
      final holder = CacheHolder<String>('value', life, now: base);

      holder.renewal(null, now: base);

      expect(holder.isAlive(now: base + 119), isTrue);
      expect(holder.isAlive(now: base + 120), isFalse);
    });
  });

  group('CachePool', () {

    const base = 1000.0;
    const life = 100.0;

    test('updateValue & fetch round trip', () {
      final pool = CachePool<String, String>();

      pool.updateValue('key', 'value', life, now: base);

      final pair = pool.fetch('key', now: base);
      expect(pair, isNotNull);
      expect(pair!.value, 'value');
      expect(pair.holder.isAlive(now: base), isTrue);
    });

    test('fetching a missing key returns null', () {
      final pool = CachePool<String, String>();
      expect(pool.fetch('missing', now: base), isNull);
    });

    test('updating the same key overwrites the old value', () {
      final pool = CachePool<String, String>();

      pool.updateValue('key', 'v1', life, now: base);
      pool.updateValue('key', 'v2', life, now: base);

      expect(pool.fetch('key', now: base)!.value, 'v2');
      expect(pool.keys.toList(), ['key']);
    });

    test('fetch returns a null value once expired, holder stays', () {
      final pool = CachePool<String, String>();
      pool.updateValue('key', 'value', life, now: base);

      expect(pool.fetch('key', now: base + life - 1)!.value, 'value');

      final pair = pool.fetch('key', now: base + life);
      expect(pair, isNotNull);
      expect(pair!.value, isNull);
      Log.info('expired key: value = ${pair.value}, holder kept');
    });

    test('updateHolder keeps the holder instance', () {
      final pool = CachePool<String, String>();
      final holder = CacheHolder<String>('value', life, now: base);

      pool.updateHolder('key', holder);

      expect(pool.fetch('key', now: base)!.holder, same(holder));
    });

    test('erase removes the key and can return the old value', () {
      final pool = CachePool<String, String>();
      pool.updateValue('key', 'value', life, now: base);

      final old = pool.erase('key', now: base);

      expect(old, isNotNull);
      expect(old!.value, 'value');
      expect(pool.fetch('key', now: base), isNull);
      expect(pool.keys, isEmpty);
      Log.info('erase(key, now) -> old value = ${old.value}, key removed');
    });

    test('erase without a timestamp does not fetch the old value', () {
      final pool = CachePool<String, String>();
      pool.updateValue('key', 'value', life, now: base);

      expect(pool.erase('key'), isNull);
      expect(pool.fetch('key', now: base), isNull);
    });

    test('erasing a missing key returns null even with a timestamp', () {
      final pool = CachePool<String, String>();
      expect(pool.erase('missing', now: base), isNull);
    });

    test('purge removes deprecated holders and keeps the rest', () {
      final pool = CachePool<String, String>();
      pool.updateValue('a', 'v1', life, now: base);       // deprecated at 1200
      pool.updateValue('b', 'v2', life, now: base + 10);  // deprecated at 1210
      pool.updateValue('c', 'v3', life, now: base + 150); // deprecated at 1350

      expect(pool.purge(now: base + life * 2), 0);  // boundary: not yet deprecated
      Log.info('purge @ ${base + life * 2}: removed 0 (deprecated at +1 tick)');

      expect(pool.purge(now: base + life * 2 + 5), 1);  // 'a' gone
      expect(pool.purge(now: base + life * 2 + 15), 1); // 'b' gone
      Log.info('purge removed deprecated "a" & "b", kept "c"');

      expect(pool.keys.toList(), ['c']);
      expect(pool.fetch('c', now: base + life * 2 + 15)!.value, 'v3');
    });
  });

  group('CacheManager', () {

    test('is a singleton', () {
      expect(identical(CacheManager(), CacheManager()), isTrue);
    });

    test('getPool returns the same pool for the same name', () {
      final manager = CacheManager();
      final p1 = manager.getPool<String, int>('pool-x');
      final p2 = manager.getPool<String, int>('pool-x');
      final other = manager.getPool<String, int>('pool-y');

      expect(identical(p1, p2), isTrue);
      expect(identical(p1, other), isFalse);
    });

    test('pools with different names are independent', () {
      final manager = CacheManager();
      final p1 = manager.getPool<String, String>('pool-1');
      final p2 = manager.getPool<String, String>('pool-2');

      // life span of infinity so this entry never interferes with purge tests
      p1.updateValue('key', 'v1', double.infinity, now: 1000);

      expect(p2.fetch('key', now: 1000), isNull);
    });

    test('purge aggregates all pools', () {
      final manager = CacheManager();
      const base = 1000.0, life = 100.0;

      final p1 = manager.getPool<String, String>('m-purge-1');
      p1.updateValue('k1', 'v1', life, now: base);         // deprecated at 1200
      p1.updateValue('keep', 'v', life, now: base + 150);  // deprecated at 1350

      final p2 = manager.getPool<String, String>('m-purge-2');
      p2.updateValue('k2', 'v2', life, now: base + 10);    // deprecated at 1210

      expect(manager.purge(base + life * 2 + 5), 1);  // only 'k1' is deprecated
      Log.info('manager.purge @ ${base + life * 2 + 5}: "k1" purged from pool-1');

      expect(p1.fetch('k1', now: base + life * 2 + 5), isNull);
      expect(p1.fetch('keep', now: base + life * 2 + 5)!.value, 'v');
      // k2 was written at base+10, its value expired at base+life+10
      expect(p2.fetch('k2', now: base + life)!.value, 'v2');

      expect(manager.purge(base + life * 2 + 15), 1); // then 'k2'
      expect(p2.fetch('k2', now: base + life * 2 + 15), isNull);
      Log.info('manager.purge @ ${base + life * 2 + 15}: "k2" purged from pool-2');
    });
  });
}
