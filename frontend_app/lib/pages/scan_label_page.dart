import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart'; 
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';
import '../services/ocr_api.dart';

class ScanLabelPage extends StatefulWidget {
  const ScanLabelPage({super.key});

  @override
  State<ScanLabelPage> createState() => _ScanLabelPageState();
}

class _ScanLabelPageState extends State<ScanLabelPage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;

  bool _loading = false;
  File? _lastImage;

  String _previewName = '-';
  String _previewBarcode = '-';
  Map<String, dynamic> _lastFields = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first),
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraPermissionDenied = false;
        });
      }
    } catch (e) {
      if (e is CameraException && e.code == 'CameraAccessDenied') {
        setState(() => _isCameraPermissionDenied = true);
      }
      debugPrint('Error initializing camera: $e');
    }
  }

  void _logJson(String tag, Object? obj) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(obj);
      print('$tag $pretty');
    } catch (_) {
      print('$tag $obj');
    }
  }

  Map<String, dynamic> _extractFieldsFromResponse(Map<String, dynamic> res) {
    final direct = res['fields'];
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final raw = res['raw'];
    if (raw is Map) {
      final rawFields = raw['fields'];
      if (rawFields is Map) return Map<String, dynamic>.from(rawFields);
    }
    return <String, dynamic>{};
  }

  Future<void> _pickFromGallery() async {
    if (_loading) return;
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return;
    await _handleImage(File(x.path));
  }

  Future<void> _captureFromCamera() async {
    if (_loading || !_isCameraInitialized || _cameraController == null) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      setState(() => _loading = true);
      final XFile picture = await _cameraController!.takePicture();
      await _handleImage(File(picture.path));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${'ocr.err_camera'.tr()} $e"))); // ✅
    }
  }

  Future<void> _handleImage(File file) async {
    setState(() {
      _loading = true;
      _lastImage = file;
      _previewName = 'ocr.analyzing'.tr(); // ✅
      _previewBarcode = 'ocr.reading'.tr(); // ✅
      _lastFields = {};
    });

    try {
      final res = await OcrApi.runOcr(file).timeout(const Duration(seconds: 60));
      _logJson("OCR raw res:", res);

      final fields = _extractFieldsFromResponse(res);
      _logJson("OCR extracted fields:", fields);

      final name = (fields["name"] ?? "").toString();
      final barcode = (fields["barcode"] ?? "").toString();

      setState(() {
        _lastFields = fields;
        _previewName = name.isEmpty ? '-' : name;
        _previewBarcode = barcode.isEmpty ? '-' : barcode;
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrConfirmFormPage(initialFields: fields),
        ),
      );

      if (mounted) {
        setState(() {
          _lastImage = null;
        });
      }

    } catch (e) {
      setState(() {
        _previewName = 'Error';
        _previewBarcode = e.toString();
        _lastImage = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OCR Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'ocr.title'.tr(), // ✅
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: bg.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_lastImage != null)
                          Image.file(_lastImage!, width: double.infinity, fit: BoxFit.cover)
                        else if (_isCameraPermissionDenied)
                          Center(child: Text('ocr.permission_denied'.tr(), style: const TextStyle(color: Colors.white))) // ✅
                        else if (_isCameraInitialized)
                          SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: CameraPreview(_cameraController!),
                          )
                        else
                          const Center(child: CircularProgressIndicator(color: bg)),

                        if (_lastImage == null)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: CustomPaint(painter: _ModernScannerFramePainter(color: bg)),
                            ),
                          ),

                        Positioned(
                          top: 20,
                          child: _HintPill(
                            icon: Icons.center_focus_strong,
                            text: 'ocr.hint'.tr(), // ✅
                          ),
                        ),

                        if (_loading)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(color: Colors.white),
                                  const SizedBox(height: 16),
                                  Text("ocr.analyzing".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), // ✅
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.document_scanner, color: bg, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text('ocr.result_preview'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // ✅
                            ],
                          ),
                          const Divider(height: 24),
                          Text('ocr.product'.tr(args: [_previewName]), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 15)), // ✅
                          const SizedBox(height: 6),
                          Text('ocr.code'.tr(args: [_previewBarcode]), style: const TextStyle(color: Colors.black54, fontSize: 14)), // ✅
                          if (_lastFields.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ocr.size'.tr(args: [(_lastFields["size"] ?? "-").toString()]), // ✅
                              style: const TextStyle(color: Colors.black54, fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),

                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: _loading ? null : _pickFromGallery,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: bg.withOpacity(0.3), width: 2),
                              ),
                              child: const Icon(Icons.photo_library, color: bg, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: _loading ? null : _captureFromCamera,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00C2F3), Color(0xFF0091E6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: bg.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera, color: Colors.white, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    _loading ? 'scan.processing'.tr() : 'ocr.btn_capture'.tr(), // ✅
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
}

// ---------------------------------------------------------
// หน้า Confirm ฟอร์ม
// ---------------------------------------------------------
class OcrConfirmFormPage extends StatefulWidget {
  final Map<String, dynamic> initialFields;

