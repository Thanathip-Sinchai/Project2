import 'package:flutter/material.dart';

enum AppTab { home, stock, lists, more, profile }

class AppBottomBar extends StatelessWidget {
  final AppTab active;
  final ValueChanged<AppTab> onChanged;

  const AppBottomBar({
    super.key,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF00C2F3);

    Widget item(IconData icon, String label, AppTab tab) {
      final isActive = tab == active;

      if (isActive) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: bg),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: bg, fontSize: 11)),
            ],
          ),
        );
      }

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(tab),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.home, 'Home', AppTab.home),
          item(Icons.add_circle_outline, 'Stock', AppTab.stock),
          // ✅ LISTS กลับมาแทน EMPLOYEES
          item(Icons.list_alt, 'Lists', AppTab.lists),
          item(Icons.more_horiz, 'More', AppTab.more),
          item(Icons.person, 'Profile', AppTab.profile),
        ],
      ),
    );
  }
}
