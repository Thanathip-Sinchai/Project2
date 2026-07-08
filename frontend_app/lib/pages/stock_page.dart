import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

import '../services/api_service.dart';
import 'product_form_page.dart';
import 'scan_center_page.dart';

const Color kBrand = Color(0xFF00C2F3);

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<List<dynamic>> _futureSummary;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _selectedFilterTag = ''; // จะถูกตั้งค่าเริ่มต้นใน build

  @override
  void initState() {
    super.initState();
    _futureSummary = ApiService.fetchProductSummary();
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _futureSummary = ApiService.fetchProductSummary();
    });
  }

  Future<void> _openScanShortcut() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanCenterPage()),
    );

    if (!mounted) return;

    if (result == true) {
      _reload(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('stock.toast_scan_success'.tr())), // ✅
      );
    }
  }

  String _nameKey(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  List<Map<String, dynamic>> _mergeSummary(List<dynamic> raw) {
    final Map<String, Map<String, dynamic>> map = {};

    for (final it in raw) {
      final row = (it as Map).cast<String, dynamic>();
      final name = (row['product_name'] ?? '-').toString();
      final barcode = (row['barcode'] ?? '').toString().trim();

      final key = barcode.isNotEmpty ? barcode : _nameKey(name);

      final lotsCount = int.tryParse('${row['lots_count'] ?? 0}') ?? 0;
      final totalQty = int.tryParse('${row['total_quantity'] ?? row['current_quantity'] ?? 0}') ?? 0;
      final groupImage = (row['group_image'] ?? '').toString().trim();

      if (!map.containsKey(key)) {
        map[key] = {
          'product_name': name.trim(),
          'barcode': barcode,
          'lots_count': lotsCount,
          'total_quantity': totalQty,
          'group_image': groupImage,
        };
      } else {
        map[key]!['lots_count'] = (int.tryParse('${map[key]!['lots_count'] ?? 0}') ?? 0) + lotsCount;
        map[key]!['total_quantity'] = (int.tryParse('${map[key]!['total_quantity'] ?? 0}') ?? 0) + totalQty;

        final oldImg = (map[key]!['group_image'] ?? '').toString().trim();
        if (oldImg.isEmpty && groupImage.isNotEmpty) {
          map[key]!['group_image'] = groupImage;
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => '${a['product_name']}'.compareTo('${b['product_name']}'));
    return list;
  }

  Widget _buildDynamicFilterChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: kBrand,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? kBrand : Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFilterTag.isEmpty) {
      _selectedFilterTag = 'stock.tag_all'.tr(); // เซ็ตค่าเริ่มต้นเป็นคำแปล
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC), 
      appBar: AppBar(
        backgroundColor: kBrand,
        elevation: 0,
        centerTitle: true,
        title: Text('app_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), // ✅
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            backgroundColor: Colors.white,
            foregroundColor: kBrand,
            elevation: 4,
            onPressed: () async {
              final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormPage()));
              if (changed == true) _reload();
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'scan',
            backgroundColor: kBrand,
            elevation: 6,
            onPressed: _openScanShortcut,
            child: const Icon(Icons.qr_code_scanner, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: kBrand,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'stock.search_hint'.tr(), // ✅
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, color: kBrand),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                FutureBuilder<List<dynamic>>(
                  future: _futureSummary,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.hasError) return const SizedBox.shrink();
                    
                    final raw = snapshot.data ?? [];
                    final allItems = _mergeSummary(raw);
                    
                    Set<String> uniqueNames = {};
                    for (var item in allItems) {
                      String name = (item['product_name'] ?? '').toString().trim();
                      if (name.isNotEmpty) uniqueNames.add(name);
                    }
                    
                    List<String> dynamicTags = ['stock.tag_all'.tr(), ...uniqueNames.toList()..sort()].take(15).toList(); // ✅

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: dynamicTags.map((tag) {
                          return _buildDynamicFilterChip(
                            tag,
                            isSelected: _selectedFilterTag == tag,
                            onTap: () {
                              setState(() {
                                _selectedFilterTag = tag;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async { _reload(); },
              child: FutureBuilder<List<dynamic>>(
                future: _futureSummary,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kBrand));
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final raw = snapshot.data ?? [];
                  final allItems = _mergeSummary(raw); 
                  
                  final items = allItems.where((item) {
                    final name = (item['product_name'] ?? '').toString().toLowerCase();
                    final barcode = (item['barcode'] ?? '').toString().toLowerCase();

                    bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || barcode.contains(_searchQuery);
                    
                    bool matchesTag = true;
                    if (_selectedFilterTag != 'stock.tag_all'.tr()) { // ✅
                      matchesTag = name == _selectedFilterTag.toLowerCase();
                    }

                    return matchesSearch && matchesTag;
                  }).toList();

                  final totalSkus = items.length;
                  final totalVolume = items.fold<int>(0, (sum, item) => sum + (item['total_quantity'] as int));

                  if (allItems.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Center(child: Text('stock.empty_stock'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 16))), // ✅
                      ],
                    );
                  }

                  if (items.isEmpty) {
                    return Center(child: Text('stock.not_found'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 16))); // ✅
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(child: _DashboardCard(title: 'stock.skus_title'.tr(), value: '$totalSkus', subtitle: 'stock.skus_sub'.tr(), icon: Icons.category, color: Colors.orange.shade400)), // ✅
                              const SizedBox(width: 12),
                              Expanded(child: _DashboardCard(title: 'stock.vol_title'.tr(), value: '$totalVolume', subtitle: 'stock.vol_sub'.tr(), icon: Icons.inventory, color: kBrand)), // ✅
                            ],
                          ),
                        );
                      }

                      final row = items[index - 1];
                      final name = (row['product_name'] ?? '-').toString();
                      final lotsCount = int.tryParse('${row['lots_count'] ?? 0}') ?? 0;
                      final totalQty = int.tryParse('${row['total_quantity'] ?? 0}') ?? 0;
                      final groupImage = (row['group_image'] ?? '').toString().trim();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(
                          productName: name,
                          lotsCount: lotsCount,
                          totalQty: totalQty,
                          groupImagePath: groupImage.isEmpty ? null : groupImage,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductLotsPage(productName: name)));
                            if (!mounted) return;
                            _reload();
                          },
                          onChangeGroupImage: () async {
                            final picker = ImagePicker();
                            final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (x == null) return;
                            final bytes = await x.readAsBytes();
                            try {
                              await ApiService.updateGroupImage(productName: name, imageBytes: bytes, imageFilename: x.name.isNotEmpty ? x.name : 'group.jpg', imageFieldName: 'image');
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('stock.toast_group_img_success'.tr()))); // ✅
                              _reload();
                            } catch (e) {}
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Widget: Dashboard Card =====================
class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DashboardCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ===================== Group Card =====================
class _GroupCard extends StatelessWidget {
  final String productName;
  final int lotsCount;
  final int totalQty;
  final String? groupImagePath;
  final VoidCallback onTap;
  final VoidCallback onChangeGroupImage;

