import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

class FeedbackMailPage extends StatefulWidget {
  const FeedbackMailPage({super.key});

  @override
  State<FeedbackMailPage> createState() => _FeedbackMailPageState();
}

class _FeedbackMailPageState extends State<FeedbackMailPage> {
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
        title: Text(
          'support.title'.tr(), // ✅
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _card(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'support.contact_us'.tr(), // ✅
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    _softField(
                      controller: subjectCtrl,
                      hint: 'support.subject'.tr(), // ✅
                      icon: Icons.menu,
                      maxLines: 1,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'support.val_subject'.tr() // ✅
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _softField(
                      controller: messageCtrl,
                      hint: 'support.message'.tr(), // ✅
                      icon: Icons.chat_bubble_outline,
                      maxLines: 6,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'support.val_msg_empty'.tr(); // ✅
                        if (t.length < 10) {
                          return 'support.val_msg_short'.tr(); // ✅
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('support.toast_sent'.tr())), // ✅
                          );

                          subjectCtrl.clear();
                          messageCtrl.clear();
                        },
                        child: Text(
                          'support.btn_send'.tr(), // ✅
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bg.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _softField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required int maxLines,
    required String? Function(String?) validator,
  }) {
    final fill = bg.withOpacity(0.06);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: bg),
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: bg.withOpacity(0.35), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: bg, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}