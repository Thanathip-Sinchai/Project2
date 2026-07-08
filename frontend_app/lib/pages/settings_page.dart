import 'package:flutter/material.dart';
import 'notification_settings_page.dart';
import 'feedback_mail_page.dart';
import 'help_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: Colors.white,

      // ===== APP BAR (ที่กลับที่เดียว) =====
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Stocknova',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ===== BODY =====
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // ===== Notification =====
            _settingsItem(
              icon: Icons.notifications_none,
              text: 'Notification',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // ===== Feedback Mail =====
            _settingsItem(
              icon: Icons.mail_outline,
              text: 'Feedback Mail',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeedbackMailPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // ===== Help =====
            _settingsItem(
              icon: Icons.help_outline,
              text: 'Help',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================= SETTINGS ITEM =================

Widget _settingsItem({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
}) {
  const bg = Color(0xFF00C2F3);

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: bg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: bg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    ),
  );
}
