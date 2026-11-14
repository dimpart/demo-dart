/* LNC : Notification module example
 *
 * Run me with: `dart run --enable-asserts example/notification_example.dart`
 */
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

/// Sample observer to listen to the 'welcome' notification.
class Guest with Logging implements Observer {

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    logInfo('${notification.sender} says: ${notification.userInfo?['message']}');
  }
}

/// Sample async observer, e.g. saving the notification into a database.
class Archiver with Logging implements Observer {
  final List<Notification> inbox = [];

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    inbox.add(notification);
    logInfo('archived: ${notification.name}');
  }
}

Future<void> main() async {
  Log.level = Log.DEBUG;

  NotificationCenter center = NotificationCenter();
  Guest guest = Guest();
  Archiver archiver = Archiver();
  center.addObserver(guest, 'welcome');
  center.addObserver(archiver, 'welcome');   // all observers get the broadcast

  await center.postNotification('welcome', 'LNC', {'message': 'Hello, observers!'});
  Log.info('archived ${archiver.inbox.length} notification(s) in total');

  center.removeObserver(guest);
  center.removeObserver(archiver);
  await center.postNotification('welcome', 'LNC');   // nobody is listening now
}
