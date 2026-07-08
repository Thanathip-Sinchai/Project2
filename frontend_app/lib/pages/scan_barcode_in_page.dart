import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';

class ScanBarcodeInPage extends StatefulWidget {
  const ScanBarcodeInPage({super.key});

  @override
  State<ScanBarcodeInPage> createState() => _ScanBarcodeInPageState();
}

class _ScanBarcodeInPageState extends State<ScanBarcodeInPage>
    with WidgetsBindingObserver {
  static const bg = Color(0xFF00C2F3);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
    ],
  );

  bool _scanning = false;
  bool _busy = false;

  String _lastRaw = '-';
  String _lastNormalized = '-';
  int _qty = 1;

  final ImagePicker _picker = ImagePicker();

  String _normalizeBarcode(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length >= 12 && digits.startsWith('0')) {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
    }

    if (digits.length >= 8 && digits.length <= 13 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  String _pickBestValue(List<Barcode> codes) {
    String best = '';
    int bestScore = -1;

    for (final b in codes) {
      final raw = (b.rawValue ?? b.displayValue ?? '').toString();
      if (raw.trim().isEmpty) continue;

      final digits = _normalizeBarcode(raw);
      if (digits.isEmpty) continue;

      final len = digits.length;
      int score = 0;
      if (len >= 8 && len <= 13) score += 100;
      score += len;

      if (score > bestScore) {
        bestScore = score;
        best = raw;
      }
    }

    return best.isEmpty
        ? (codes.isNotEmpty
            ? (codes.first.rawValue ?? codes.first.displayValue ?? '-')
            : '-')
        : best;
  }

  void _applyScanRaw(String rawValue) {
    final normalized = _normalizeBarcode(rawValue);
    if (normalized.isEmpty) return;

    if (_lastNormalized == normalized) return;

    setState(() {
      _lastRaw = rawValue;
      _lastNormalized = normalized;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scanning) return;

    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await _controller.stop();
      if (!mounted) return;
      setState(() => _scanning = false);
    } else {
      await _controller.start();
      if (!mounted) return;
      setState(() => _scanning = true);
    }
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController(
        text: _lastNormalized == '-' ? '' : _lastNormalized);
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('scan.manual_title'.tr()), // ✅
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(hintText: 'scan.manual_hint'.tr()), // ✅
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('scan.btn_cancel'.tr())), // ✅
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text('scan.btn_ok'.tr())), // ✅
        ],
      ),
    );

    if (v == null) return;

    final raw = v.trim();
    if (raw.isEmpty) return;

    final normalized = _normalizeBarcode(raw);
    if (normalized.isEmpty) {
      _toast('scan.toast_not_found'.tr()); // ✅
      return;
    }

    setState(() {
      _lastRaw = raw;
      _lastNormalized = normalized;
    });

    _toast('scan.toast_set'.tr(args: [normalized])); // ✅
  }

  Future<void> _scanFromImage() async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 90);
      if (x == null) return;

      final BarcodeCapture? cap = await _controller.analyzeImage(x.path);

      if (cap == null || cap.barcodes.isEmpty) {
        _toast('scan.toast_img_fail'.tr()); // ✅
        return;
      }

      final rawBest = _pickBestValue(cap.barcodes);
      _applyScanRaw(rawBest);
      _toast('scan.toast_img_success'.tr()); // ✅
    } catch (e, s) {
      _toast('Scan from image error: $e');
      final _ = s;
    }
  }

  Future<void> _backToStock() async {
    if (!mounted) return;

    try {
      if (_scanning) {
        await _controller.stop();
      }
    } catch (_) {}

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true); 
    }
  }

  Future<void> _submitStockIn() async {
    final code = _lastNormalized.trim();
    if (code.isEmpty || code == '-') {
      _toast('scan.err_no_barcode'.tr()); // ✅
      return;
    }
    if (_qty <= 0) {
      _toast('scan.err_qty'.tr()); // ✅
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final res = await ApiService.stockIn(barcode: code, qty: _qty);
      final total = (res['total_quantity'] ?? '-').toString();
      _toast('scan.toast_in_success'.tr(args: [total])); // ✅

      await _backToStock();
    } catch (e) {
      _toast('scan.toast_in_fail'.tr(args: [e.toString()])); // ✅
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('scan.in_title'.tr(), // ✅
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Flip',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusHeader(
              color: bg,
              icon: Icons.call_received,
              title: 'scan.scan_in_header'.tr(), // ✅ แก้ให้แปลภาษาได้
              subtitle: 'scan.in_desc'.tr(), // ✅
            ),
            const SizedBox(height: 12),
            _CameraBox(
              color: bg,
              scanning: _scanning,
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  final codes = capture.barcodes;
                  if (codes.isEmpty) return;

                  final rawBest = _pickBestValue(codes);
                  _applyScanRaw(rawBest);
                },
              ),
            ),
            const SizedBox(height: 12),
            _ResultCard(color: bg, title: 'scan.last_scanned'.tr(), value: _lastNormalized), // ✅
            const SizedBox(height: 10),
            _QtyCard(
              color: bg,
              qty: _qty,
              onMinus: () => setState(() => _qty = (_qty > 1) ? _qty - 1 : 1),
              onPlus: () => setState(() => _qty = _qty + 1),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    color: bg,
                    icon: Icons.image_outlined,
                    label: 'scan.scan_image'.tr(), // ✅
                    onTap: _scanFromImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlineButton(
                    color: bg,
                    icon: Icons.edit,
                    label: 'scan.manual'.tr(), // ✅
                    onTap: _manualInput,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SolidButton(
              color: bg,
              icon: _scanning ? Icons.stop_circle_outlined : Icons.qr_code_scanner,
              label: _scanning ? 'scan.stop_scan'.tr() : 'scan.start_scan'.tr(), // ✅
              onTap: _toggleScan,
            ),
            const SizedBox(height: 10),
            _SolidButton(
              color: bg,
              icon: Icons.check_circle_outline,
              label: _busy ? 'scan.processing'.tr() : 'scan.confirm_in'.tr(), // ✅
              onTap: _busy ? () {} : _submitStockIn,
            ),
          ],
        ),
      ),
    );
  }
}

// ================= COMPONENTS =================
class _StatusHeader extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusHeader({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: color, width: 2),
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
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
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
        ],
      ),
    );
  }
}

class _CameraBox extends StatelessWidget {
  final Color color;
  final bool scanning;
  final Widget child;

  const _CameraBox({
    required this.color,
    required this.scanning,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Center(
              child: Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                ),
              ),
            ),
            if (!scanning)
              const Center(
                child: Icon(Icons.qr_code_2, size: 56, color: Colors.black38),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _ResultCard({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _QtyCard extends StatelessWidget {
  final Color color;
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyCard({
    required this.color,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('scan.qty'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
          ),
          IconButton(
            onPressed: onMinus,
            icon: Icon(Icons.remove_circle_outline, color: color),
          ),
          SizedBox(
            width: 46,
            child: Center(
              child: Text(
                '$qty',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: Icon(Icons.add_circle_outline, color: color),
          ),
        ],
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SolidButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
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

class _OutlineButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.color,
    required this.icon,
    required this.label,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.6),
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