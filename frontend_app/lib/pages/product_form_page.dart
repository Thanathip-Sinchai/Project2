import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

import '../services/api_service.dart';
import '../services/notification_service.dart';

class ProductFormPage extends StatefulWidget {
  final Map<String, dynamic>? product; 

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  static const bg = Color(0xFF00C2F3);

  // ===== Notification settings keys =====
  static const String _kLowStockKey = 'notify_low_stock';
  static const String _kLowStockThresholdKey = 'notify_low_stock_threshold';
  static const int _notifIdLowStock = 1001;

  final _productName = TextEditingController();
  final _productCode = TextEditingController();
  final _size = TextEditingController();
  final _productionDate = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController(); 

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get isEdit => widget.product != null;

  // ===== Image =====
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage; 
  String? _existingImagePath;

  int _getId() {
    final raw = widget.product?['id'] ??
        widget.product?['product_id'] ??
        widget.product?['productId'];
    return int.tryParse('$raw') ?? 0;
  }

  String? _getExistingImagePath() {
    final p = widget.product;
    if (p == null) return null;
    final v = p['product_image'] ?? p['image'] ?? p['image_url'];
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String _imageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return '${ApiService.baseUrl}$imagePath';
  }

  @override
  void initState() {
    super.initState();

    final p = widget.product;
    if (p != null) {
      _productName.text = '${p['product_name'] ?? ''}';
      _productCode.text = '${p['barcode'] ?? ''}';
      _size.text = '${p['size'] ?? ''}';
      _quantity.text = '${p['quantity'] ?? ''}';
      _price.text = '${p['unit_price'] ?? ''}';
      _productionDate.text = '${p['productionDate'] ?? ''}';
      _existingImagePath = _getExistingImagePath();
    }
  }

  @override
  void dispose() {
    _productName.dispose();
    _productCode.dispose();
    _size.dispose();
    _quantity.dispose();
    _price.dispose();
    _productionDate.dispose();
    super.dispose();
  }

