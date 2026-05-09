import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_model.dart';

class BalanceCard extends StatelessWidget {
  final BankData data;
  final VoidCallback? onTap;
  final bool isChildView;

  const BalanceCard({
    super.key, 
    required this.data, 
    this.onTap,
    this.isChildView = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCW = data.name == '채원';
    
    final cardColors = isCW
        ? (isDark ? [const Color(0xFF4C0519), const Color(0xFF881337)] : [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)])
        : (isDark ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)] : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]);
        
    final accentColor = isCW
        ? (isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
        
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? cardColors[0] : cardColors[0],
          gradient: LinearGradient(
            colors: cardColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isChildView 
                ? (isDark ? Colors.white.withOpacity(0.2) : accentColor.withOpacity(0.3)) 
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
            width: isChildView ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : accentColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: (isDark ? Colors.white : accentColor).withOpacity(0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.name,
                            style: GoogleFonts.notoSansKr(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '입출금 계좌',
                            style: GoogleFonts.notoSansKr(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCW ? Icons.savings_rounded : Icons.account_balance_wallet_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '저금액',
                        style: GoogleFonts.notoSansKr(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₩ ',
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            data.totalBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '누적 이자',
                          style: GoogleFonts.notoSansKr(
                            color: subTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₩ ${data.interest.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: GoogleFonts.outfit(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
