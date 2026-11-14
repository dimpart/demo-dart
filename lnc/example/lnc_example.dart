/* LNC : Log, Notification & Cache
 *
 * This package provides three modules, each with its own example:
 *
 *   log_example.dart           - logging
 *   notification_example.dart  - local notification center
 *   cache_example.dart         - in-memory cache
 *
 * Run them one by one, or run all together with:
 * `dart run --enable-asserts example/lnc_example.dart`
 */
import 'cache_example.dart' as cache_example;
import 'log_example.dart' as log_example;
import 'notification_example.dart' as notification_example;

void main() async {
  await log_example.main();
  await notification_example.main();
  await cache_example.main();
}
