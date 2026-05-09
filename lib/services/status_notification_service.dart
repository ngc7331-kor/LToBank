import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/bank_model.dart';

class StatusNotificationService {
  static final StatusNotificationService _instance = StatusNotificationService._internal();
  factory StatusNotificationService() => _instance;
  StatusNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'ltobank_status_bar';
  static const String channelName = 'L.To Bank \uc0c1\ud0dc \ubc14';

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings: initSettings);

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: '\uc2b9\uc778 \ub300\uae30 \uc0c1\ud0dc\ub97c \uc2e4\uc2dc\uac04\uc73c\ub85c \ubcf4\uc5ec\uc90d\ub2c8\ub2e4.',
      importance: Importance.low,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> updateStatus(List<BankTransaction> pendingTxs) async {
    if (pendingTxs.isEmpty) {
      await _notifications.cancel(id: 1001);
      await _notifications.cancel(id: 1002);
      return;
    }

    final cwTxs = pendingTxs.where((tx) => tx.name == 'cw').toList();
    if (cwTxs.isNotEmpty) {
      _showPersistentNotification(
        id: 1001,
        title: '\ud83c\udf6b \ucc44\ub110\uc774\uac00 \uc904\uc744 \uc130\uc5b4\uc694!',
        body: '\uc2b9\uc778 \ub300\uae30 \uac74\uc218\uac00 \${cwTxs.length}\uac74 \uc788\uc2b5\ub2cc\ub2e4. \ud655\uc778\ud574 \uc8fc\uc138\uc694!',
      );
    } else {
      await _notifications.cancel(id: 1001);
    }

    final dkTxs = pendingTxs.where((tx) => tx.name == 'dk').toList();
    if (dkTxs.isNotEmpty) {
      _showPersistentNotification(
        id: 1002,
        title: '\ud83d\ude80 \ub3c4\uad8c\uc774\uc758 \uae34\uae09 \uc694\ucdad!',
        body: '\uc544\ube60\uc758 \ube5b\ub098\ub294 \uc2b9\uc778\uc744 \uae30\ub2e4\ub9ac\ub294 \uc694\ucdad\uc774 \${dkTxs.length}\uac74 \uc788\uc5b4\uc694.',
      );
    } else {
      await _notifications.cancel(id: 1002);
    }
  }

  Future<void> _showPersistentNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      ongoing: true,
      autoCancel: false,
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
      styleInformation: BigTextStyleInformation(body),
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }
}
