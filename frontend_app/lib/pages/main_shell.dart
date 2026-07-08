import 'package:flutter/material.dart';
import '../widgets/app_bottom_bar.dart';

import 'home_page.dart';
import 'stock_page.dart';
import 'lists_page.dart';
import 'more_page.dart';
import 'profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;

  final List<Widget> _pages = const [
    HomePage(),
    StockPage(),
    ListsPage(), // ✅ Lists
    MorePage(),  // ✅ Employees ไปอยู่ใน More
    ProfilePage(),
  ];

  int get _index => AppTab.values.indexOf(_tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomBar(
        active: _tab,
        onChanged: (t) => setState(() => _tab = t),
      ),
    );
  }
}
