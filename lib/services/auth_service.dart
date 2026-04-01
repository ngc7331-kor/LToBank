import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '35323267785-oqueflp0he6ot8jphtq8dqobpt6k2hp7.apps.googleusercontent.com',
  );

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
      print('Firebase Sign-In successful: \${userCredential.user?.email}');
      
      final user = userCredential.user;
      if (user != null) {
        // 🛡️ [Security] 진짜 이메일 화이트리스트 체크 (3인만 허용)
        final allowedEmails = [
          'father@example.com', // 아빠
          'chaewon@example.com', // 채원
          'dokwon@example.com', // 도권
        ];

        if (!allowedEmails.contains(user.email)) {
          print('Unauthorized access attempt: \${user.email}');
          await signOut(); // 즉시 로그아웃
          throw FirebaseAuthException(
            code: 'unauthorized-user',
            message: '허용된 사용자가 아닙니다. (가족 전용 계정으로 로그인해주세요)',
          );
        }

        try {
          final token = await FCMService().getToken();
          if (token != null) {
            // 이메일 기반 역할 판별
            String role = 'admin';
            if (user.email == 'chaewon@example.com') role = 'cw';
            if (user.email == 'dokwon@example.com') role = 'dk';

            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': user.email,
              'fcmToken': token,
              'lastLogin': FieldValue.serverTimestamp(),
              'role': role,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          print('FCM Token Save Error: \$e');
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
  bool get isParent => userEmail == 'father@example.com'; // 사용자님 이메일 기준
}
