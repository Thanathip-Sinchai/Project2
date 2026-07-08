import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ระบบภาษา
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const bg = Color(0xFF00C2F3);

  bool loading = true;
  int totalProducts = 0;
  int lowStockCount = 0;
  List<dynamic> lowStockItems = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => loading = true);

    try {
      final summary = await ApiService.fetchProductSummary();

      int total = 0;
      int low = 0;
      List<dynamic> lowList = [];

      for (var item in summary) {
        total += 1;

        final qty = int.tryParse(item['total_quantity'].toString()) ?? 0;

        if (qty <= 5) {
          low += 1;
          lowList.add(item);
        }
      }

      if (!mounted) return;

      setState(() {
        totalProducts = total;
        lowStockCount = low;
        lowStockItems = lowList;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'app_name'.tr(), // ✅ เปลี่ยนเป็นภาษาแบบ Dynamic
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSummary,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: bg))
          : RefreshIndicator(
              onRefresh: _loadSummary,
              color: bg,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ===== STAT CARDS =====
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.warning_amber_rounded,
                            title: 'home.low_stock'.tr(), // ✅
                            value: lowStockCount.toString(),
                            iconColor: Colors.orange.shade500,
                            bgColor: Colors.orange.shade50,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'home.all_products'.tr(), // ✅
                            value: totalProducts.toString(),
                            iconColor: bg,
                            bgColor: bg.withOpacity(0.15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    /// ===== NOTIFICATIONS =====
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: bg.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: const Icon(Icons.notifications_active, color: bg, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'home.notifications'.tr(), // ✅
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (lowStockItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'home.no_alerts'.tr(), // ✅
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'home.stock_normal'.tr(), // ✅
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...lowStockItems.map(
                        (item) => _NotificationCard(
                          title: item['product_name'],
                          // ✅ แทรกตัวเลขลงในข้อความที่ถูกแปล
                          subtitle: 'home.remaining'.tr(args: [item['total_quantity'].toString()]), 
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// ================= STAT CARD =================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= NOTIFICATION CARD =================
class _NotificationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _NotificationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color, 
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}