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

    _cwSub = _db.getBankData('cw').listen((data) {
      _cwTotal = data.totalBalance;
      _cwInterest = data.interest;
      _updateWidget();
    });

    _dkSub = _db.getBankData('dk').listen((data) {
      _dkTotal = data.totalBalance;
      _dkInterest = data.interest;
      _updateWidget();
    });

    _pendingSub = _db.getPendingTransactions().listen((txs) {
      _pendingCount = txs.length;
      _updateWidget();
    });
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

    WidgetService.updateWidgetData(
      pendingCount: _pendingCount,
      cwTotal: _cwTotal,
      cwInterest: _cwInterest,
      dkTotal: _dkTotal,
      dkInterest: _dkInterest,
      userRole: role,
    );
  }
}
