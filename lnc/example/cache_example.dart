/* LNC : Cache module example
 *
 * Run me with: `dart run --enable-asserts example/cache_example.dart`
 */
import 'package:lnc/cache.dart';
import 'package:lnc/log.dart';

Future<void> main() async {
  Log.level = Log.DEBUG;

  CacheManager manager = CacheManager();
  CachePool<String, String> pool = manager.getPool('greetings');

  pool.updateValue('hello', 'world', 1);      // alive for 1 second
  pool.updateValue('bye', 'cruel world', 1);  // alive for 1 second
  pool.fetch('hello')!.holder.renewal(3);     // 'hello' gets 3 more seconds

  Log.info('cached: hello = ${pool.fetch('hello')?.value}, bye = ${pool.fetch('bye')?.value}');

  await Future.delayed(const Duration(milliseconds: 2100));

  Log.info('after 2.1s: hello = ${pool.fetch('hello')?.value}, bye = ${pool.fetch('bye')?.value}');

  // fetch a missing key -> null
  Log.info('missing: ${pool.fetch('no-such-key')?.value ?? '(not cached)'}');

  // erase a key explicitly
  pool.updateValue('temp', 'to be erased', 60);
  pool.erase('temp');
  Log.info('erased "temp": ${pool.fetch('temp')?.value ?? '(gone)'}');

  int count = manager.purge(null);            // clear deprecated holders
  Log.info('purged $count deprecated holder(s)');
}
