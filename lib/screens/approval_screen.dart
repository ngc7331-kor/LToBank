import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'request_transaction_screen.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final db = DatabaseService();
  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final isParent = auth.isParent;
    final email = auth.userEmail ?? '';
    final myId = email.contains('cw') ? 'cw' : (email.contains('dk') ? 'dk' : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isParent ? '승인 대기' : '승인 요청중', 
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<BankTransaction>>(
        stream: db.getPendingTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<BankTransaction> transactions = snapshot.data ?? [];
          
          // 자녀인 경우 본인 요청만 필터링
          if (!isParent && myId != null) {
            transactions = transactions.where((tx) => tx.name == myId).toList();
          }

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('대기 중인 요청이 없습니다.', style: GoogleFonts.notoSansKr(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildApprovalCard(tx, isParent);
            },
          );
        },
      ),
    );
  }

  Widget _buildApprovalCard(BankTransaction tx, bool isParent) {
    final isDeposit = tx.type == '입금';
    final targetName = tx.name == 'cw' ? '채원' : '도권';
    final displayName = _getDisplayName(tx.recorder);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🆕 상단 날짜 및 신청자 정보 (강조)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '날짜',
                    style: GoogleFonts.notoSansKr(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    tx.date,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDeposit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tx.type,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDeposit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 🆕 신청자 정보
          Row(
            children: [
              Icon(Icons.person_pin_rounded, size: 18, color: Colors.blueGrey[300]),
              const SizedBox(width: 6),
              Text(
                '신청자: ',
                style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
              ),
              Text(
                displayName,
                style: GoogleFonts.notoSansKr(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$targetName 계좌 요청',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          // 🆕 금액 표시 (원 추가)
          Text(
            '₩${tx.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
            style: GoogleFonts.outfit(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          if (isParent)
            _buildParentButtons(tx)
          else
            _buildChildButtons(tx),
        ],
      ),
    );
  }

  Widget _buildParentButtons(BankTransaction tx) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => _confirmAction('거절', () => db.rejectTransaction(tx.id)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              '거절',
              style: GoogleFonts.notoSansKr(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await db.approveTransaction(tx.id, tx);
              try {
                final amountStr = tx.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
                await FCMService().sendPushMessage(
                  targetRoleOrName: tx.name,
                  title: '거래 승인 완료',
                  body: '${tx.type} ${amountStr}원이 거래 승인 되었습니다.',
                );
              } catch (e) { print('Push notification error: $e'); }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('승인하기', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildChildButtons(BankTransaction tx) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => _confirmAction('취소', () => db.deletePendingTransaction(tx.id)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              '요청 취소',
              style: GoogleFonts.notoSansKr(color: const Color(0xFFDC2626), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RequestTransactionScreen(initialTransaction: tx)),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('수정하기', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  void _confirmAction(String title, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('정말 이 요청을 $title하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('아니오')),
          TextButton(onPressed: () async {
            await action();
            if (mounted) Navigator.pop(ctx);
          }, child: Text(title, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  String _getDisplayName(String email) {
    final normalizedEmail = email.toLowerCase();
    if (normalizedEmail == 'ngc7331cw@gmail.com' || normalizedEmail == 'taeoh0317@gmail.com' || normalizedEmail == 'cw') return '채원';
    if (normalizedEmail == 'ngc7331dk@gmail.com' || normalizedEmail == 'taeoh0318@gmail.com' || normalizedEmail == 'dk') return '도권';
    if (normalizedEmail == 'taeoh0311@gmail.com') return '태오';
    return email.split('@').first;
  }
}
