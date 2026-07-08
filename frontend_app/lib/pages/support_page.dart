import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const bg = Color(0xFF00C2F3);

  final formKey = GlobalKey<FormState>();
  final subjectCtrl = TextEditingController();
  final messageCtrl = TextEditingController();

  @override
  void dispose() {
    subjectCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('support.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: bg.withOpacity(0.20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('support.faq'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // ✅
                  const SizedBox(height: 12),
                  _FaqItem(
                    q: 'support.faq_1_q'.tr(), // ✅
                    a: 'support.faq_1_a'.tr(), // ✅
                  ),
                  _FaqItem(
                    q: 'support.faq_2_q'.tr(), // ✅
                    a: 'support.faq_2_a'.tr(), // ✅
                  ),
                  _FaqItem(
                    q: 'support.faq_3_q'.tr(), // ✅
                    a: 'support.faq_3_a'.tr(), // ✅
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: bg.withOpacity(0.20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('support.contact_us'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // ✅
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: _dec('support.subject'.tr(), Icons.subject_outlined), // ✅
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'support.val_subject'.tr() : null, // ✅
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageCtrl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: _dec('support.message'.tr(), Icons.message_outlined), // ✅
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'support.val_msg_empty'.tr(); // ✅
                        if (t.length < 10) return 'support.val_msg_short'.tr(); // ✅
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('support.toast_sent'.tr())), // ✅
                          );
                          subjectCtrl.clear();
                          messageCtrl.clear();
                        },
                        child: Text('support.btn_send'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
                      ),
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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: bg),
      filled: true,
      fillColor: bg.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: bg.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: bg, width: 2),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(a, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}