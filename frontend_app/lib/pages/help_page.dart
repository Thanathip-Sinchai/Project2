import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('help.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _HelpCard(
              title: 'help.faq_1_q'.tr(), // ✅
              body: 'help.faq_1_a'.tr(), // ✅
            ),
            const SizedBox(height: 12),
            _HelpCard(
              title: 'help.faq_2_q'.tr(), // ✅
              body: 'help.faq_2_a'.tr(), // ✅
            ),
            const SizedBox(height: 12),
            _HelpCard(
              title: 'help.faq_3_q'.tr(), // ✅
              body: 'help.faq_3_a'.tr(), // ✅
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final String body;

  const _HelpCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}