  const _GroupCard({
    required this.productName,
    required this.lotsCount,
    required this.totalQty,
    required this.groupImagePath,
    required this.onTap,
    required this.onChangeGroupImage,
  });

  String _imageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) return imagePath;
    return '${ApiService.baseUrl}$imagePath';
  }

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = totalQty <= 0;
    final Color statusColor = isOutOfStock ? Colors.redAccent : kBrand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChangeGroupImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kBrand.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: (groupImagePath == null)
                            ? const Center(child: Icon(Icons.inventory_2, color: kBrand, size: 28))
                            : Image.network(_imageUrl(groupImagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 24))),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                      child: const Icon(Icons.camera_alt, size: 12, color: kBrand),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87, height: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('stock.lots_count'.tr(args: [lotsCount.toString()]), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)), // ✅
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isOutOfStock ? 'stock.out_of_stock'.tr() : 'stock.in_stock'.tr(), style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)), // ✅
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Text('$totalQty', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== LOTS PAGE =====================

class ProductLotsPage extends StatefulWidget {
  final String productName;
  const ProductLotsPage({super.key, required this.productName});

  @override
  State<ProductLotsPage> createState() => _ProductLotsPageState();
}

class _ProductLotsPageState extends State<ProductLotsPage> {
  late Future<List<dynamic>> _futureLots;
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _selectedFilterTagLot = '';

  @override
  void initState() {
    super.initState();
    _futureLots = ApiService.fetchProductLotsByName(widget.productName);
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _futureLots = ApiService.fetchProductLotsByName(widget.productName);
    });
  }

  int _getId(Map<String, dynamic> p) {
    final raw = p['id'] ?? p['product_id'] ?? p['productId'];
    return int.tryParse('$raw') ?? 0;
  }
  double _toDouble(dynamic v) => double.tryParse('${v ?? 0}'.trim()) ?? 0.0;
  int _toInt(dynamic v) => int.tryParse('${v ?? 0}'.trim()) ?? 0;
  String _prodDateText(dynamic raw) {
    final s = raw?.toString() ?? '-';
    if (s.contains('T')) return s.split('T')[0];
    return s;
  }
  String? _imagePath(Map<String, dynamic> p) {
    final v = p['product_image'] ?? p['image'] ?? p['image_url'];
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }
  String _imageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) return imagePath;
    return '${ApiService.baseUrl}$imagePath';
  }

  String _addSizeStrings(String s1, String s2) {
    final reg = RegExp(r'\d+(\.\d+)?'); // ค้นหาตัวเลข (รวมทศนิยม)
    final m1 = reg.firstMatch(s1);
    final m2 = reg.firstMatch(s2);
    
    if (m1 != null && m2 != null) {
      double v1 = double.parse(m1.group(0)!);
      double v2 = double.parse(m2.group(0)!);
      double sum = v1 + v2;
      
      String sumStr = sum == sum.toInt() ? sum.toInt().toString() : sum.toString();
      return s1.replaceFirst(reg, sumStr);
    } else if (m1 != null) {
      return s1;
    } else if (m2 != null) {
      return s2;
    }
    return s1.isNotEmpty ? s1 : s2;
  }

  List<Map<String, dynamic>> _mergeLots(List<dynamic> raw) {
    final Map<String, Map<String, dynamic>> map = {};

    for (final it in raw) {
      final lot = (it as Map).cast<String, dynamic>();
      final barcode = (lot['barcode'] ?? '').toString().trim();
      final size = (lot['size'] ?? '').toString().trim();
      
      final key = barcode.isNotEmpty ? barcode : (lot['product_name'] ?? '').toString().trim();

      if (!map.containsKey(key)) {
        map[key] = Map<String, dynamic>.from(lot);
        map[key]!['merged_ids'] = <int>[_getId(lot)]; 
        
        map[key]!['total_in'] = _toInt(lot['total_in'] ?? lot['quantity']);
        map[key]!['total_out'] = _toInt(lot['total_out'] ?? 0);
        
        // 📌 เก็บค่า Original ของ ID แรกไว้ เพื่อไม่ให้ตอนอัปเดตรูป/แก้ไขข้อมูล ค่าเพี้ยน
        map[key]!['first_qty'] = _toInt(lot['quantity']);
        map[key]!['first_size'] = (lot['size'] ?? '').toString();
      } else {
        final currentQty = _toInt(map[key]!['quantity']);
        final extraQty = _toInt(lot['quantity']);
        map[key]!['quantity'] = currentQty + extraQty;

        map[key]!['total_in'] = _toInt(map[key]!['total_in']) + _toInt(lot['total_in'] ?? lot['quantity']);
        map[key]!['total_out'] = _toInt(map[key]!['total_out']) + _toInt(lot['total_out'] ?? 0);
        
        map[key]!['size'] = _addSizeStrings(map[key]!['size'].toString(), size);

        (map[key]!['merged_ids'] as List<int>).add(_getId(lot));

        final currentImg = _imagePath(map[key]!);
        final newImg = _imagePath(lot);
        if (currentImg == null && newImg != null) {
          map[key]!['product_image'] = newImg;
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => _prodDateText(b['productionDate']).compareTo(_prodDateText(a['productionDate'])));
    return list;
  }

  Future<void> _openEdit(Map<String, dynamic> lot) async {
    // 📌 ส่งค่า Original ไปให้ฟอร์มแก้ไข เพื่อป้องกันการบันทึกค่ายอดรวมกลับไปที่ ID เดียว
    Map<String, dynamic> editLot = Map<String, dynamic>.from(lot);
    editLot['quantity'] = _toInt(lot['first_qty'] ?? lot['quantity']);
    editLot['size'] = (lot['first_size'] ?? lot['size'] ?? '').toString();

    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormPage(product: editLot)));
    if (changed == true) {
      // 📌 นำลูป Delete ออก! ป้องกันการลบข้อมูลประวัติของแถวอื่น
      _reload();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> lot) async {
    final ids = lot['merged_ids'] as List<int>? ?? [_getId(lot)];
    if (ids.isEmpty || ids.first == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('stock.del_title'.tr()), // ✅
        content: Text('stock.del_desc'.tr(args: [widget.productName])), // ✅
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('stock.btn_cancel'.tr())), // ✅
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: Text('stock.btn_delete'.tr())), // ✅
        ],
      ),
    );

    if (ok == true) {
      try {
        for (final id in ids) {
          if (id != 0) await ApiService.deleteProduct(id);
        }
        _reload();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _changeLotImage(Map<String, dynamic> lot) async {
    final ids = lot['merged_ids'] as List<int>? ?? [_getId(lot)];
    if (ids.isEmpty || ids.first == 0) return;
    final firstId = ids.first;

    Future<void> pickAndUpload(ImageSource source) async {
      try {
        final x = await _picker.pickImage(source: source, imageQuality: 85);
        if (x == null) return;
        final Uint8List bytes = await x.readAsBytes();

        // 📌 BUG FIX: ใช้ข้อมูล original ของ firstId ส่งกลับไป ไม่ใช่ข้อมูลที่จับบวกกันแล้ว
        await ApiService.updateProductWithImage(
          id: firstId,
          name: (lot['product_name'] ?? widget.productName).toString(),
          code: (lot['barcode'] ?? '').toString(),
          size: (lot['first_size'] ?? lot['size'] ?? '').toString(),
          quantity: _toInt(lot['first_qty'] ?? lot['quantity']), 
          price: _toDouble(lot['unit_price']),
          productionDate: _prodDateText(lot['productionDate']),
          imageBytes: bytes,
          imageFilename: x.name.isNotEmpty ? x.name : 'lot.jpg',
          imageFieldName: 'image',
        );
        
        // 📌 นำลูป Delete ออก! นี่คือต้นเหตุที่ทำให้ "ประวัติรับเข้า" ของแถวอื่นถูกลบไป 

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('stock.toast_lot_img_success'.tr()))); // ✅
        _reload();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${'stock.toast_lot_img_fail'.tr()} $e"))); // ✅
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFFF6FBFF), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Text('stock.update_lot_img'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), // ✅
                const SizedBox(height: 12),
                _sheetBtn(icon: Icons.photo_library_outlined, text: 'lists.img_gallery'.tr(), onTap: () async { Navigator.pop(context); await pickAndUpload(ImageSource.gallery); }), // ✅
                const SizedBox(height: 10),
                _sheetBtn(icon: Icons.camera_alt_outlined, text: 'lists.img_camera'.tr(), onTap: () async { Navigator.pop(context); await pickAndUpload(ImageSource.camera); }), // ✅
                const SizedBox(height: 6),
                const Divider(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('lists.btn_close'.tr(), style: const TextStyle(color: kBrand))), // ✅
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetBtn({required IconData icon, required String text, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrand.withOpacity(0.25), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 8))]),
          child: Row(children: [Icon(icon, color: kBrand), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))), const Icon(Icons.chevron_right, color: Colors.black38)]),
        ),
      ),
    );
  }

  Widget _buildDynamicFilterChipLot(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: kBrand,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? kBrand : Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFilterTagLot.isEmpty) {
      _selectedFilterTagLot = 'stock.tag_all'.tr(); // ✅
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC),
      appBar: AppBar(
        backgroundColor: kBrand,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: kBrand,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'stock.search_hint_lot'.tr(), // ✅
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: kBrand),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); })
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                FutureBuilder<List<dynamic>>(
                  future: _futureLots,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.hasError) return const SizedBox.shrink();
                    
                    final rawData = snapshot.data ?? [];
                    final lots = _mergeLots(rawData);
                    
                    Set<String> dynamicHints = {};
                    for (var lot in lots) {
                      String barcode = (lot['barcode'] ?? '').toString().trim();
                      if (barcode.isNotEmpty && barcode != '-') dynamicHints.add('Barcode: $barcode');
                    }
                    
                    List<String> dynamicTagsLot = ['stock.tag_all'.tr(), ...dynamicHints.toList()..sort()]; // ✅

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: dynamicTagsLot.map((tag) {
                          return _buildDynamicFilterChipLot(
                            tag,
                            isSelected: _selectedFilterTagLot == tag,
                            onTap: () {
                              setState(() {
                                _selectedFilterTagLot = tag;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _futureLots,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kBrand));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                final rawData = snapshot.data ?? [];
                final lots = _mergeLots(rawData);
                
                final filteredLots = lots.where((lot) {
                  final lotMap = lot as Map;
                  final barcode = (lotMap['barcode'] ?? '').toString().toLowerCase();
                  final size = (lotMap['size'] ?? '').toString().toLowerCase();
                  final mfg = _prodDateText(lotMap['productionDate']).toLowerCase();

                  bool matchesSearch = _searchQuery.isEmpty || 
                                       barcode.contains(_searchQuery) ||
                                       size.contains(_searchQuery) ||
                                       mfg.contains(_searchQuery);
                                       
                  bool matchesTag = true;
                  if (_selectedFilterTagLot != 'stock.tag_all'.tr()) { // ✅
                    if (_selectedFilterTagLot.startsWith('Barcode: ')) {
                      matchesTag = barcode == _selectedFilterTagLot.replaceAll('Barcode: ', '').toLowerCase();
                    }
                  }

                  return matchesSearch && matchesTag;
                }).toList();

                if (lots.isEmpty) {
                  return Center(child: Text('stock.no_lots'.tr(), style: const TextStyle(color: Colors.grey))); // ✅
                }

                if (filteredLots.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('stock.filter_no_match'.tr(), style: const TextStyle(color: Colors.grey)), // ✅
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: filteredLots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lot = (filteredLots[index] as Map).cast<String, dynamic>();

                    final barcode = (lot['barcode'] ?? '-').toString();
                    final size = (lot['size'] ?? '').toString();
                    final price = (lot['unit_price'] ?? 0).toString();
                    final qty = int.tryParse('${lot['quantity'] ?? 0}') ?? 0;
                    
                    final totalIn = int.tryParse('${lot['total_in'] ?? 0}') ?? 0;
                    final totalOut = int.tryParse('${lot['total_out'] ?? 0}') ?? 0;

                    final mfg = _prodDateText(lot['productionDate']);
                    final imgPath = _imagePath(lot);

                    final bool isOutOfStock = qty <= 0;
                    final Color qtyColor = isOutOfStock ? Colors.redAccent : kBrand;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openEdit(lot),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _changeLotImage(lot),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(color: kBrand.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 3)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: imgPath == null
                                            ? const Center(child: Icon(Icons.inventory_2, color: kBrand, size: 28))
                                            : Image.network(_imageUrl(imgPath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 24))),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                                      child: const Icon(Icons.camera_alt, size: 12, color: kBrand),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Barcode: $barcode', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (size.trim().isNotEmpty && size != '-') _chip('stock.size_val'.tr(args: [size])), // ✅
                                        if (price != '0.0' && price != '0') _chip('stock.cost_val'.tr(args: [price])), // ✅
                                        _chip('stock.mfg_val'.tr(args: [mfg]), isLight: true), // ✅
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // 📌 FIX แถบแดง: เปลี่ยนจาก Row เป็น Wrap เพื่อห่อคำอัตโนมัติหากหน้าจอแคบ
                                    Wrap(
                                      spacing: 12, 
                                      runSpacing: 4, 
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.arrow_circle_down, size: 14, color: Colors.green.shade600),
                                            const SizedBox(width: 4),
                                            Text('stock.in_qty'.tr(args: [totalIn.toString()]), style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.arrow_circle_up, size: 14, color: Colors.red.shade600),
                                            const SizedBox(width: 4),
                                            Text('stock.out_qty'.tr(args: [totalOut.toString()]), style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(color: qtyColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: qtyColor.withOpacity(0.3))),
                                    child: Column(
                                      children: [
                                        Text(isOutOfStock ? 'stock.status_out'.tr() : 'stock.status_in'.tr(), style: TextStyle(color: qtyColor, fontSize: 10, fontWeight: FontWeight.bold)), // ✅
                                        Text('$qty', style: TextStyle(color: qtyColor, fontSize: 18, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(onTap: () => _openEdit(lot), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.black54, size: 18))),
                                      const SizedBox(width: 8),
                                      InkWell(onTap: () => _confirmDelete(lot), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18))),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool isLight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isLight ? Colors.grey.shade100 : kBrand.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: isLight ? Colors.grey.shade300 : kBrand.withOpacity(0.2))),
      child: Text(text, style: TextStyle(fontSize: 11, color: isLight ? Colors.black54 : kBrand, fontWeight: FontWeight.w600)),
    );
  }
}