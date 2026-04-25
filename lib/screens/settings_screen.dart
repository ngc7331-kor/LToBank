import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '설정',
          style: GoogleFonts.notoSansKr(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('계정 정보'),
            const SizedBox(height: 12),
            _buildProfileCard(context, user, auth),
            const SizedBox(height: 32),
            _buildSectionTitle('앱 정보'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context,
              items: [
                _SettingsItem(
                  icon: Icons.info_outline_rounded,
                  title: '앱 버전',
                  trailing: 'v50.0',
                ),
                _SettingsItem(
                  icon: Icons.description_outlined,
                  title: '오픈소스 라이선스',
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(context, auth),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, User? user, AuthService auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = user?.email ?? '알 수 없음';
    final name = auth.userRealName;
    final role = auth.isParent ? '관리자(부모님)' : '사용자(자녀)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
            child: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<_SettingsItem> items}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 56,
          endIndent: 20,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            onTap: item.onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: const Color(0xFF64748B), size: 20),
            ),
            title: Text(
              item.title,
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            trailing: item.trailing != null
                ? Text(
                    item.trailing!,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: const Color(0xFFCBD5E1), size: 24),
          );
        },
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
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
          if (context.mounted) Navigator.pop(context); // 설정창 닫기
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            '로그아웃',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
}
