import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import
import '../services/api_service.dart';

const Color kBrand = Color(0xFF00C2F3);

class StockHistoryPage extends StatefulWidget {
  const StockHistoryPage({super.key});

  @override
  State<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends State<StockHistoryPage> {
  final _search = TextEditingController();
  String _range = '7d';

  late Future<List<dynamic>> _future;

  String? _myRole;
  bool get _isEmployee => (_myRole ?? '').toLowerCase() == 'employee';

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchStockHistory(range: _range, q: ''); 
    _init();
  }

  Future<void> _init() async {
    final r = await ApiService.getSelectedShopRole();
    final role = (r ?? '').toLowerCase();

    if (!mounted) return;

    setState(() => _myRole = role);

    _future = ApiService.fetchStockHistory(range: _range, q: '');
    setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = ApiService.fetchStockHistory(range: _range, q: _search.text.trim());
    });
  }

  void _setRange(String v) {
    setState(() {
      _range = v;
      _future = ApiService.fetchStockHistory(range: _range, q: _search.text.trim());
    });
  }

  Future<void> _onRefresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {}
  }

  int _toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  DateTime? _toDate(dynamic v) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _dateText(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$day/$m/$y  $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (_myRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: kBrand,
        elevation: 0,
        centerTitle: true,
        title: Text('history.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              final msg = '${snapshot.error}';
              final noShop = msg.contains('NO_SHOP_SELECTED');
              final forbidden = msg.contains('FORBIDDEN');

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _topControls(),
                  const SizedBox(height: 12),
                  _errorCard(
                    noShop: noShop,
                    forbidden: forbidden,
                    msg: msg,
                    onRetry: _reload,
                  ),
                ],
              );
            }

            final raw = snapshot.data ?? const <dynamic>[];
            final rows = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

            int totalIn = 0;
            int totalOut = 0;
            for (final r in rows) {
              final action = (r['action'] ?? '').toString().toUpperCase();
              final qty = _toInt(r['qty']);
              if (action == 'IN') totalIn += qty;
              if (action == 'OUT') totalOut += qty;
            }
            final net = totalIn - totalOut;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _topControls(),
                const SizedBox(height: 12),
                _summaryRow(
                  orders: rows.length,
                  totalIn: totalIn,
                  totalOut: totalOut,
                  net: net,
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Center(child: Text('history.no_history'.tr())), // ✅
                  )
                else
                  ...rows.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryCard(
                        action: (r['action'] ?? '').toString(),
                        productName: (r['product_name'] ?? '-').toString(),
                        barcode: (r['barcode'] ?? '-').toString(),
                        qty: _toInt(r['qty']),
                        beforeQty: _toInt(r['before_qty']),
                        afterQty: _toInt(r['after_qty']),
                        note: (r['note'] ?? '').toString(),
                        createdAtText: _dateText(r['created_at']),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topControls() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrand.withOpacity(0.20), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, color: kBrand, size: 18),
              const SizedBox(width: 8),
              Text(
                "${'profile.role'.tr()}: ${(_myRole ?? '-')}", // ✅
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_isEmployee)
                Text(
                  'history.view_only'.tr(), // ✅
                  style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBrand.withOpacity(0.35), width: 1.4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: kBrand),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'history.search_hint'.tr(), // ✅
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: kBrand),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _chip('history.filter_today'.tr(), 'today'), // ✅
            const SizedBox(width: 8),
            _chip('history.filter_7d'.tr(), '7d'), // ✅
            const SizedBox(width: 8),
            _chip('history.filter_30d'.tr(), '30d'), // ✅
            const SizedBox(width: 8),
            _chip('history.filter_all'.tr(), 'all'), // ✅
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final active = _range == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setRange(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? kBrand : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kBrand.withOpacity(active ? 0.0 : 0.45), width: 1.4),
            boxShadow: [
              if (active)
                BoxShadow(color: kBrand.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : kBrand),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow({
    required int orders,
    required int totalIn,
    required int totalOut,
    required int net,
  }) {
    return Row(
      children: [
        Expanded(child: _statCard(title: 'history.moves'.tr(), value: '$orders')), // ✅
        const SizedBox(width: 10),
        Expanded(child: _statCard(title: 'history.in'.tr(), value: '+$totalIn')), // ✅
        const SizedBox(width: 10),
        Expanded(child: _statCard(title: 'history.out'.tr(), value: '-$totalOut')), // ✅
        const SizedBox(width: 10),
        Expanded(child: _statCard(title: 'history.net'.tr(), value: '${net >= 0 ? '+' : ''}$net')), // ✅
      ],
    );
  }

  Widget _statCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBrand.withOpacity(0.30), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _errorCard({
    required bool noShop,
    required bool forbidden,
    required String msg,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBrand, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            noShop ? 'history.err_no_shop'.tr() : forbidden ? 'history.err_forbidden'.tr() : 'Error: $msg', // ✅
            textAlign: TextAlign.center,
            style: TextStyle(color: noShop || forbidden ? Colors.black87 : Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrand),
            onPressed: onRetry,
            child: Text('history.btn_retry'.tr()), // ✅
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String action;
  final String productName;
  final String barcode;
  final int qty;
  final int beforeQty;
  final int afterQty;
  final String note;
  final String createdAtText;

  const _HistoryCard({
    required this.action,
    required this.productName,
    required this.barcode,
    required this.qty,
    required this.beforeQty,
    required this.afterQty,
    required this.note,
    required this.createdAtText,
  });

  bool get isIn => action.toUpperCase() == 'IN';

  @override
  Widget build(BuildContext context) {
    final pillBg = isIn ? kBrand.withOpacity(0.12) : Colors.redAccent.withOpacity(0.10);
    final pillBorder = isIn ? kBrand : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBrand.withOpacity(0.35), width: 1.3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pillBorder.withOpacity(0.55), width: 1.2),
            ),
            child: Icon(isIn ? Icons.call_received_rounded : Icons.call_made_rounded, color: pillBorder),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pillBorder.withOpacity(0.55), width: 1.2),
                      ),
                      child: Text(
                        isIn ? "${'history.in'.tr()}  +$qty" : "${'history.out'.tr()}  -$qty", // ✅
                        style: TextStyle(fontWeight: FontWeight.w900, color: pillBorder, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Barcode: $barcode',
                  style: TextStyle(color: Colors.black.withOpacity(0.62), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _miniChip('history.before'.tr(args: [beforeQty.toString()])), // ✅
                    _miniChip('history.after'.tr(args: [afterQty.toString()])), // ✅
                    _miniChip(createdAtText),
                    if (note.trim().isNotEmpty) _miniChip('history.note'.tr(args: [note])), // ✅
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kBrand.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBrand.withOpacity(0.18)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}