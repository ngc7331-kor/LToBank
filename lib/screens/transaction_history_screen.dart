import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_model.dart';
import '../services/database_service.dart';
import '../widgets/transaction_tile.dart';

class TransactionHistoryScreen extends StatelessWidget {
  final String bankId;
  const TransactionHistoryScreen({super.key, required this.bankId});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final bankName = bankId == 'cw' ? '채원' : '도권';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '$bankName 계좌 내역',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: StreamBuilder<List<BankTransaction>>(
        stream: db.getTransactions(bankId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final txs = snapshot.data ?? [];

          if (txs.isEmpty) {
            return Center(
              child: Text(
                '거래 내역이 없습니다.',
                style: GoogleFonts.notoSansKr(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: txs.length,
            itemBuilder: (context, index) {
              return TransactionTile(tx: txs[index]);
            },
          );
        },
      ),
    );
  }
}
