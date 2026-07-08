import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา
import 'scan_label_page.dart';
import 'scan_barcode_in_page.dart';
import 'scan_barcode_out_page.dart';

class ScanCenterPage extends StatelessWidget {
  const ScanCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('scan.center_title'.tr(), // ✅
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'scan.select_type'.tr(), // ✅
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'scan.select_type_desc'.tr(), // ✅
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: ListView(
                children: [
                  _BigActionCard(
                    title: 'scan.ocr_title'.tr(), // ✅
                    subtitle: 'scan.ocr_desc'.tr(), // ✅
                    icon: Icons.document_scanner_outlined,
                    accent: bg,
                    onTap: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanLabelPage(),
                        ),
                      );

                      if (result != null && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _BigActionCard(
                    title: 'scan.barcode_title'.tr(), // ✅
                    subtitle: 'scan.barcode_desc'.tr(), // ✅
                    icon: Icons.qr_code_scanner,
                    accent: bg,
                    onTap: () {
                      _openBarcodeSheet(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBarcodeSheet(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'scan.barcode_mode'.tr(), // ✅
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'scan.btn_scan_in'.tr(),  // ✅ ดึงคำว่า SCAN IN หรือ สแกนรับเข้า
                      icon: Icons.call_received,
                      color: bg,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScanBarcodeInPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeButton(
                      label: 'scan.btn_scan_out'.tr(), // ✅ ดึงคำว่า SCAN OUT หรือ สแกนเบิกออก
                      icon: Icons.call_made,
                      color: bg,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScanBarcodeOutPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'scan.ui_hint'.tr(), // ✅
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}