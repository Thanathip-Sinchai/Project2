import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const bg = Color(0xFF00C2F3);

  final formKey = GlobalKey<FormState>();
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool hideOld = true;
  bool hideNew = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
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
        title: Text('change_pwd.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Container(
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
              children: [
                TextFormField(
                  controller: oldCtrl,
                  obscureText: hideOld,
                  decoration: _dec(
                    label: 'change_pwd.f_old'.tr(), // ✅
                    icon: Icons.lock_outline,
                    hidden: hideOld,
                    toggle: () => setState(() => hideOld = !hideOld),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'change_pwd.val_old_empty'.tr() : null, // ✅
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: hideNew,
                  decoration: _dec(
                    label: 'change_pwd.f_new'.tr(), // ✅
                    icon: Icons.lock_reset,
                    hidden: hideNew,
                    toggle: () => setState(() => hideNew = !hideNew),
                  ),
                  validator: (v) {
                    final t = v ?? '';
                    if (t.isEmpty) return 'change_pwd.val_new_empty'.tr(); // ✅
                    if (t.length < 6) return 'change_pwd.val_new_short'.tr(); // ✅
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: hideConfirm,
                  decoration: _dec(
                    label: 'change_pwd.f_confirm'.tr(), // ✅
                    icon: Icons.verified_outlined,
                    hidden: hideConfirm,
                    toggle: () => setState(() => hideConfirm = !hideConfirm),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'change_pwd.val_confirm_empty'.tr(); // ✅
                    if (v != newCtrl.text) return 'change_pwd.val_mismatch'.tr(); // ✅
                    return null;
                  },
                ),
                const SizedBox(height: 18),
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
                      Navigator.pop(context, true);
                    },
                    child: Text('change_pwd.btn_update'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    required bool hidden,
    required VoidCallback toggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: bg),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(hidden ? Icons.visibility_off : Icons.visibility, color: Colors.black45),
      ),
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