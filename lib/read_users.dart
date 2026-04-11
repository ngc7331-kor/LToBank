import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ltobank/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('--- Checking Users Collection ---');
  final snapshot = await FirebaseFirestore.instance.collection('users').get();
  for (var doc in snapshot.docs) {
    print('User: ${doc.id} | Email: ${doc.data()['email']}');
  }
  print('--- End of List ---');
}
