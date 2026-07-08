import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import 'package:frontend_app/pages/employees_page.dart';
import 'package:frontend_app/pages/feedback_mail_page.dart';
import 'package:frontend_app/pages/help_page.dart';
import 'package:frontend_app/pages/notification_settings_page.dart';
import 'package:frontend_app/pages/profile_page.dart';
import 'package:frontend_app/pages/stock_history_page.dart';
import 'package:frontend_app/services/api_service.dart';

const Color kBrand = Color(0xFF00C2F3);

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String? _role;

  bool get isEmployee => (_role ?? '').toLowerCase() == 'employee';
  bool get _roleLoaded => _role != null;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final r = await ApiService.getSelectedShopRole();
    if (!mounted) return;
    setState(() => _role = (r ?? '').toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: kBrand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'app_name'.tr(), // ✅ เปลี่ยนเป็นภาษาแบบ Dynamic
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _sectionTitle('more.general'.tr()), // ✅
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.person_outline,
            title: 'more.profile'.tr(), // ✅
            subtitle: 'more.profile_desc'.tr(), // ✅
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.notifications_none,
            title: 'more.notifications'.tr(), // ✅
            subtitle: 'more.notifications_desc'.tr(), // ✅
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
            ),
          ),

          const SizedBox(height: 18),
          _sectionTitle('more.warehouse'.tr()), // ✅
          const SizedBox(height: 10),

          _tile(
            context,
            icon: Icons.history_rounded,
            title: 'more.stock_history'.tr(), // ✅
            subtitle: 'more.stock_history_desc'.tr(), // ✅
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockHistoryPage()),
            ),
          ),

          const SizedBox(height: 10),

          if (_roleLoaded && !isEmployee)
            _tile(
              context,
              icon: Icons.badge_outlined,
              title: 'more.employees'.tr(), // ✅
              subtitle: 'more.employees_desc'.tr(), // ✅
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeesPage()),
              ),
            ),

          const SizedBox(height: 18),
          _sectionTitle('more.support'.tr()), // ✅
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.help_outline,
            title: 'more.help'.tr(), // ✅
            subtitle: 'more.help_desc'.tr(), // ✅
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.email_outlined,
            title: 'more.feedback'.tr(), // ✅
            subtitle: 'more.feedback_desc'.tr(), // ✅
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackMailPage()),
            ),
          ),

          // ✅ เพิ่มส่วน "ตั้งค่า" สำหรับเปลี่ยนภาษา
          const SizedBox(height: 18),
          _sectionTitle('more.settings_section'.tr()),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.language,
            title: 'more.change_language'.tr(),
            subtitle: context.locale.languageCode == 'th' ? 'ภาษาไทย' : 'English',
            onTap: () {
              _showLanguageDialog(context);
            },
          ),
        ],
      ),
    );
  }

  // ✅ ฟังก์ชันแสดงหน้าต่างเปลี่ยนภาษา
  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.g_translate, color: kBrand),
                title: const Text('ภาษาไทย', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: context.locale.languageCode == 'th' ? const Icon(Icons.check_circle, color: kBrand) : null,
                onTap: () {
                  context.setLocale(const Locale('th'));
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language, color: kBrand),
                title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: context.locale.languageCode == 'en' ? const Icon(Icons.check_circle, color: kBrand) : null,
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.black.withOpacity(0.70),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBrand.withOpacity(0.30), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kBrand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBrand.withOpacity(0.35), width: 1.2),
                ),
                child: Icon(icon, color: kBrand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}