import 'common.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:test/test.dart';

/// Observer that records everything it receives.
class RecordingObserver implements Observer {
  final List<Notification> received = [];

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    received.add(notification);
  }
}

/// Observer that takes some time to handle the notification.
class SlowObserver implements Observer {
  SlowObserver(this.listeningTo);

  final String listeningTo;
  bool done = false;

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (notification.name == listeningTo) {
      done = true;
    }
  }
}

/// Observer that throws synchronously.
class ThrowingObserver implements Observer {
  @override
  Future<void> onReceiveNotification(Notification notification) {
    throw StateError('sync boom');
  }
}

/// Observer that fails asynchronously.
class AsyncThrowingObserver implements Observer {
  @override
  Future<void> onReceiveNotification(Notification notification) async {
    throw StateError('async boom');
  }
}

/// Observer that unregisters itself upon receiving a notification.
class SelfRemovingObserver implements Observer {
  SelfRemovingObserver(this.center);

  final NotificationCenter center;
  final List<Notification> received = [];

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    received.add(notification);
    center.removeObserver(this, notification.name);
  }
}

void main() {
  setUp(() {
    // echo the library logs as tidy one-liners (expected observer
    // errors included) instead of dumping raw multi-line traces
    Log.logger = DefaultLogger(TidyPrinter());
    Log.level = Log.DEBUG;
    Log.colorful = true;
    // shorten long messages to 160 chars, so the middle ellipsis
    // (' ... total N chars ... ') stays inside the echo window
    Log.MAX_LEN = 160;
    // the center is a singleton, isolate each case with a fresh backing
    NotificationCenter().center = BaseCenter();
  });

  group('NotificationCenter', () {

    test('is a singleton', () {
      expect(identical(NotificationCenter(), NotificationCenter()), isTrue);
    });

    test('delivers name, sender and userInfo to the observer', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt');

      await center.postNotification('evt', 'sender', {'key': 'value'});

      expect(obs.received, hasLength(1));
      expect(obs.received.single.name, 'evt');
      expect(obs.received.single.sender, 'sender');
      expect(obs.received.single.userInfo, {'key': 'value'});
    });

    test('post() accepts a notification object directly', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt');

      final notification = Notification('evt', 'sender', {'key': 'value'});
      await center.post(notification);

      expect(obs.received.single, same(notification));
    });

    test('only observers registered with the same name receive it', () async {
      final center = NotificationCenter();
      final a = RecordingObserver();
      final b = RecordingObserver();
      center.addObserver(a, 'a-event');
      center.addObserver(b, 'b-event');

      await center.postNotification('a-event', null);

      expect(a.received, hasLength(1));
      expect(b.received, isEmpty);
    });

    test('every observer of the name receives it', () async {
      final center = NotificationCenter();
      final a = RecordingObserver();
      final b = RecordingObserver();
      center.addObserver(a, 'evt');
      center.addObserver(b, 'evt');

      await center.postNotification('evt', null);

      expect(a.received, hasLength(1));
      expect(b.received, hasLength(1));
    });

    test('duplicate registration receives only once', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt');
      center.addObserver(obs, 'evt');

      await center.postNotification('evt', null);

      expect(obs.received, hasLength(1));
    });

    test('posting without listeners completes normally', () async {
      await NotificationCenter().postNotification('nobody', null);
    });

    test('post() awaits all observers before returning', () async {
      final center = NotificationCenter();
      final slow = SlowObserver('evt');
      final fast = RecordingObserver();
      center.addObserver(slow, 'evt');
      center.addObserver(fast, 'evt');

      await center.postNotification('evt', null);

      expect(slow.done, isTrue);
      expect(fast.received, hasLength(1));
    });
  });

  group('NotificationCenter.removeObserver', () {

    test('with a name only unbinds that name', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt-1');
      center.addObserver(obs, 'evt-2');

      center.removeObserver(obs, 'evt-1');
      await center.postNotification('evt-1', null);
      await center.postNotification('evt-2', null);

      expect(obs.received.map((n) => n.name), ['evt-2']);
    });

    test('without a name unbinds all names', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt-1');
      center.addObserver(obs, 'evt-2');

      center.removeObserver(obs);
      await center.postNotification('evt-1', null);
      await center.postNotification('evt-2', null);

      expect(obs.received, isEmpty);
    });

    test('removing an unknown observer is a no-op', () {
      final center = NotificationCenter();
      center.removeObserver(RecordingObserver(), 'never-registered');
      center.removeObserver(RecordingObserver());
    });

    test('observer can re-register after removal', () async {
      final center = NotificationCenter();
      final obs = RecordingObserver();
      center.addObserver(obs, 'evt');
      center.removeObserver(obs, 'evt');

      center.addObserver(obs, 'evt');
      await center.postNotification('evt', null);

      expect(obs.received, hasLength(1));
    });
  });

  group('NotificationCenter error isolation', () {

    test('a synchronous error in one observer keeps others working', () async {
      final center = NotificationCenter();
      final bad = ThrowingObserver();
      final good = RecordingObserver();
      center.addObserver(bad, 'evt');
      center.addObserver(good, 'evt');

      await center.postNotification('evt', null);

      expect(good.received, hasLength(1));
    });

    test('an async error in one observer keeps others working', () async {
      final center = NotificationCenter();
      final bad = AsyncThrowingObserver();
      final good = RecordingObserver();
      center.addObserver(bad, 'evt');
      center.addObserver(good, 'evt');

      await center.postNotification('evt', null);

      expect(good.received, hasLength(1));
    });
  });

  group('NotificationCenter dispatch snapshot', () {

    test('removal during dispatch does not affect the current post', () async {
      final center = NotificationCenter();
      final obs = SelfRemovingObserver(center);
      center.addObserver(obs, 'evt');

      await center.postNotification('evt', null);
      expect(obs.received, hasLength(1)); // received from the snapshot

      await center.postNotification('evt', null);
      expect(obs.received, hasLength(1)); // already removed, no more delivery
    });
  });

  group('Notification', () {

    test('carries name, sender and userInfo', () {
      final info = {'k': 'v'};
      final n = Notification('evt', 'sender', info);

      expect(n.name, 'evt');
      expect(n.sender, 'sender');
      expect(n.userInfo, same(info));
    });

    test('toString exposes the fields', () {
      final n = Notification('evt', 'sender', {'k': 'v'});

      expect(n.toString(), contains('<Notification name="evt">'));
      expect(n.toString(), contains('<sender>sender</sender>'));
      expect(n.toString(), contains('{k: v}'));
    });
  });
}
