import 'package:cloud_firestore/cloud_firestore.dart';

class BankData {
  final String name;
  final int currentBalance;
  final int totalBalance;
  final int interest;

  BankData({
    required this.name,
    required this.currentBalance,
    required this.totalBalance,
    required this.interest,
  });

  factory BankData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return BankData(
      name: data['name'] ?? '',
      currentBalance: data['currentBalance'] ?? 0,
      totalBalance: data['totalBalance'] ?? 0,
      interest: data['interest'] ?? 0,
    );
  }

  // 🤖 GAS 데이터에서 생성 (v5.4)
  factory BankData.fromGas(String name, Map<String, dynamic> json) {
    // GAS widget 데이터 구조: { cwTotal, dkTotal, cwInterest, dkInterest }
    final prefix = name.toLowerCase();
    return BankData(
      name: name == 'cw' ? '채원' : '도권',
      currentBalance: (json['${prefix}Total'] as num?)?.toInt() ?? 0,
      totalBalance: (json['${prefix}Total'] as num?)?.toInt() ?? 0, // 현재는 합산된 값이 오므로 동일하게 처리
      interest: (json['${prefix}Interest'] as num?)?.toInt() ?? 0,
    );
  }
}

class BankTransaction {
  final String id;
  final String date;
  final String name; // 대상 (채원, 도권)
  final String type; // 입금, 출금
  final int amount;
  final int balance;
  final String recorder;
  final String status; // 대기중, 승인됨, 거절됨
  final DateTime? timestamp;

  BankTransaction({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.amount,
    required this.balance,
    required this.recorder,
    required this.status,
    this.timestamp,
  });

  factory BankTransaction.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return BankTransaction(
      id: doc.id,
      date: data['date'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      amount: data['amount'] ?? 0,
      balance: data['balance'] ?? 0,
      recorder: data['recorder'] ?? '',
      status: data['status'] ?? '승인됨',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  // 🤖 GAS 데이터에서 생성 (v5.4)
  factory BankTransaction.fromGas(Map<String, dynamic> json) {
    return BankTransaction(
      id: json['id']?.toString() ?? json['uniqueId']?.toString() ?? '',
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      recorder: json['recorder'] ?? '',
      status: json['status'] ?? '승인됨',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'name': name,
      'type': type,
      'amount': amount,
      'balance': balance,
      'recorder': recorder,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // 🤖 GAS 전송용 맵 생성 (v5.4)
  Map<String, dynamic> toGasMap() {
    return {
      'date': date,
      'name': name,
      'type': type,
      'amount': amount,
      'recorder': recorder,
    };
  }
}