  Future<void> _pickImageSheet() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF6FBFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'product_form.img_title'.tr(), // ✅
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                _sheetBtn(
                  icon: Icons.photo_library_outlined,
                  text: 'product_form.img_gallery'.tr(), // ✅
                  onTap: () async {
                    Navigator.pop(context);
                    final x = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (x == null) return;
                    setState(() => _pickedImage = File(x.path));
                  },
                ),
                const SizedBox(height: 10),
                _sheetBtn(
                  icon: Icons.camera_alt_outlined,
                  text: 'product_form.img_camera'.tr(), // ✅
                  onTap: () async {
                    Navigator.pop(context);
                    final x = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (x == null) return;
                    setState(() => _pickedImage = File(x.path));
                  },
                ),
                const SizedBox(height: 10),
                _sheetBtn(
                  icon: Icons.delete_outline,
                  text: 'product_form.img_remove'.tr(), // ✅
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _pickedImage = null);
                  },
                ),
                const SizedBox(height: 6),
                const Divider(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('product_form.btn_close'.tr(), style: const TextStyle(color: bg)), // ✅
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetBtn({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bg.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? bg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor ?? Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProductionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      initialDate: now,
    );
    if (picked == null) return;

    setState(() {
      _productionDate.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _afterSaveCheckLowStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kLowStockKey) ?? true;
      if (!enabled) return;

      final threshold = prefs.getInt(_kLowStockThresholdKey) ?? 5;

      final list = await ApiService.fetchProductSummary();

      final lowItems = <Map<String, dynamic>>[];
      for (final item in list) {
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

        if (qty != null && qty <= threshold) {
          lowItems.add(m);
        }
      }

      if (lowItems.isEmpty) return;

      final names = lowItems.take(3).map((m) {
        final name = _readStringAny(m, [
              'product_name',
              'name',
              'productName',
              'title',
            ]) ??
            'Item';
        final qty = _readIntAny(m, [
              'quantity',
              'qty',
              'total_quantity',
              'stock',
              'remaining',
              'remain',
            ]) ??
            0;
        return '$name ($qty)';
      }).toList();

      final more = lowItems.length > 3 ? 'product_form.notif_more'.tr(args: [(lowItems.length - 3).toString()]) : ''; // ✅

      await NotificationService.instance.showNow(
        id: _notifIdLowStock,
        title: 'product_form.notif_low_title'.tr(args: [threshold.toString()]), // ✅
        body: 'product_form.notif_low_body'.tr(args: [names.join(', '), more]), // ✅
      );
    } catch (_) {}
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

  String? _readStringAny(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (!m.containsKey(k)) continue;
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  Future<void> _saveProduct() async {
    if (_saving) return;

    try {
      FocusScope.of(context).unfocus();

      if (!(_formKey.currentState?.validate() ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_form.toast_fill_all'.tr())), // ✅
        );
        return;
      }

      final qty = int.tryParse(_quantity.text.trim());
      if (qty == null || qty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_form.val_qty_invalid'.tr())), // ✅
        );
        return;
      }

      final priceValue = double.tryParse(_price.text.trim());
      if (priceValue == null || priceValue < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_form.val_price_invalid'.tr())), // ✅
        );
        return;
      }

      setState(() => _saving = true);

      final name = _productName.text.trim();
      final code = _productCode.text.trim();
      final sizeText = _size.text.trim();
      final prodDate = _productionDate.text.trim();

      if (!isEdit) {
        if (_pickedImage != null) {
          await ApiService.createProductWithImage(
            name: name,
            code: code,
            size: sizeText,
            quantity: qty,
            price: priceValue,
            productionDate: prodDate,
            imageBytes: await _pickedImage!.readAsBytes(),
            imageFilename: _pickedImage!.path.split(Platform.pathSeparator).last,
            imageFieldName: 'image',
          );
        } else {
          await ApiService.createProduct(
            name: name,
            code: code,
            size: sizeText,
            quantity: qty,
            price: priceValue,
            productionDate: prodDate,
          );
        }
      } else {
        final id = _getId();

        if (_pickedImage != null) {
          await ApiService.updateProductWithImage(
            id: id,
            name: name,
            code: code,
            size: sizeText,
            quantity: qty,
            price: priceValue,
            productionDate: prodDate,
            imageBytes: await _pickedImage!.readAsBytes(),
            imageFilename: _pickedImage!.path.split(Platform.pathSeparator).last,
            imageFieldName: 'image',
          );
        } else {
          await ApiService.updateProduct(
            id: id,
            name: name,
            code: code,
            size: sizeText,
            quantity: qty,
            price: priceValue,
            productionDate: prodDate,
          );
        }
      }

      await _afterSaveCheckLowStock();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('product_form.toast_save_success'.tr())), // ✅
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'product_form.toast_save_fail'.tr()} $e")), // ✅
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEdit ? 'product_form.title_edit'.tr() : 'product_form.title_add'.tr(); // ✅

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 48),
                    padding: const EdgeInsets.fromLTRB(16, 62, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 24),

                          _modernField(
                            controller: _productName,
                            label: 'product_form.f_name'.tr(), // ✅
                            icon: Icons.inventory_2_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'product_form.val_name'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _productCode,
                            label: 'product_form.f_code'.tr(), // ✅
                            icon: Icons.qr_code_2,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'product_form.val_code'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _size,
                            label: 'product_form.f_size'.tr(), // ✅
                            icon: Icons.straighten_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'product_form.val_size'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _pickProductionDate,
                            child: AbsorbPointer(
                              child: _modernField(
                                controller: _productionDate,
                                label: 'product_form.f_date'.tr(), // ✅
                                icon: Icons.calendar_month_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'product_form.val_date'.tr() : null, // ✅
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _quantity,
                            label: 'product_form.f_qty'.tr(), // ✅
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'product_form.val_qty_empty'.tr(); // ✅
                              final n = int.tryParse(t);
                              if (n == null || n < 0) return 'product_form.val_qty_invalid'.tr(); // ✅
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _price,
                            label: 'product_form.f_price'.tr(), // ✅
                            icon: Icons.attach_money,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'product_form.val_price_empty'.tr(); // ✅
                              final n = double.tryParse(t);
                              if (n == null || n < 0) return 'product_form.val_price_invalid'.tr(); // ✅
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveProduct,
                              icon: const Icon(Icons.check_circle),
                              label: Text(_saving ? 'product_form.btn_saving'.tr() : 'product_form.btn_save'.tr(), style: const TextStyle(fontSize: 16)), // ✅
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bg,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickImageSheet,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: bg.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildImagePreview(),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: bg, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: bg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover);
    }
    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      return Image.network(
        _imageUrl(_existingImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image,
              color: bg.withOpacity(0.95), size: 34),
        ),
      );
    }
    return Center(
      child: Icon(Icons.inventory_2, color: bg.withOpacity(0.95), size: 40),
    );
  }
}

Widget _modernField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType keyboardType = TextInputType.text,
}) {
  const bg = Color(0xFF00C2F3);

  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: bg, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: bg),
      filled: true,
      fillColor: bg.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: bg.withOpacity(0.40), width: 1.4),
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