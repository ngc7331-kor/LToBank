import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bank_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🏦 초기 데이터 시딩 (계좌가 없을 경우 생성)
  Future<void> checkAndInitialize(String name) async {
    final doc = await _db.collection('banks').doc(name).get();
    if (!doc.exists) {
      await _db.collection('banks').doc(name).set({
        'name': name == 'cw' ? '채원' : '도권',
        'currentBalance': 0,
        'totalBalance': 0,
        'interest': 0,
      });
    }
  }

  // 🏦 개인 잔액 정보 실시간 감시 (cw, dk)
  Stream<BankData> getBankData(String name) {
    return _db
        .collection('banks')
        .doc(name)
        .snapshots()
        .map((doc) => BankData.fromFirestore(doc));
  }

  // 📝 모든 거래 내역 가져오기 (날짜순)
  Stream<List<BankTransaction>> getTransactions(String name) {
    return _db
        .collection('banks')
        .doc(name)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BankTransaction.fromFirestore(doc))
            .toList());
  }

  // 🔔 승인 대기 항목 가져오기 (아빠 전용)
  Stream<List<BankTransaction>> getPendingTransactions() {
    return _db
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BankTransaction.fromFirestore(doc))
            .toList());
  }

  // ➕ 새로운 거래 요청 (승인 대기함으로 이동)
  Future<void> requestTransaction(BankTransaction tx) async {
    await _db.collection('approvals').add(tx.toMap());
  }

  // ✅ 거래 승인 처리 (잔액 업데이트 포함된 Batch 작업)
  Future<void> approveTransaction(String approvalId, BankTransaction tx) async {
    WriteBatch batch = _db.batch();

    final bankRef = _db.collection('banks').doc(tx.name);
    final approvalRef = _db.collection('approvals').doc(approvalId);
    final txRef = bankRef.collection('transactions').doc();

    // 1. 승인 상태 변경
    batch.update(approvalRef, {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // 2. 실제 개인 거래 내역에 추가
    batch.set(txRef, {
      ...tx.toMap(),
      'status': 'approved',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. 잔액 업데이트 (중요!)
    int amountChange = (tx.type == '입금') ? tx.amount : -tx.amount;
    batch.update(bankRef, {
      'currentBalance': FieldValue.increment(amountChange),
      'totalBalance': FieldValue.increment(amountChange),
    });

    await batch.commit();
  }

  // ❌ 거래 거절 처리
  Future<void> rejectTransaction(String approvalId) async {
    await _db.collection('approvals').doc(approvalId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🗑️ 승인 대기 항목 삭제 (취소)
  Future<void> deletePendingTransaction(String id) async {
    await _db.collection('approvals').doc(id).delete();
  }

  // ✏️ 승인 대기 항목 수정
  Future<void> updatePendingTransaction(String id, BankTransaction tx) async {
    await _db.collection('approvals').doc(id).update({
      ...tx.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
