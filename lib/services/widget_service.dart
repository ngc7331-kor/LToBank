import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String androidWidgetName = 'LToBankWidget';

  static Future<void> updateLogoutState() async {
    await HomeWidget.saveWidgetData('isLoggedIn', false);
    await HomeWidget.updateWidget(name: androidWidgetName);
  }

  static Future<void> updateWidgetData({
    required int pendingCount,
    required int cwTotal,
    required int cwInterest,
    required int dkTotal,
    required int dkInterest,
    required String userRole, // 'parent', 'cw', 'dk'
  }) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await HomeWidget.saveWidgetData('isLoggedIn', true);
    await HomeWidget.saveWidgetData('userRole', userRole);
    await HomeWidget.saveWidgetData('pendingCount', pendingCount);
    await HomeWidget.saveWidgetData('cwTotal', _formatNum(cwTotal));
    await HomeWidget.saveWidgetData('cwInterest', '이자: ${_formatNum(cwInterest)}');
    await HomeWidget.saveWidgetData('dkTotal', _formatNum(dkTotal));
    await HomeWidget.saveWidgetData('dkInterest', '이자: ${_formatNum(dkInterest)}');
    await HomeWidget.saveWidgetData('updateTime', timeStr);

    await HomeWidget.updateWidget(name: androidWidgetName);
  }

  static String _formatNum(int number) {
    return '₩ ${number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}
