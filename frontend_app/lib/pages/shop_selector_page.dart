import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';
import 'main_shell.dart';

class ShopSelectorPage extends StatefulWidget {
  const ShopSelectorPage({super.key});

  @override
  State<ShopSelectorPage> createState() => _ShopSelectorPageState();
}

class _ShopSelectorPageState extends State<ShopSelectorPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _shops = [];

  final ImagePicker _picker = ImagePicker();
  final Map<int, bool> _uploadState = {}; 

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shops = await ApiService.fetchMyShops();
      if (!mounted) return;
      setState(() => _shops = shops);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _isOwner(dynamic shop) {
    final role = (shop['my_role'] ?? shop['role'] ?? '').toString().toLowerCase().trim();
    return role == 'owner';
  }

  int? _shopIdOf(dynamic shop) {
    final id = (shop['shop_id'] ?? shop['id']);
    return int.tryParse(id.toString());
  }

  Future<void> _selectShop(dynamic shop) async {
    final shopId = _shopIdOf(shop);
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.err_invalid_id'.tr())), // ✅
      );
      return;
    }

    final role = (shop['my_role'] ?? shop['role'] ?? 'employee').toString();

    await ApiService.setSelectedShop(shopId: shopId, role: role);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _addShopDialog() async {
    final controller = TextEditingController();
    bool creating = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: Text('shop_selector.add_shop_title'.tr()), // ✅
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'shop_selector.hint_shop_name'.tr(), // ✅
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.pop(ctx),
                  child: Text('shop_selector.btn_cancel'.tr()), // ✅
                ),
                ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isEmpty) return;

                          setD(() => creating = true);
                          try {
                            await ApiService.createShop(shopName: name);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            await _loadShops();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('shop_selector.toast_create_success'.tr())), // ✅
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("${'shop_selector.toast_create_fail'.tr()} $e")), // ✅
                            );
                          } finally {
                            setD(() => creating = false);
                          }
                        },
                  child: Text(creating ? 'shop_selector.btn_creating'.tr() : 'shop_selector.btn_create'.tr()), // ✅
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editShopNameDialog(dynamic shop) async {
    if (!_isOwner(shop)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.err_owner_only_name'.tr())), // ✅
      );
      return;
    }

    final shopId = _shopIdOf(shop);
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.err_invalid_id'.tr())), // ✅
      );
      return;
    }

    final controller = TextEditingController(
      text: (shop['shop_name'] ?? shop['name'] ?? '').toString(),
    );

    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: Text('shop_selector.edit_shop_title'.tr()), // ✅
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'shop_selector.hint_new_shop_name'.tr(), // ✅
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: Text('shop_selector.btn_cancel'.tr()), // ✅
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) return;

                          setD(() => saving = true);
                          try {
                            await ApiService.updateShopName(shopId: shopId, shopName: newName);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            await _loadShops();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('shop_selector.toast_edit_name_success'.tr())), // ✅
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("${'shop_selector.toast_edit_name_fail'.tr()} $e")), // ✅
                            );
                          } finally {
                            setD(() => saving = false);
                          }
                        },
                  child: Text(saving ? 'shop_selector.btn_saving'.tr() : 'shop_selector.btn_save'.tr()), // ✅
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeShopAvatar(dynamic shop) async {
    if (!_isOwner(shop)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.err_owner_only_img'.tr())), // ✅
      );
      return;
    }

    final shopId = _shopIdOf(shop);
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.err_invalid_id'.tr())), // ✅
      );
      return;
    }

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (xfile == null) return;

      final Uint8List bytes = await xfile.readAsBytes();
      final filename = xfile.name.isNotEmpty ? xfile.name : 'shop_$shopId.jpg';

      setState(() => _uploadState[shopId] = true);
      await ApiService.updateShopAvatar(
        shopId: shopId,
        imageBytes: bytes,
        imageFilename: filename,
      );

      if (!mounted) return;
      await _loadShops();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('shop_selector.toast_edit_img_success'.tr())), // ✅
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'shop_selector.toast_edit_img_fail'.tr()} $e")), // ✅
      );
    } finally {
      if (mounted) setState(() => _uploadState[shopId] = false);
    }
  }

  bool _isUploading(int shopId) => _uploadState[shopId] == true;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 42),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.storefront_rounded, size: 70, color: bg),
              ),
              const SizedBox(height: 14),
              Text(
                'shop_selector.title'.tr(), // ✅
                style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 26),

              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      ..._shops.map((s) {
                        final shopId = _shopIdOf(s) ?? -1;
                        return _shopTile(
                          shop: s,
                          title: (s['shop_name'] ?? s['name'] ?? '').toString(),
                          subtitle: (s['my_role'] ?? s['role'] ?? '').toString(),
                          onTap: () => _selectShop(s),
                          onEditName: _isOwner(s) ? () => _editShopNameDialog(s) : null,
                          onEditAvatar: _isOwner(s) ? () => _changeShopAvatar(s) : null,
                          uploading: shopId > 0 ? _isUploading(shopId) : false,
                        );
                      }),
                      const SizedBox(height: 10),
                      _addProfileButton(onTap: _addShopDialog),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopTile({
    required dynamic shop,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onEditName,
    VoidCallback? onEditAvatar,
    required bool uploading,
  }) {
    const bg = Color(0xFF00C2F3);
    final isOwner = _isOwner(shop);

    final shopImage = (shop['shop_image'] ?? '').toString().trim();
    final hasImage = shopImage.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: (onEditAvatar != null && !uploading) ? onEditAvatar : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: hasImage
                            ? NetworkImage(ApiService.shopImageUrl(shopImage))
                            : null,
                        child: !hasImage
                            ? const Icon(Icons.storefront_rounded, color: bg)
                            : null,
                      ),
                      if (uploading)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isOwner ? Colors.amber.shade200 : Colors.white70,
                            fontSize: 12,
                            fontWeight: isOwner ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      if (isOwner)
                        Text(
                          'shop_selector.tap_hint'.tr(), // ✅
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),

                if (onEditName != null)
                  IconButton(
                    onPressed: onEditName,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Edit shop name',
                  ),

                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addProfileButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            'shop_selector.add_profile'.tr(), // ✅
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}