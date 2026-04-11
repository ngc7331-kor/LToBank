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
        ? (isDark ? [const Color(0xFF9D174D), const Color(0xFF831843)] : [const Color(0xFFFFD6E0), const Color(0xFFFFEFD6)])
        : (isDark ? [const Color(0xFF1E3A8A), const Color(0xFF172554)] : [const Color(0xFFD6E4FF), const Color(0xFFE5D6FF)]);
        
    final spineColor = isCW
        ? (isDark ? const Color(0xFFBE123C) : const Color(0xFFFB7185))
        : (isDark ? const Color(0xFF1D4ED8) : const Color(0xFF60A5FA));
        
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150, // 높이 축소
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cardColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: isChildView 
              ? Border.all(color: Colors.white.withOpacity(0.8), width: 3) 
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.4) : cardColors.last.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 통장 제본(Spine) 라인
            Container(
              width: 12, // 너비 축소
              decoration: BoxDecoration(
                color: spineColor.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => Container(
                  width: 6, height: 1.5, color: Colors.black.withOpacity(0.05)
                )),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12), // 패딩 축소
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data.name,
                            style: GoogleFonts.notoSansKr(
                              color: textColor,
                              fontSize: 12, // 폰트 축소
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.menu_book_rounded, color: subTextColor.withOpacity(0.5), size: 18),
                      ],
                    ),
                    const Spacer(),
                    FittedBox( // 금액이 길어질 경우 대비
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₩ ${data.totalBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 22, // 폰트 축소
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: textColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669), size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '이자: ₩${data.interest}',
                            style: GoogleFonts.notoSansKr(
                              color: subTextColor,
                              fontSize: 10, // 폰트 축소
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
