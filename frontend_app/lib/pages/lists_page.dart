import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

import '../services/api_service.dart';
import 'scan_center_page.dart';

class ListsPage extends StatefulWidget {
  final VoidCallback? onSavedGoToStock;

  const ListsPage({
    super.key,
    this.onSavedGoToStock,
  });

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final _productName = TextEditingController();
  final _productCode = TextEditingController();
  final _size = TextEditingController();
  final _productionDate = TextEditingController();
  final _quantityStock = TextEditingController();
  final _price = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  final ImagePicker _picker = ImagePicker();
  File? _productImage;

  @override
  void dispose() {
    _productName.dispose();
    _productCode.dispose();
    _size.dispose();
    _quantityStock.dispose();
    _price.dispose();
    _productionDate.dispose();
    super.dispose();
  }

  String _convertDdMmYyyyToYmd(String dmy) {
    final parts = dmy.split('/');
    if (parts.length != 3) return dmy;
    final dd = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    final yyyy = parts[2];
    if (yyyy.length != 4) return dmy;
    return '$yyyy-$mm-$dd';
  }

  void _applyOcrFields(Map<String, dynamic> fields) {
    final name = (fields["name"] ?? "").toString();
    final barcode = (fields["barcode"] ?? "").toString();
    final size = (fields["size"] ?? "").toString();
    final mfg = (fields["mfg"] ?? "").toString();

    if (name.isNotEmpty) _productName.text = name;
    if (barcode.isNotEmpty) _productCode.text = barcode;
    if (size.isNotEmpty) _size.text = size;

    if (mfg.contains('/')) {
      _productionDate.text = _convertDdMmYyyyToYmd(mfg);
    } else if (mfg.isNotEmpty) {
      _productionDate.text = mfg;
    }

    setState(() {});
  }

  Future<void> _goScanAndFill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanCenterPage()),
    );

    if (!mounted) return;
    if (result == null) return;

    if (result is Map<String, dynamic>) {
      _applyOcrFields(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.toast_ocr_success'.tr())), // ✅
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.toast_ocr_fail'.tr())), // ✅
      );
    }
  }

  Future<void> _pickImageSheet() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        const bg = Color(0xFF00C2F3);

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
                    'lists.img_title'.tr(), // ✅
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                _sheetBtn(
                  icon: Icons.photo_library_outlined,
                  text: 'lists.img_gallery'.tr(), // ✅
                  onTap: () async {
                    Navigator.pop(context);
                    final x = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (x == null) return;
                    setState(() => _productImage = File(x.path));
                  },
                ),
                const SizedBox(height: 10),
                _sheetBtn(
                  icon: Icons.camera_alt_outlined,
                  text: 'lists.img_camera'.tr(), // ✅
                  onTap: () async {
                    Navigator.pop(context);
                    final x = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (x == null) return;
                    setState(() => _productImage = File(x.path));
                  },
                ),
                const SizedBox(height: 10),
                _sheetBtn(
                  icon: Icons.delete_outline,
                  text: 'lists.img_remove'.tr(), // ✅
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _productImage = null);
                  },
                ),
                const SizedBox(height: 6),
                const Divider(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('lists.btn_close'.tr(), style: const TextStyle(color: bg)), // ✅
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
    const bg = Color(0xFF00C2F3);

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
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );

    if (picked == null) return;

    final yyyy = picked.year.toString();
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');

    setState(() {
      _productionDate.text = '$yyyy-$mm-$dd';
    });
  }

  Future<void> _saveProduct() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.toast_fill_all'.tr())), // ✅
      );
      return;
    }

    final qtyStock = int.tryParse(_quantityStock.text.trim());
    if (qtyStock == null || qtyStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.val_qty_invalid'.tr())), // ✅
      );
      return;
    }

    final priceValue = double.tryParse(_price.text.trim());
    if (priceValue == null || priceValue < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.val_price_invalid'.tr())), // ✅
      );
      return;
    }

    try {
      if (_productImage != null) {
        await ApiService.createProductWithImage(
          name: _productName.text.trim(),
          code: _productCode.text.trim(),
          size: _size.text.trim(),
          quantity: qtyStock,
          price: priceValue,
          productionDate: _productionDate.text.trim(),
          imageBytes: await _productImage!.readAsBytes(),
          imageFilename: _productImage!.path.split('/').last,
          imageFieldName: 'image', 
        );
      } else {
        await ApiService.createProduct(
          name: _productName.text.trim(),
          code: _productCode.text.trim(),
          size: _size.text.trim(),
          quantity: qtyStock,
          price: priceValue,
          productionDate: _productionDate.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.toast_save_success'.tr())), // ✅
      );

      _productName.clear();
      _productCode.clear();
      _size.clear();
      _quantityStock.clear();
      _price.clear();
      _productionDate.clear();
      setState(() {
        _productImage = null;
      });

      widget.onSavedGoToStock?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'lists.toast_save_fail'.tr()} $e")), // ✅
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('app_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                            'lists.title'.tr(), // ✅
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 24),

                          _modernField(
                            controller: _productName,
                            label: 'lists.f_name'.tr(), // ✅
                            icon: Icons.inventory_2_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_name'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _productCode,
                            label: 'lists.f_code'.tr(), // ✅
                            icon: Icons.qr_code_2,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_code'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _size,
                            label: 'lists.f_size'.tr(), // ✅
                            icon: Icons.straighten_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_size'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _pickProductionDate,
                            child: AbsorbPointer(
                              child: _modernField(
                                controller: _productionDate,
                                label: 'lists.f_date'.tr(), // ✅
                                icon: Icons.calendar_month_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_date'.tr() : null, // ✅
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _quantityStock,
                            label: 'lists.f_qty'.tr(), // ✅
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'lists.val_qty'.tr(); // ✅
                              final n = int.tryParse(t);
                              if (n == null || n < 0) return 'lists.val_qty_invalid'.tr(); // ✅
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _modernField(
                            controller: _price,
                            label: 'lists.f_price'.tr(), // ✅
                            icon: Icons.attach_money,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'lists.val_price'.tr(); // ✅
                              final n = double.tryParse(t);
                              if (n == null || n < 0) return 'lists.val_price_invalid'.tr(); // ✅
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: _OutlineAction(
                                  label: 'lists.btn_scan'.tr(), // ✅
                                  icon: Icons.qr_code_scanner,
                                  color: bg,
                                  onTap: _goScanAndFill,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SolidAction(
                                  label: 'lists.btn_save'.tr(), // ✅
                                  icon: Icons.check_circle,
                                  color: bg,
                                  onTap: _saveProduct,
                                ),
                              ),
                            ],
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
                            child: _productImage == null
                                ? Center(
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: bg.withOpacity(0.95),
                                      size: 40,
                                    ),
                                  )
                                : Image.file(_productImage!, fit: BoxFit.cover),
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
}

class _SolidAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SolidAction({
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OutlineAction({
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
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