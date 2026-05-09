import 'package:home_widget/home_widget.dart';
import 'auth_service.dart';

class WidgetSyncService {
  static const String _androidWidgetName = 'LToBankWidget';

  // 🔄 [우리집 세금 방식] HomeWidget 전용 저장소만 사용
  static Future<void> syncWidgetData({
    String? cwTotal,
    String? dkTotal,
    String? cwInterest,
    String? dkInterest,
    int? pendingCount,
  }) async {
    try {
      final auth = AuthService();
      
      // 🏷️ flutter. 접두사가 없는 순수한 이름으로 저장 (우리집 세금의 핵심 비결)
      await HomeWidget.saveWidgetData<bool>('isLoggedIn', true);
      await HomeWidget.saveWidgetData<String>('userRole', auth.userRole);
      
      if (cwTotal != null) await HomeWidget.saveWidgetData<String>('cwTotal', cwTotal);
      if (dkTotal != null) await HomeWidget.saveWidgetData<String>('dkTotal', dkTotal);
      if (cwInterest != null) await HomeWidget.saveWidgetData<String>('cwInterest', cwInterest);
      if (dkInterest != null) await HomeWidget.saveWidgetData<String>('dkInterest', dkInterest);
      if (pendingCount != null) await HomeWidget.saveWidgetData<int>('pendingCount', pendingCount);
      
      await HomeWidget.saveWidgetData<String>('workerStatus', 'active');
      
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      await HomeWidget.saveWidgetData<String>('updateTime', timeStr);

      // 🚀 위젯 새로고침 신호
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (e) {
      print('Widget sync error: $e');
    }
  }
}
