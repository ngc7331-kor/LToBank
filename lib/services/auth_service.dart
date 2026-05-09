import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '35323267785-oqueflp0he6ot8jphtq8dqobpt6k2hp7.apps.googleusercontent.com',
  );

  // 👤 현재 로그인한 사용자의 정보 캐싱 (메모리에 임시 저장)
  String? _cachedRole;
  String? _cachedName;

  // 👤 사용자의 역할(Role) 가져오기
  String get userRole => _cachedRole ?? 'user';
  
  // 👤 사용자의 실명 가져오기
  String get userRealName => _cachedName ?? (userEmail?.split('@').first ?? '사용자');

  // 👤 UID 기반으로 DB에서 역할과 이름을 가져와 캐싱하는 함수
  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _cachedRole = data['role'] as String?;
        _cachedName = data['realName'] as String?;
        print('User profile loaded: $_cachedRole, $_cachedName');
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // 🚪 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        final email = user.email?.toLowerCase() ?? '';
        
        // 🛡️ [Security] DB에서 유저 정보 로드 및 캐싱
        await loadUserProfile();
        
        try {
          final token = await FCMService().getToken();
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': email,
            'fcmToken': token,
            'lastLogin': FieldValue.serverTimestamp(),
            // role은 이미 DB에 있거나 관리자가 부여함
          }, SetOptions(merge: true));
        } catch (e) {
          print('FCM Token Save Error: $e');
        }
      }
      return user;
    } catch (e) {
      print('Sign-In Error: $e');
      rethrow;
    }
  }

  // 🚪 로그아웃
  Future<void> signOut() async {
    _cachedRole = null;
    _cachedName = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 👤 현재 사용자 이메일
  String? get userEmail => _auth.currentUser?.email;
  
  // 👨‍👩‍👧‍👦 권한 확인 (캐싱된 role 사용)
  bool get isParent => userRole == 'admin' || userRole == 'parent';
}
