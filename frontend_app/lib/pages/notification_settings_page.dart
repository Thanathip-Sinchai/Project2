import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';
import '../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const bg = Color(0xFF00C2F3);

  static const _kLowStockKey = 'notify_low_stock';
  static const _kSystemKey = 'notify_system';
  static const _kDailySummaryKey = 'notify_daily_summary';
  static const _kLowStockThresholdKey = 'notify_low_stock_threshold';

  static const int _idLowStock = 1001;
  static const int _idDailySummary = 1002;
  static const int _idSystemTest = 1999;

  bool lowStock = true;
  bool system = false;
  bool dailySummary = true;
  int lowStockThreshold = 5;

  bool _loading = true;
  bool _checking = false;
  String? _lastCheckMsg;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermissionIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    lowStock = prefs.getBool(_kLowStockKey) ?? true;
    system = prefs.getBool(_kSystemKey) ?? false;
    dailySummary = prefs.getBool(_kDailySummaryKey) ?? true;
    lowStockThreshold = prefs.getInt(_kLowStockThresholdKey) ?? 5;

    await _applyAll();

    if (lowStock) {
      await _checkLowStockAndNotify(showWhenOk: false);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _applyAll() async {
    if (dailySummary) {
      await NotificationService.instance.scheduleDaily(
        id: _idDailySummary,
        title: 'Daily Stock Summary',
        body: 'Check your stock IN/OUT today.',
        hour: 9,
        minute: 0,
      );
    } else {
      await NotificationService.instance.cancel(_idDailySummary);
    }

    if (!lowStock) {
      await NotificationService.instance.cancel(_idLowStock);
    }
  }

  Future<void> _toggleLowStock(bool v) async {
    setState(() {
      lowStock = v;
      _lastCheckMsg = null;
    });
    await _saveBool(_kLowStockKey, v);

    if (!v) {
      await NotificationService.instance.cancel(_idLowStock);
      return;
    }

    await _checkLowStockAndNotify(showWhenOk: true);
  }

  Future<void> _toggleDailySummary(bool v) async {
    setState(() => dailySummary = v);
    await _saveBool(_kDailySummaryKey, v);

    if (v) {
      await NotificationService.instance.scheduleDaily(
        id: _idDailySummary,
        title: 'Daily Stock Summary',
        body: 'Check your stock IN/OUT today.',
        hour: 9,
        minute: 0,
      );
    } else {
      await NotificationService.instance.cancel(_idDailySummary);
    }
  }

  Future<void> _toggleSystem(bool v) async {
    setState(() => system = v);
    await _saveBool(_kSystemKey, v);

    if (v) {
      await NotificationService.instance.showNow(
        id: _idSystemTest,
        title: 'System messages enabled',
        body: 'System can now send push notifications.',
      );
    }
  }

  Future<void> _updateThreshold(int v) async {
    setState(() {
      lowStockThreshold = v;
      _lastCheckMsg = null;
    });
    await _saveInt(_kLowStockThresholdKey, v);

    if (lowStock) {
      await _checkLowStockAndNotify(showWhenOk: false);
    }
  }

  Future<void> _checkLowStockAndNotify({required bool showWhenOk}) async {
    if (_checking) return;

    setState(() {
      _checking = true;
      _lastCheckMsg = null;
    });

    try {
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

        if (qty != null && qty <= lowStockThreshold) {
          lowItems.add(m);
        }
      }

      if (lowItems.isNotEmpty) {
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

        final more = lowItems.length > 3 ? ' + ${lowItems.length - 3} more' : '';

        await NotificationService.instance.showNow(
          id: _idLowStock,
          title: 'Low stock (≤ $lowStockThreshold)',
          body: '${names.join(', ')}$more',
        );

        setState(() => _lastCheckMsg = 'notif_settings.found_low'.tr(args: [lowItems.length.toString()])); // ✅
      } else {
        if (showWhenOk) {
          await NotificationService.instance.showNow(
            id: _idLowStock,
            title: 'Low stock',
            body: 'No items are ≤ $lowStockThreshold',
          );
        }
        setState(() => _lastCheckMsg = 'notif_settings.no_low'.tr()); // ✅
      }
    } catch (e) {
      setState(() => _lastCheckMsg = 'notif_settings.check_fail'.tr(args: [e.toString()])); // ✅
    } finally {
      if (mounted) setState(() => _checking = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'notif_settings.title'.tr(), // ✅
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _switchTile(
                    bg: bg,
                    title: 'notif_settings.low_stock_title'.tr(), // ✅
                    subtitle: 'notif_settings.low_stock_sub'.tr(), // ✅
                    value: lowStock,
                    onChanged: _toggleLowStock,
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'notif_settings.threshold_title'.tr(), // ✅
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DropdownButton<int>(
                          value: lowStockThreshold,
                          underline: const SizedBox.shrink(),
                          items: const [1, 2, 3, 5, 10, 20]
                              .map((v) => DropdownMenuItem<int>(
                                    value: v,
                                    child: Text('≤ $v'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _updateThreshold(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  _switchTile(
                    bg: bg,
                    title: 'notif_settings.daily_title'.tr(), // ✅
                    subtitle: 'notif_settings.daily_sub'.tr(), // ✅
                    value: dailySummary,
                    onChanged: _toggleDailySummary,
                  ),
                  _switchTile(
                    bg: bg,
                    title: 'notif_settings.system_title'.tr(), // ✅
                    subtitle: 'notif_settings.system_sub'.tr(), // ✅
                    value: system,
                    onChanged: _toggleSystem,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: lowStock && !_checking
                          ? () => _checkLowStockAndNotify(showWhenOk: true)
                          : null,
                      label: Text(
                        'notif_settings.btn_check_now'.tr(), // ✅
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_lastCheckMsg != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _lastCheckMsg!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _switchTile({
    required Color bg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        color: Colors.white,
      ),
      child: SwitchListTile(
        value: value,
        activeColor: bg,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}