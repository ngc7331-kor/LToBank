import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'widget_service.dart';
import 'dart:async';

class WidgetSyncService {
  static final WidgetSyncService _instance = WidgetSyncService._internal();
  factory WidgetSyncService() => _instance;
  WidgetSyncService._internal();

  final _db = DatabaseService();
  StreamSubscription? _cwSub;
  StreamSubscription? _dkSub;
  StreamSubscription? _pendingSub;

  int _cwTotal = 0;
  int _cwInterest = 0;
  int _dkTotal = 0;
  int _dkInterest = 0;
  int _pendingCount = 0;

  bool _isInitialized = false;

  void start() {
    if (_isInitialized) return;
    _isInitialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _stopSyncing();
        WidgetService.updateLogoutState();
      } else {
        _startSyncing();
        _updateWidget();
      }
    });
  }

  void _startSyncing() {
    _cwSub?.cancel();
    _dkSub?.cancel();
    _pendingSub?.cancel();

    // 1. 개인 잔액 데이터 스트림
    _cwSub = _db.getBankData('cw').listen((data) {
      _cwTotal = data.totalBalance;
      _cwInterest = data.interest;
      _updateWidget();
    }, onError: (e) => print('WidgetSync Error (CW): $e'));

    _dkSub = _db.getBankData('dk').listen((data) {
      _dkTotal = data.totalBalance;
      _dkInterest = data.interest;
      _updateWidget();
    }, onError: (e) => print('WidgetSync Error (DK): $e'));

    // 2. 전체 승인 대기 내역 스트림 (도권 데이터 누락 해결 핵심)
    _pendingSub = _db.getPendingTransactions().listen((txs) {
      _pendingCount = txs.length;
      _updateWidget(); // 데이터 올 때마다 확실히 위젯 갱신
    }, onError: (e) => print('WidgetSync Error (Pending): $e'));
  }

  void _stopSyncing() {
    _cwSub?.cancel();
    _dkSub?.cancel();
    _pendingSub?.cancel();
  }

  Future<void> _updateWidget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email?.toLowerCase();
    final role = AuthService.emailRoleMap[email] ?? 'parent';
    
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('flutter.userRole', role);

    // v48: 자녀 모드일 경우 본인의 '승인 요청중' 건수만 필터링 (부모는 전체)
    int displayPendingCount = _pendingCount;
    if (role == 'cw' || role == 'dk') {
      // DatabaseService에서 가져온 최신 pending 내역 중 본인 것만 필터링
      final allPending = await _db.getPendingTransactions().first;
      displayPendingCount = allPending.where((tx) => tx.name == role).length;
    }

    WidgetService.updateWidgetData(
      pendingCount: displayPendingCount,
      cwTotal: _cwTotal,
      cwInterest: _cwInterest,
      dkTotal: _dkTotal,
      dkInterest: _dkInterest,
      userRole: role,
    );
  }
}
