import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import 'signup_page.dart';
import '../services/api_service.dart';
import 'shop_selector_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool rememberMe = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _forceLoginAlways();
  }

  Future<void> _forceLoginAlways() async {
    try {
      await ApiService.clearToken();
      await ApiService.clearSelectedShopId();
    } catch (_) {}
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
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
                const SizedBox(height: 60),

                // ===== LOGO =====
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
                  'app_name'.tr(), // ✅
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 44),

                // ===== USERNAME =====
                _pillField(
                  controller: _username,
                  hint: 'login.email_username'.tr(), // ✅
                  icon: Icons.person_outline,
                  obscure: false,
                ),
                const SizedBox(height: 16),

                // ===== PASSWORD =====
                _pillField(
                  controller: _password,
                  hint: 'login.password'.tr(), // ✅
                  icon: Icons.lock_outline,
                  obscure: true,
                ),

                const SizedBox(height: 10),

                // ===== REMEMBER ME =====
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (v) => setState(() => rememberMe = v ?? false),
                      activeColor: Colors.white,
                      checkColor: bg,
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                    Text(
                      'login.remember_me'.tr(), // ✅
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ===== LOGIN BUTTON =====
                _primaryButton(
                  text: _loading ? 'login.btn_loading'.tr() : 'login.btn_login'.tr(), // ✅
                  onTap: _loading
                      ? () {}
                      : () async {
                          FocusScope.of(context).unfocus();

                          final emailOrUsername = _username.text.trim();
                          final password = _password.text;

                          if (emailOrUsername.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('login.err_empty'.tr())), // ✅
                            );
                            return;
                          }

                          setState(() => _loading = true);
                          try {
                            await ApiService.login(
                              emailOrUsername: emailOrUsername,
                              password: password,
                            );

                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ShopSelectorPage()),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("${'login.err_failed'.tr()} $e")), // ✅
                            );
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                ),

                const SizedBox(height: 14),

                // ===== CREATE ACCOUNT =====
                _filledButton(
                  text: 'login.btn_create_account'.tr(), // ✅
                  color: const Color(0xFF00A8D9),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                ),

                const SizedBox(height: 18),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: Text(
                    'login.no_account'.tr(), // ✅
                    style: const TextStyle(color: Colors.white),
                  ),
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

// ================= UI COMPONENTS =================

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
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: bg,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

Widget _filledButton({
  required String text,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}