import 'package:flutter/material.dart';

import '../widgets/app_bottom_bar.dart';

// ✅ แก้ import ให้ตรงชื่อไฟล์หน้าของคุณ
import 'home_page.dart';
import 'stock_page.dart';
import 'lists_page.dart';
import 'more_page.dart';
import 'profile_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  AppTab _activeTab = AppTab.home;

  void _setTab(AppTab t) {
    setState(() => _activeTab = t);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_activeTab) {
      case AppTab.home:
        body = const HomePage();
        break;

      case AppTab.stock:
        body = const StockPage();
        break;

      case AppTab.lists:
        // ✅ ส่ง callback เข้า ListsPage เพื่อให้กด Save แล้วเด้งไป Stock
        body = ListsPage(
          onSavedGoToStock: () => _setTab(AppTab.stock),
        );
        break;

      case AppTab.more:
        body = const MorePage();
        break;

      case AppTab.profile:
        body = const ProfilePage();
        break;
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: AppBottomBar(
        active: _activeTab,
        onChanged: _setTab,
      ),
    );
  }
}
