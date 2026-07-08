import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final e = email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signUp() async {
    if (_loading) return;

    final name = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('signup.err_empty'.tr()); // ✅
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnack('signup.err_email'.tr()); // ✅
      return;
    }
    if (password.length < 6) {
      _showSnack('signup.err_pwd_len'.tr()); // ✅
      return;
    }
    if (password != confirm) {
      _showSnack('signup.err_pwd_match'.tr()); // ✅
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.register(
        username: name,
        email: email,
        password: password,
        confirmPassword: confirm,
      );

      _showSnack('signup.toast_success'.tr()); // ✅
      if (mounted) Navigator.pop(context); 

    } catch (e) {
      String msg = e.toString().replaceAll('Exception:', '').trim();
      _showSnack("${'signup.toast_fail'.tr()} $msg"); // ✅
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 70),
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 70,
                    color: bg,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'signup.title'.tr(), // ✅
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 48),
                _pillField(
                  controller: _username,
                  hint: 'signup.f_username'.tr(), // ✅
                  icon: Icons.person_outline,
                  obscure: false,
                ),
                const SizedBox(height: 16),
                _pillField(
                  controller: _email,
                  hint: 'signup.f_email'.tr(), // ✅
                  icon: Icons.email_outlined,
                  obscure: false,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _pillField(
                  controller: _password,
                  hint: 'signup.f_password'.tr(), // ✅
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                const SizedBox(height: 16),
                _pillField(
                  controller: _confirm,
                  hint: 'signup.f_confirm'.tr(), // ✅
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  text: _loading ? 'signup.btn_signing_up'.tr() : 'signup.btn_signup'.tr(), // ✅
                  onTap: _loading ? () {} : _signUp,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'signup.have_account'.tr(), // ✅
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'signup.btn_login'.tr(), // ✅
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _pillField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required bool obscure,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 6)),
      ],
    ),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        prefixIcon: Icon(icon, color: Colors.white),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}

Widget _primaryButton({
  required String text,
  required VoidCallback onTap,
}) {
  const bg = Color(0xFF00C2F3);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: bg, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}