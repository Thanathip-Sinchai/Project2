import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

import '../services/api_service.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'support_page.dart';
import 'shop_selector_page.dart';

class UserProfile {
  String name;
  String email;
  String role;
  int products;
  int alerts;
  String? avatarUrl;

  UserProfile({
    required this.name,
    required this.email,
    this.role = 'Owner',
    this.products = 0,
    this.alerts = 0,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['username'] ?? '').toString();

    return UserProfile(
      name: name,
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'Owner').toString(),
      products: int.tryParse((json['products'] ?? 0).toString()) ?? 0,
      alerts: int.tryParse((json['alerts'] ?? 0).toString()) ?? 0,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'] ?? '').toString(),
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? role,
    int? products,
    int? alerts,
    String? avatarUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      products: products ?? this.products,
      alerts: alerts ?? this.alerts,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const bg = Color(0xFF00C2F3);

  UserProfile? profile;
  bool loading = true;
  String? errorText;

  int _threshold = 5;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _threshold = prefs.getInt('notify_low_stock_threshold') ?? 5;

      final data = await ApiService.fetchMe();
      var me = UserProfile.fromJson(data);

      final shopRole = await ApiService.getSelectedShopRole();
      if (shopRole != null && shopRole.trim().isNotEmpty) {
        me = me.copyWith(role: shopRole);
      }

      final summary = await ApiService.fetchProductSummary();
      final productsCount = summary.length;

      int lowCount = 0;
      for (final item in summary) {
        if (item is! Map) continue;
        final m = item.map((k, v) => MapEntry(k.toString(), v));
        final qty = _readIntAny(m, [
          'quantity',
          'qty',
          'total_quantity',
          'totalQty',
          'stock',
          'remaining',
          'remain',
        ]);
        if (qty != null && qty <= _threshold) lowCount++;
      }

      me = me.copyWith(products: productsCount, alerts: lowCount);

      if (!mounted) return;
      setState(() {
        profile = me;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains("UNAUTHORIZED")) {
        await ApiService.clearToken();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
        return;
      }

      setState(() {
        errorText = e.toString();
        loading = false;
      });
    }
  }

  int? _readIntAny(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
    }
    return null;
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _changeAvatarNow() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x == null) return;

      final bytes = await File(x.path).readAsBytes();
      final filename = x.path.split(Platform.pathSeparator).last;

      final res = await ApiService.updateAvatar(
        imageBytes: bytes,
        imageFilename: filename,
      );

      final newUrl = (res['avatar_url'] ?? res['avatarUrl'] ?? res['url'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        profile = profile?.copyWith(avatarUrl: newUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.toast_avatar_success'.tr())), // ✅
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'profile.toast_avatar_fail'.tr()} $e")), // ✅
      );
    }
  }

  String _avatarFullUrl(String avatarUrl) {
    final s = avatarUrl.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return "${ApiService.baseUrl}$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('app_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), // ✅
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            tooltip: 'profile.change_shop'.tr(), // ✅
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopSelectorPage()),
              );
              await _loadAll();
            },
            icon: const Icon(Icons.store_mall_directory_outlined, color: Colors.white),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (errorText != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.red),
                        const SizedBox(height: 10),
                        Text(
                          'profile.err_load'.tr(args: [errorText!]), // ✅
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: Text('profile.btn_retry'.tr()), // ✅
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundColor: bg.withOpacity(0.15),
                                    backgroundImage: (profile!.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty)
                                        ? NetworkImage(_avatarFullUrl(profile!.avatarUrl!))
                                        : null,
                                    child: (profile!.avatarUrl == null || profile!.avatarUrl!.trim().isEmpty)
                                        ? const Icon(Icons.person, size: 52, color: bg)
                                        : null,
                                  ),
                                  InkWell(
                                    onTap: _changeAvatarNow,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(color: bg, shape: BoxShape.circle),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                profile!.name.isNotEmpty ? profile!.name : 'User',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(profile!.email, style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                      child: _MiniStat(title: 'profile.role'.tr(), value: profile!.role)), // ✅
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _MiniStat(title: 'profile.products'.tr(), value: '${profile!.products}')), // ✅
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _MiniStat(title: 'profile.alerts'.tr(), value: '${profile!.alerts}')), // ✅
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ShopSelectorPage()),
                                    );
                                    await _loadAll();
                                  },
                                  icon: const Icon(Icons.storefront, color: bg),
                                  label: Text(
                                    'profile.change_shop'.tr(), // ✅
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: bg),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: bg.withOpacity(0.6)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _actionTile(
                          icon: Icons.person_outline,
                          title: 'profile.edit_profile'.tr(), // ✅
                          subtitle: 'profile.edit_profile_desc'.tr(), // ✅
                          onTap: () async {
                            final updatedLocal = await Navigator.push<UserProfile>(
                              context,
                              MaterialPageRoute(builder: (_) => EditProfilePage(initial: profile!)),
                            );

                            if (updatedLocal != null) {
                              try {
                                final updatedServer = await ApiService.updateMe(
                                  name: updatedLocal.name,
                                  email: updatedLocal.email,
                                  avatarUrl: updatedLocal.avatarUrl,
                                );
                                final updated = UserProfile.fromJson(updatedServer);

                                if (!mounted) return;
                                setState(() => profile = updated);
                                await _loadAll();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _actionTile(
                          icon: Icons.lock_outline,
                          title: 'profile.change_password'.tr(), // ✅
                          subtitle: 'profile.change_password_desc'.tr(), // ✅
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _actionTile(
                          icon: Icons.help_outline,
                          title: 'profile.support'.tr(), // ✅
                          subtitle: 'profile.support_desc'.tr(), // ✅
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupportPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _logout,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                'profile.logout'.tr(), // ✅
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  const _MiniStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

Widget _actionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  const bg = Color(0xFF00C2F3);

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: bg, width: 1.5),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    ),
  );
}