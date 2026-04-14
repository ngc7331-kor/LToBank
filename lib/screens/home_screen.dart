import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';
import 'approval_screen.dart';
import 'request_transaction_screen.dart';
import 'transaction_history_screen.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseService();
  final auth = AuthService();
  final user = FirebaseAuth.instance.currentUser;

  String? get _effectiveEmail => user?.email;
  bool get _isParent => auth.isParent;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.jpg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'L.To Bank',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.signOut();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? constraints.maxWidth * 0.1 : 20,
                vertical: 16
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(),
                  const SizedBox(height: 16),
                  
                  _buildPendingApprovalAlert(),
                  _buildMyPendingRequests(),
                  
                  Text(
                    _isParent ? '아이들의 계좌 현황' : '내 계좌 현황',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildBalanceGrids(isWide),
                  
                  const SizedBox(height: 36),
                  _buildRecentTransactionsSection(),
                  
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RequestTransactionScreen()),
          );
        },
        elevation: 4,
        label: Text('거래 등록', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildBalanceGrids(bool isWide) {
    return StreamBuilder<BankData>(
      stream: db.getBankData('cw'),
      builder: (context, cwSnapshot) {
        return StreamBuilder<BankData>(
          stream: db.getBankData('dk'),
          builder: (context, dkSnapshot) {
            if (cwSnapshot.connectionState == ConnectionState.waiting || 
                dkSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ));
            }

            final cwData = cwSnapshot.data ?? BankData(name: '채원', currentBalance: 0, totalBalance: 0, interest: 0);
            final dkData = dkSnapshot.data ?? BankData(name: '도권', currentBalance: 0, totalBalance: 0, interest: 0);

            final email = _effectiveEmail ?? '';
            final role = AuthService.emailRoleMap[email];
            final isCW = role == 'cw';
            final isDK = role == 'dk';

            final List<Widget> cards = [];
            if (_isParent || isCW) {
              cards.add(BalanceCard(
                data: cwData, 
                onTap: () => _openHistory(context, 'cw'),
                isChildView: ! _isParent, // 자녀뷰일 때 강조
              ));
            }
            if (_isParent || isDK) {
              cards.add(BalanceCard(
                data: dkData, 
                onTap: () => _openHistory(context, 'dk'),
                isChildView: ! _isParent, // 자녀뷰일 때 강조
              ));
            }

            if (cards.isEmpty) {
              return const Center(child: Text('등록된 연동 계좌가 없습니다.'));
            }

            // 모바일 환경에서도 2개면 가로 배치 (Row)
            if (cards.length >= 2) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              );
            } else {
              return cards[0];
            }
          },
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.transparent,
              child: ClipOval(
                child: Image.asset('assets/logo.jpg', width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3B82F6), size: 30),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반가워요, ${_getRealName(_effectiveEmail)}님',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '오늘도 스마트한 저축 습관을 응원해요! 💰',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalAlert() {
    if (!_isParent) return const SizedBox.shrink();

    return StreamBuilder<List<BankTransaction>>(
      stream: db.getPendingTransactions(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.length ?? 0;
        if (pendingCount == 0) return const SizedBox.shrink(); // 데이터 없으면 예시 없이 숨김

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApprovalScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF451A03).withOpacity(0.4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF78350F).withOpacity(0.5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active_rounded, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '승인 대기', // 부모 계정일 때 "승인 대기"
                        style: GoogleFonts.notoSansKr(
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '총 $pendingCount건의 요청이 기다리고 있어요!',
                        style: GoogleFonts.notoSansKr(
                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyPendingRequests() {
    if (_isParent) return const SizedBox.shrink();

    final role = AuthService.emailRoleMap[_effectiveEmail];
    final bankId = (role == 'cw' || role == 'dk') ? role : null;
    
    if (bankId == null) return const SizedBox.shrink();

    return StreamBuilder<List<BankTransaction>>(
      stream: db.getPendingTransactions(), // 자녀도 approvals 컬렉션을 봅니다.
      builder: (context, approvalsSnapshot) {
        final myPendingCount = approvalsSnapshot.data
                ?.where((tx) => tx.name == bankId) // 내 계좌(cw/dk) 요청만 필터링
                .length ??
            0;

        if (myPendingCount == 0) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApprovalScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withOpacity(0.6)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E40AF).withOpacity(0.3)
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hourglass_empty_rounded,
                      color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '승인 요청중', // 자녀 계정일 때는 "승인 요청중"
                        style: GoogleFonts.notoSansKr(
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '아빠의 승인을 기다리는 요청이 $myPendingCount건 있어요.',
                        style: GoogleFonts.notoSansKr(
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, 
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openHistory(BuildContext context, String bankId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(bankId: bankId),
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 입출금 내역',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<BankTransaction>>(
          stream: db.getTransactions('cw'),
          builder: (context, cwTx) {
            return StreamBuilder<List<BankTransaction>>(
              stream: db.getTransactions('dk'),
              builder: (context, dkTx) {
                if (cwTx.connectionState == ConnectionState.waiting ||
                    dkTx.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final email = _effectiveEmail ?? '';
                final role = AuthService.emailRoleMap[email];
                final isCW = role == 'cw';
                final isDK = role == 'dk';
                
                List<BankTransaction> allTxs = [];
                if (_isParent || isCW) {
                  allTxs.addAll(cwTx.data ?? []);
                }
                if (_isParent || isDK) {
                  allTxs.addAll(dkTx.data ?? []);
                }
                allTxs.sort((a, b) => (b.timestamp ?? DateTime.now()).compareTo(a.timestamp ?? DateTime.now()));

                final recentTxs = allTxs.take(10).toList();

                if (recentTxs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        '최근 거래 내역이 없습니다.',
                        style: GoogleFonts.notoSansKr(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: recentTxs.map((tx) => TransactionTile(tx: tx)).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _getRealName(String? email) {
    return AuthService.getNameByEmail(email);
  }
}
