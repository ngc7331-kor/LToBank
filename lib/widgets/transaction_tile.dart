import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_model.dart';

class TransactionTile extends StatelessWidget {
  final BankTransaction tx;

  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    bool isDeposit = tx.type == '입금';
    final targetName = tx.name == 'cw' ? '채원' : tx.name == 'dk' ? '도권' : tx.name;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final shadowColor = isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF0F172A).withOpacity(0.03);
    
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dateColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final iconBgColorIn = isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFECFDF5);
    final iconColorIn = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
    final iconBgColorOut = isDark ? const Color(0xFF7F1D1D).withOpacity(0.5) : const Color(0xFFFEF2F2);
    final iconColorOut = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDeposit ? iconBgColorIn : iconBgColorOut,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isDeposit ? iconColorIn : iconColorOut,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isDeposit ? '입금' : '출금',
                      style: GoogleFonts.notoSansKr(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      targetName,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.date} · ${tx.recorder}',
                  style: GoogleFonts.notoSansKr(
                    color: dateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'} ₩${tx.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: isDeposit ? iconColorIn : iconColorOut,
                ),
              ),
              const SizedBox(height: 2),
              if (tx.balance > 0)
                Text(
                  '잔액 ₩${tx.balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}',
                  style: GoogleFonts.outfit(
                    color: subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
