import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import

import '../services/api_service.dart';

class Employee {
  final String id;
  String name;
  String username;
  String phone;
  String role;
  bool isActive;

  Employee({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    required this.role,
    this.isActive = true,
  });

  static Employee fromMemberJson(Map<String, dynamic> j) {
    final userId = (j['id'] ?? j['user_id'] ?? '').toString();
    final username = (j['username'] ?? '').toString();
    final email = (j['email'] ?? '').toString();
    final role = (j['role'] ?? 'employee').toString();

    return Employee(
      id: userId,
      name: username,
      username: username,
      phone: email,
      role: role,
      isActive: true,
    );
  }
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const bg = Color(0xFF00C2F3);

  final List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  String? _myRole;

  bool get _isOwner => (_myRole ?? '').toLowerCase() == 'owner';
  bool get _isEmployee => (_myRole ?? '').toLowerCase() == 'employee';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final r = await ApiService.getSelectedShopRole();
    final role = (r ?? '').toLowerCase();

    if (!mounted) return;

    if (role == 'employee') {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _myRole = role);
    await _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
      _employees.clear();
    });

    try {
      final list = await ApiService.fetchShopMembers();
      final members = list
          .map((e) => Employee.fromMemberJson((e as Map).cast<String, dynamic>()))
          .toList();

      setState(() => _employees.addAll(members));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addUserToShop({required int userId, required String role}) async {
    await ApiService.addShopMember(userId: userId, role: role);
  }

  Future<void> _updateRole({required int userId, required String role}) async {
    await ApiService.updateShopMemberRole(userId: userId, role: role);
  }

  Future<void> _removeMember(int userId) async {
    await ApiService.removeShopMember(userId);
  }

  Future<void> _openAddDialog() async {
    if (!_isOwner) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(
        onSearch: (q) async {
          final list = await ApiService.searchUsersForShop(query: q);
          return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        },
        onAdd: (userId, role) async {
          await _addUserToShop(userId: userId, role: role);
          await _loadMembers();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('employees.toast_add_success'.tr())), // ✅
          );
        },
      ),
    );
  }

  Future<void> _openEditRole(Employee emp) async {
    if (!_isOwner) return;

    final userId = int.tryParse(emp.id);
    if (userId == null) return;

    final newRole = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('employees.change_role_title'.tr()), // ✅
        content: Text('employees.change_role_desc'.tr(args: [emp.username])), // ✅
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('employees.btn_cancel'.tr())), // ✅
          TextButton(onPressed: () => Navigator.pop(context, 'owner'), child: Text('employees.role_owner'.tr())), // ✅
          TextButton(onPressed: () => Navigator.pop(context, 'manager'), child: Text('employees.role_manager'.tr())), // ✅
          TextButton(onPressed: () => Navigator.pop(context, 'employee'), child: Text('employees.role_employee'.tr())), // ✅
        ],
      ),
    );

    if (newRole == null) return;

    try {
      await _updateRole(userId: userId, role: newRole);
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('employees.toast_role_success'.tr())), // ✅
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'employees.toast_role_fail'.tr()} $e")), // ✅
      );
    }
  }

  Future<void> _confirmDelete(Employee emp) async {
    if (!_isOwner) return;

    final userId = int.tryParse(emp.id);
    if (userId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('employees.remove_title'.tr()), // ✅
        content: Text('employees.remove_desc'.tr(args: [emp.username])), // ✅
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('employees.btn_cancel'.tr())), // ✅
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('employees.btn_remove'.tr()), // ✅
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _removeMember(userId);
        await _loadMembers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('employees.toast_remove_success'.tr())), // ✅
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${'employees.toast_remove_fail'.tr()} $e")), // ✅
        );
      }
    }
  }

  List<Employee> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _employees;

    return _employees.where((e) {
      final base = e.name.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          e.phone.toLowerCase().contains(q) ||
          e.id.toLowerCase().contains(q);

      return _isOwner ? (base || e.role.toLowerCase().contains(q)) : base;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_myRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isEmployee) return const SizedBox.shrink();

    final noShop = (_error ?? '').contains('NO_SHOP_SELECTED');

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('employees.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
        actions: [
          if (_isOwner)
            IconButton(
              onPressed: _openAddDialog,
              icon: const Icon(Icons.add, color: Colors.white),
            ),
          IconButton(
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton(
              backgroundColor: bg,
              onPressed: _openAddDialog,
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (noShop) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bg, width: 1.5),
                ),
                child: Text(
                  'employees.no_shop'.tr(), // ✅
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _searchBar(),
            const SizedBox(height: 12),
            _headerRow(),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null && !noShop)
                      ? Center(child: Text(_error!, textAlign: TextAlign.center))
                      : _filtered.isEmpty
                          ? Center(child: Text('employees.no_employees'.tr())) // ✅
                          : ListView.separated(
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _employeeCard(_filtered[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bg, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: bg),
          hintText: 'employees.search_hint'.tr(), // ✅
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bg, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: bg),
          const SizedBox(width: 10),
          Expanded(
            child: Text('employees.col_name'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: bg)), // ✅
          ),
          if (_isOwner) ...[
            const SizedBox(width: 10),
            Text('employees.col_role'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: bg)), // ✅
          ],
        ],
      ),
    );
  }

  Widget _employeeCard(Employee emp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bg, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bg.withOpacity(0.15),
            child: const Icon(Icons.person, color: bg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.username.isEmpty ? '(no username)' : emp.username,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('UID ${emp.id} • ${emp.phone}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),

          if (_isOwner) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: bg.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bg.withOpacity(0.35)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: emp.role,
                  items: [
                    DropdownMenuItem(value: 'owner', child: Text('employees.role_owner'.tr())), // ✅
                    DropdownMenuItem(value: 'manager', child: Text('employees.role_manager'.tr())), // ✅
                    DropdownMenuItem(value: 'employee', child: Text('employees.role_employee'.tr())), // ✅
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    final userId = int.tryParse(emp.id);
                    if (userId == null) return;

                    final old = emp.role;
                    setState(() => emp.role = v);

                    try {
                      await _updateRole(userId: userId, role: v);
                    } catch (e) {
                      setState(() => emp.role = old);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${'employees.toast_role_fail'.tr()} $e")), // ✅
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'role') _openEditRole(emp);
                if (v == 'delete') _confirmDelete(emp);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'role', child: Text('employees.change_role_title'.tr())), // ✅
                PopupMenuItem(value: 'delete', child: Text('employees.btn_remove'.tr())), // ✅
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String q) onSearch;
  final Future<void> Function(int userId, String role) onAdd;

  const _AddMemberSheet({required this.onSearch, required this.onAdd});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  static const bg = Color(0xFF00C2F3);

  final _q = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final text = _q.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final r = await widget.onSearch(text);
      setState(() => _results = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6FBFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('employees.add_sheet_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // ✅
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _q,
                        decoration: InputDecoration(
                          hintText: 'employees.search_user_hint'.tr(), // ✅
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _doSearch(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: bg),
                      onPressed: _loading ? null : _doSearch,
                      child: Text(_loading ? 'employees.btn_searching'.tr() : 'employees.btn_search'.tr()), // ✅
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                if (!_loading)
                  SizedBox(
                    height: 320,
                    child: _results.isEmpty
                        ? Center(child: Text('employees.no_results'.tr())) // ✅
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final u = _results[i];
                              final id = int.tryParse((u['id'] ?? '').toString()) ?? 0;
                              final username = (u['username'] ?? '').toString();
                              final email = (u['email'] ?? '').toString();

                              return Card(
                                child: ListTile(
                                  title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(email),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (role) async {
                                      try {
                                        await widget.onAdd(id, role);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("${'employees.toast_add_fail'.tr()} $e")), // ✅
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'manager', child: Text('employees.add_manager'.tr())), // ✅
                                      PopupMenuItem(value: 'employee', child: Text('employees.add_employee'.tr())), // ✅
                                    ],
                                    icon: const Icon(Icons.person_add),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}