  const OcrConfirmFormPage({
    super.key,
    required this.initialFields,
  });

  @override
  State<OcrConfirmFormPage> createState() => _OcrConfirmFormPageState();
}

class _OcrConfirmFormPageState extends State<OcrConfirmFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  File? _productImage;

  late final TextEditingController _productName;
  late final TextEditingController _productCode;
  late final TextEditingController _size;
  late final TextEditingController _productionDateCE;
  
  late final TextEditingController _quantityStock;
  late final TextEditingController _price;

  bool _saving = false;

  DateTime? _parseDmyToDate(String dmy) {
    final parts = dmy.split('/');
    if (parts.length != 3) return null;
    final dd = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final yyyy = int.tryParse(parts[2]);
    if (dd == null || mm == null || yyyy == null) return null;
    return DateTime(yyyy, mm, dd);
  }

  String _formatCeYmd(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  @override
  void initState() {
    super.initState();

    final fields = widget.initialFields;

    final name = (fields["name"] ?? "").toString();
    final code = (fields["barcode"] ?? "").toString();
    final size = (fields["size"] ?? "").toString();
    final mfg = (fields["mfg"] ?? "").toString(); 

    String ceDate = "";
    final dt = _parseDmyToDate(mfg);
    if (dt != null) ceDate = _formatCeYmd(dt);

    _productName = TextEditingController(text: name);
    _productCode = TextEditingController(text: code);
    _size = TextEditingController(text: size);
    _productionDateCE = TextEditingController(text: ceDate);
    
    _quantityStock = TextEditingController(text: "");
    _price = TextEditingController(text: ""); 
  }

  @override
  void dispose() {
    _productName.dispose();
    _productCode.dispose();
    _size.dispose();
    _productionDateCE.dispose();
    _quantityStock.dispose();
    _price.dispose();
    super.dispose();
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

    setState(() {
      _productionDateCE.text = _formatCeYmd(picked);
    });
  }

  Future<void> _pickProductImageSheet() async {
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
                    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
                    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
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

  Widget _sheetBtn({required IconData icon, required String text, required VoidCallback onTap, Color? textColor}) {
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? bg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: textColor ?? Colors.black87)),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToDb() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

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

    final productionDateCE = _productionDateCE.text.trim();

    setState(() => _saving = true);
    try {
      if (_productImage != null) {
        await ApiService.createProductWithImage(
          name: _productName.text.trim(),
          code: _productCode.text.trim(),
          size: _size.text.trim(),
          quantity: qtyStock,
          price: priceValue,
          productionDate: productionDateCE,
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
          productionDate: productionDateCE,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('lists.toast_save_success'.tr())), // ✅
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'lists.toast_save_fail'.tr()} $e")), // ✅
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    const bg = Color(0xFF00C2F3);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)
            ),
            child: Icon(icon, color: bg, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
        title: Text(
          'ocr.confirm_title'.tr(), // ✅
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'ocr.confirm_title'.tr(), // ✅
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _sectionHeader(icon: Icons.document_scanner, title: 'ocr.section_1'.tr()), // ✅

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
                            icon: Icons.straighten,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_size'.tr() : null, // ✅
                          ),
                          const SizedBox(height: 12),

                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _pickProductionDate,
                            child: AbsorbPointer(
                              child: _modernField(
                                controller: _productionDateCE,
                                label: 'lists.f_date'.tr(), // ✅
                                icon: Icons.calendar_month_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'lists.val_date'.tr() : null, // ✅
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Divider(color: Colors.grey.shade300, thickness: 1.5),
                          const SizedBox(height: 8),

                          _sectionHeader(icon: Icons.edit_note, title: 'ocr.section_2'.tr()), // ✅

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

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveToDb,
                              icon: const Icon(Icons.check_circle),
                              label: Text(_saving ? 'ocr.btn_saving'.tr() : 'ocr.btn_confirm'.tr(), style: const TextStyle(fontSize: 16)), // ✅
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
                    onTap: _pickProductImageSheet,
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
                              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 10)),
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

class _HintPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: bg.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: bg, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ModernScannerFramePainter extends CustomPainter {
  final Color color;
  _ModernScannerFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 40.0;
    const r = 0.0; 

    canvas.drawPath(Path()..moveTo(r, 0)..lineTo(len, 0)..moveTo(0, r)..lineTo(0, len), p);
    canvas.drawPath(Path()..moveTo(size.width - r, 0)..lineTo(size.width - len, 0)..moveTo(size.width, r)..lineTo(size.width, len), p);
    canvas.drawPath(Path()..moveTo(0, size.height - r)..lineTo(0, size.height - len)..moveTo(r, size.height)..lineTo(len, size.height), p);
    canvas.drawPath(Path()..moveTo(size.width, size.height - r)..lineTo(size.width, size.height - len)..moveTo(size.width - r, size.height)..lineTo(size.width - len, size.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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