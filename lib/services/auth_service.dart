import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '35323267785-oqueflp0he6ot8jphtq8dqobpt6k2hp7.apps.googleusercontent.com',
  );

  // 👤 이메일-역할 매매핑 (전체 주소 기반 정확한 인식)
  static const Map<String, String> emailRoleMap = {
    'taeoh0311@gmail.com': 'admin',
    'ngc7331cw@gmail.com': 'cw',
    'taeoh0317@gmail.com': 'cw', // 채원 새 계정
    'ngc7331dk@gmail.com': 'dk',
    'taeoh0318@gmail.com': 'dk', // 도권 새 계정
  };

  // 🚪 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In cancelled by user.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print('Google Auth completed. Obtaining credentials...');

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      print('Firebase Sign-In successful: ${userCredential.user?.email}');
      
      final user = userCredential.user;
      if (user != null) {
        final email = user.email?.toLowerCase() ?? '';
        // 🛡️ [Security] 이메일 화이트리스트 체크 (대소문자 무시)
        if (!emailRoleMap.containsKey(email)) {
          print('Unauthorized access attempt: $email');
          await signOut(); // 즉시 로그아웃
          throw FirebaseAuthException(
            code: 'unauthorized-user',
            message: '허용된 사용자가 아닙니다. ($email)',
          );
        }

        try {
          final token = await FCMService().getToken();
          if (token != null) {
            // 이메일 기반 역할 판별 (Map 참조)
            String role = emailRoleMap[email] ?? 'admin';

            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': user.email,
              'fcmToken': token,
              'lastLogin': FieldValue.serverTimestamp(),
              'role': role,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          print('FCM Token Save Error: $e');
        }
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected Sign-In Error: $e');
      rethrow;
    }
  }

  // 🚪 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 👤 현재 사용자 이메일
  String? get userEmail => _auth.currentUser?.email;

  // 👨‍👩‍👧‍👦 권한 확인 (간이 버전, 실제로는 Firestore users 컬렉션 권장)
  bool get isParent => userEmail == 'taeoh0311@gmail.com'; // 사용자님 이메일 기준
}
