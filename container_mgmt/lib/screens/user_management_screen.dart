import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const _roles = ['Admin', 'Port Manager', 'Driver', 'Customer', 'Checker'];

// Fallback port list used when API is unavailable
final _fallbackPorts = [
  Port(portId: 1, portDesc: 'Manila Port'),
  Port(portId: 2, portDesc: 'Cebu Port'),
  Port(portId: 3, portDesc: 'Davao Port'),
  Port(portId: 4, portDesc: 'Bacolod Port'),
  Port(portId: 5, portDesc: 'Cagayan Port'),
  Port(portId: 6, portDesc: 'Batangas Port'),
  Port(portId: 7, portDesc: 'Dumaguete Port'),
  Port(portId: 8, portDesc: 'General Santos Port'),
  Port(portId: 9, portDesc: 'Iligan Port'),
  Port(portId: 10, portDesc: 'Iloilo Port'),
  Port(portId: 11, portDesc: 'Masbate Port'),
  Port(portId: 12, portDesc: 'Ozamis Port'),
  Port(portId: 13, portDesc: 'Tacloban Port'),
  Port(portId: 14, portDesc: 'Tagbilaran Port'),
  Port(portId: 15, portDesc: 'Zamboanga Port'),
];

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _api = ApiService();
  List<UserModel> _users = [];
  List<UserModel> _filtered = [];
  List<Port> _ports = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterRole;
  int? _filterPortId;
  bool _showDeleted = false; // toggle to show/hide deleted users

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.getUsers(), _api.getPorts()]);
      setState(() {
        _users = results[0] as List<UserModel>;
        final apiPorts = results[1] as List<Port>;
        _ports = apiPorts.isNotEmpty ? apiPorts : _fallbackPorts;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        if (_ports.isEmpty) _ports = _fallbackPorts;
        _applyFilter();
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load users. Check your connection.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    var list = List.of(_users);

    // Show ONLY deleted users when toggle is on, otherwise hide them
    if (_showDeleted) {
      list = list.where((u) => u.statusId == userStatusDeleted).toList();
    } else {
      list = list.where((u) => u.statusId != userStatusDeleted).toList();
    }

    if (_filterRole != null) {
      list = list.where((u) => u.role == _filterRole).toList();
    }
    if ((_filterRole == 'Port Manager' || _filterRole == 'Driver') &&
        _filterPortId != null) {
      list = list.where((u) => u.assignedPortId == _filterPortId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (u) =>
                u.userCode.toLowerCase().contains(q) ||
                u.name.toLowerCase().contains(q),
          )
          .toList();
    }
    _filtered = list;
  }

  void _onSearch(String v) => setState(() {
    _searchQuery = v;
    _applyFilter();
  });
  void _setRoleFilter(String? r) => setState(() {
    _filterRole = r;
    _filterPortId = null;
    _applyFilter();
  });
  void _setPortFilter(int? p) => setState(() {
    _filterPortId = p;
    _applyFilter();
  });

  Future<void> _showReassignDialog(UserModel user) async {
    int? selected = user.assignedPortId;
    // Drivers can share ports freely — only Port Managers have exclusivity
    final takenPortIds = user.role == 'Port Manager'
        ? _users
              .where(
                (u) =>
                    u.role == 'Port Manager' &&
                    u.assignedPortId != null &&
                    u.userId != user.userId,
              )
              .map((u) => u.assignedPortId!)
              .toSet()
        : <int>{};

    final newPortId = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.textDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reassign Port',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select new port:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._ports.map((p) {
                    final taken = takenPortIds.contains(p.portId);
                    final isCurrent = p.portId == user.assignedPortId;
                    final isSel = p.portId == selected;
                    return GestureDetector(
                      onTap: taken
                          ? null
                          : () => setS(() => selected = p.portId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.green.withValues(alpha: 0.1)
                              : taken
                              ? Colors.grey.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? AppColors.green
                                : taken
                                ? Colors.grey.withValues(alpha: 0.3)
                                : AppColors.yellow.withValues(alpha: 0.4),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: taken
                                  ? AppColors.textGrey
                                  : isSel
                                  ? AppColors.green
                                  : AppColors.textDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.portDesc,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: taken
                                      ? AppColors.textGrey
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                            if (isCurrent) _tag('Current', AppColors.green),
                            if (taken && !isCurrent)
                              _tag('Taken', AppColors.textGrey),
                            if (isSel)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.yellow,
              ),
              onPressed: selected == null || selected == user.assignedPortId
                  ? null
                  : () => Navigator.pop(ctx, selected),
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
    if (newPortId == null) return;
    final newPort = _ports.firstWhere((p) => p.portId == newPortId);
    final updated = user.copyWith(
      assignedPortIds: [newPortId],
      assignedPortNames: [newPort.portDesc],
    );
    try {
      final saved = await _api.updateUser(updated);
      setState(() {
        final idx = _users.indexWhere((u) => u.userId == user.userId);
        if (idx != -1) _users[idx] = saved;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reassign port. Please try again.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showUserDialog({UserModel? existing}) async {
    final result = await showDialog<UserModel>(
      context: context,
      builder: (_) => _UserDialog(
        existing: existing,
        ports: _ports,
        takenPortIds: _users
            .where(
              (u) =>
                  u.role == 'Port Manager' &&
                  u.assignedPortId != null &&
                  u.userId != existing?.userId,
            )
            .map((u) => u.assignedPortId!)
            .toSet(),
        // Pass all existing codes (excluding the current user's own code when editing)
        existingCodes: _users
            .where((u) => u.userId != existing?.userId)
            .map((u) => u.userCode.toUpperCase())
            .toSet(),
      ),
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      if (existing == null) {
        final created = await _api.createUser(result);
        setState(() {
          _users.add(created);
          _applyFilter();
          _loading = false;
        });
      } else {
        final updated = await _api.updateUser(result);
        setState(() {
          final idx = _users.indexWhere((u) => u.userId == updated.userId);
          if (idx != -1) _users[idx] = updated;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        final msg = e.toString().contains('already taken')
            ? 'User code "${result.userCode}" is already taken. Please use a different code.'
            : existing == null
            ? 'Failed to create user. Please check your connection and try again.'
            : 'Failed to update user. Please check your connection and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            action: e.toString().contains('already taken')
                ? null
                : SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () => _showUserDialog(existing: existing),
                  ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Remove User',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.yellow.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _roleColor(
                      user.role,
                    ).withValues(alpha: 0.15),
                    radius: 20,
                    child: Icon(
                      Icons.person_rounded,
                      color: _roleColor(user.role),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Code: ${user.userCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This action is permanent and cannot be undone. Are you sure you want to remove this user?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGrey,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Remove'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      if (user.userId != null) {
        final softDeleted = await _api.deleteUser(user.userId!, user);
        setState(() {
          final idx = _users.indexWhere((u) => u.userId == user.userId);
          if (idx != -1) _users[idx] = softDeleted;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove user. Please try again.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            icon: Icon(
              _showDeleted
                  ? Icons.visibility_off_rounded
                  : Icons.delete_sweep_rounded,
              color: _showDeleted ? AppColors.red : AppColors.textDark,
            ),
            tooltip: _showDeleted ? 'Hide deleted users' : 'Show deleted users',
            onPressed: () => setState(() {
              _showDeleted = !_showDeleted;
              _applyFilter();
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Search + Filter row ──
          Container(
            color: AppColors.yellow,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by user code or name…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterDropdown(
                  ports: _ports,
                  selectedRole: _filterRole,
                  selectedPortId: _filterPortId,
                  onRoleChanged: _setRoleFilter,
                  onPortChanged: _setPortFilter,
                ),
              ],
            ),
          ),

          // ── Count strip ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  () {
                    final active = _users.where((u) => u.isActive).length;
                    final total = _users.length;
                    return '$active active · $total total';
                  }(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
                const Spacer(),
                ..._roles.map((r) {
                  final count = _users
                      .where((u) => u.role == r && !u.isDeleted)
                      .length;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _RoleBadge(role: r, count: count),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                : _filtered.isEmpty
                ? _EmptyState(
                    hasSearch: _searchQuery.isNotEmpty || _filterRole != null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _UserTile(
                      user: _filtered[i],
                      onEdit: _filtered[i].isDeleted
                          ? null
                          : () => _showUserDialog(existing: _filtered[i]),
                      onDelete: () => _confirmDelete(_filtered[i]),
                      onReassign:
                          _filtered[i].role == 'Port Manager' &&
                              !_filtered[i].isDeleted
                          ? () => _showReassignDialog(_filtered[i])
                          : null,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.yellow,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'ADD USER',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

Widget _tag(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    label,
    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
  ),
);

// ── Filter Dropdown ──────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final List<Port> ports;
  final String? selectedRole;
  final int? selectedPortId;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<int?> onPortChanged;

  const _FilterDropdown({
    required this.ports,
    required this.selectedRole,
    required this.selectedPortId,
    required this.onRoleChanged,
    required this.onPortChanged,
  });

  bool get _isFiltered => selectedRole != null;

  String get _label {
    if (selectedRole == null) return 'Filter';
    if ((selectedRole == 'Port Manager' || selectedRole == 'Driver') &&
        selectedPortId != null) {
      final port = ports.firstWhere(
        (p) => p.portId == selectedPortId,
        orElse: () => Port(portId: 0, portDesc: ''),
      );
      return port.portDesc.isNotEmpty ? port.portDesc : selectedRole!;
    }
    return selectedRole!;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter users',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
      itemBuilder: (_) => _buildMenuItems(),
      onSelected: (value) {
        if (value == '__clear__') {
          onRoleChanged(null);
          onPortChanged(null);
        } else if (value.startsWith('role:')) {
          final role = value.substring(5);
          onRoleChanged(role == selectedRole ? null : role);
          onPortChanged(null);
        } else if (value.startsWith('port:')) {
          final portId = int.parse(value.substring(5));
          onPortChanged(portId == selectedPortId ? null : portId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isFiltered ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: _isFiltered ? AppColors.yellow : AppColors.textGrey,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _isFiltered ? AppColors.yellow : AppColors.textGrey,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: _isFiltered ? AppColors.yellow : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[];
    items.add(
      const PopupMenuItem<String>(
        enabled: false,
        height: 32,
        child: Text(
          'FILTER BY ROLE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textGrey,
            letterSpacing: 1,
          ),
        ),
      ),
    );
    for (final role in _roles) {
      final isSel = selectedRole == role;
      items.add(
        PopupMenuItem<String>(
          value: 'role:$role',
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _roleColor(role),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSel)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.green,
                ),
            ],
          ),
        ),
      );
    }
    if ((selectedRole == 'Port Manager' || selectedRole == 'Driver') &&
        ports.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            'FILTER BY PORT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textGrey,
              letterSpacing: 1,
            ),
          ),
        ),
      );
      for (final port in ports) {
        final isSel = selectedPortId == port.portId;
        items.add(
          PopupMenuItem<String>(
            value: 'port:${port.portId}',
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: isSel ? AppColors.green : AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    port.portDesc,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? AppColors.green : AppColors.textDark,
                    ),
                  ),
                ),
                if (isSel)
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.green,
                  ),
              ],
            ),
          ),
        );
      }
    }
    if (selectedRole != null) {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem<String>(
          value: '__clear__',
          child: Row(
            children: [
              Icon(Icons.clear_rounded, size: 16, color: AppColors.red),
              SizedBox(width: 8),
              Text(
                'Clear Filter',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }
}

// ── Add / Edit Dialog ────────────────────────────────────────────────────────

class _UserDialog extends StatefulWidget {
  final UserModel? existing;
  final List<Port> ports;
  final Set<int> takenPortIds;
  final Set<String> existingCodes; // all user codes already in use
  const _UserDialog({
    this.existing,
    required this.ports,
    required this.takenPortIds,
    required this.existingCodes,
  });
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _miCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _passCtrl;
  late String _role;
  List<int> _selectedPortIds = [];
  bool _obscure = true;
  late int _statusId;
  String _codeError = '';

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.existing?.firstName ?? '');
    _miCtrl = TextEditingController(text: widget.existing?.middleInitial ?? '');
    _lastCtrl = TextEditingController(text: widget.existing?.lastName ?? '');
    _contactCtrl = TextEditingController(
      text: widget.existing?.contactNumber ?? '',
    );
    _codeCtrl = TextEditingController(text: widget.existing?.userCode ?? '');
    _passCtrl = TextEditingController();
    _role = widget.existing?.role ?? 'Port Manager';
    _selectedPortIds = List.of(widget.existing?.assignedPortIds ?? []);
    _statusId = widget.existing?.statusId ?? userStatusActive;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _miCtrl.dispose();
    _lastCtrl.dispose();
    _contactCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _nameVal(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    if (RegExp(r'[0-9]').hasMatch(v))
      return 'Numbers not allowed — letters and dots (.) only';
    if (RegExp(r'[^a-zA-Z. ]').hasMatch(v))
      return 'Only letters and dots (.) allowed';
    return null;
  }

  String? _miVal(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (RegExp(r'[0-9]').hasMatch(v)) return 'Numbers not allowed';
    if (RegExp(r'[^a-zA-Z.]').hasMatch(v))
      return 'Only a letter or letter + dot';
    if (v.trim().length > 2) return 'Max 2 characters (e.g. M or M.)';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if ((_role == 'Port Manager' || _role == 'Checker') &&
        _selectedPortIds.isEmpty) {
      setState(() {}); // triggers the inline error message to show
      return;
    }
    final needsPort =
        _role == 'Port Manager' || _role == 'Driver' || _role == 'Checker';
    final portNames = _selectedPortIds
        .map((id) {
          final match = widget.ports.where((p) => p.portId == id).toList();
          return match.isNotEmpty ? match.first.portDesc : '';
        })
        .where((n) => n.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      UserModel(
        userId: widget.existing?.userId,
        firstName: _firstCtrl.text.trim(),
        middleInitial: _miCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        contactNumber: _contactCtrl.text.trim().isEmpty
            ? null
            : _contactCtrl.text.trim(),
        userCode: _codeCtrl.text.trim(),
        role: _role,
        password: _passCtrl.text.trim().isEmpty ? null : _passCtrl.text.trim(),
        assignedPortIds: needsPort ? _selectedPortIds : [],
        assignedPortNames: needsPort ? portNames : [],
        statusId: _statusId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEdit ? Icons.edit : Icons.person_add,
              color: AppColors.textDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'Edit User' : 'Add User',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Role ──
                _lbl('Role'), const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(isDense: true),
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              _RoleDot(role: r),
                              const SizedBox(width: 8),
                              Text(r),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _role = v!;
                    if (_role != 'Port Manager' &&
                        _role != 'Driver' &&
                        _role != 'Checker') {
                      _selectedPortIds = [];
                    }
                  }),
                ),

                // ── Port (Port Manager, Driver & Checker) ──
                if (_role == 'Port Manager' ||
                    _role == 'Driver' ||
                    _role == 'Checker') ...[
                  const SizedBox(height: 14),
                  _lbl('Assigned Port'),
                  const SizedBox(height: 6),
                  _MultiPortPickerField(
                    ports: widget.ports,
                    selectedPortIds: _selectedPortIds,
                    onChanged: (ids) => setState(() => _selectedPortIds = ids),
                    multiSelect: false,
                  ),
                  if ((_role == 'Port Manager' || _role == 'Checker') &&
                      _selectedPortIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        'Please select at least one port',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 16),
                _sectionHeader(
                  Icons.person_outline_rounded,
                  'NAME INFORMATION',
                ),
                const SizedBox(height: 12),

                // ── First Name + M.I. ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl('First Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _firstCtrl,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                RegExp(r'[0-9]'),
                              ),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z. ]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'First name',
                              isDense: true,
                            ),
                            validator: (v) => _nameVal(v, 'First name'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl('M.I.'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _miCtrl,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                RegExp(r'[0-9]'),
                              ),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z.]'),
                              ),
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'M.I',
                              isDense: true,
                            ),
                            validator: _miVal,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Last Name ──
                _lbl('Last Name'), const SizedBox(height: 6),
                TextFormField(
                  controller: _lastCtrl,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z. ]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Last name',
                    isDense: true,
                  ),
                  validator: (v) => _nameVal(v, 'Last name'),
                ),

                const SizedBox(height: 16),
                _sectionHeader(Icons.badge_outlined, 'ACCOUNT INFORMATION'),
                const SizedBox(height: 12),

                // ── Contact Number ──
                _lbl('Contact Number'), const SizedBox(height: 6),
                TextFormField(
                  controller: _contactCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (value.trim().length < 10)
                      return 'Enter a valid contact number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── User Code ──
                _lbl('User Code'), const SizedBox(height: 6),
                TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    final code = v.trim().toUpperCase();
                    final isDuplicate = widget.existingCodes.contains(code);
                    setState(
                      () => _codeError = isDuplicate
                          ? 'User code "$code" is already taken'
                          : '',
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. ADM001',
                    isDense: true,
                    errorText: _codeError.isEmpty ? null : _codeError,
                    suffixIcon:
                        _codeError.isEmpty && _codeCtrl.text.trim().isNotEmpty
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.green,
                            size: 18,
                          )
                        : null,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (widget.existingCodes.contains(v.trim().toUpperCase())) {
                      return 'User code "${v.trim().toUpperCase()}" is already taken';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Password ──
                _lbl(
                  isEdit ? 'New Password (leave blank to keep)' : 'Password',
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: isEdit
                        ? 'Leave blank to keep current'
                        : 'Create a password',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (!isEdit && (v == null || v.trim().isEmpty))
                      return 'Password is required';
                    return null;
                  },
                ),

                // ── Status (edit only) ──
                if (isEdit) ...[
                  const SizedBox(height: 16),
                  _sectionHeader(Icons.toggle_on_outlined, 'ACCOUNT STATUS'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusOption(
                        label: 'Active',
                        statusId: userStatusActive,
                        selected: _statusId == userStatusActive,
                        onTap: () =>
                            setState(() => _statusId = userStatusActive),
                      ),
                      const SizedBox(width: 8),
                      _StatusOption(
                        label: 'Inactive',
                        statusId: userStatusInactive,
                        selected: _statusId == userStatusInactive,
                        onTap: () =>
                            setState(() => _statusId = userStatusInactive),
                      ),
                      const SizedBox(width: 8),
                      _StatusOption(
                        label: 'Deleted',
                        statusId: userStatusDeleted,
                        selected: _statusId == userStatusDeleted,
                        onTap: () =>
                            setState(() => _statusId = userStatusDeleted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.yellow,
          ),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
// ── Multi-Port Picker ────────────────────────────────────────────────────────

class _MultiPortPickerField extends StatelessWidget {
  final List<Port> ports;
  final List<int> selectedPortIds;
  final ValueChanged<List<int>> onChanged;
  final bool multiSelect;

  const _MultiPortPickerField({
    required this.ports,
    required this.selectedPortIds,
    required this.onChanged,
    this.multiSelect = true,
  });

  String get _displayText {
    if (selectedPortIds.isEmpty) return 'Select a port';
    final names = selectedPortIds.map((id) {
      final match = ports.where((p) => p.portId == id).toList();
      return match.isNotEmpty ? match.first.portDesc : 'Port $id';
    }).toList();
    return names.join(', ');
  }

  Future<void> _openPicker(BuildContext context) async {
    List<int> temp = List.of(selectedPortIds);

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        multiSelect
                            ? 'Select Ports (multiple allowed)'
                            : 'Select Port',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                // Port list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ports.length,
                    itemBuilder: (ctx2, i) {
                      final p = ports[i];
                      final isSelected = temp.contains(p.portId);
                      return InkWell(
                        onTap: () {
                          setS(() {
                            if (multiSelect) {
                              if (isSelected) {
                                temp.remove(p.portId);
                              } else {
                                temp.add(p.portId);
                              }
                            } else {
                              temp = [p.portId];
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.green.withValues(alpha: 0.08)
                                : Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                multiSelect
                                    ? (isSelected
                                          ? Icons.check_box_rounded
                                          : Icons
                                                .check_box_outline_blank_rounded)
                                    : (isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded),
                                size: 20,
                                color: isSelected
                                    ? AppColors.green
                                    : AppColors.textGrey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.portDesc,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (multiSelect && temp.isNotEmpty)
                        TextButton(
                          onPressed: () => setS(() => temp = []),
                          child: const Text(
                            'Clear all',
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.yellow,
                        ),
                        onPressed: () {
                          onChanged(temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedPortIds.isNotEmpty;
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSelection
                ? AppColors.green
                : AppColors.yellow.withValues(alpha: 0.6),
            width: hasSelection ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 18,
              color: hasSelection ? AppColors.green : AppColors.textGrey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayText,
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection ? AppColors.textDark : AppColors.textGrey,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasSelection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selectedPortIds.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: hasSelection ? AppColors.green : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionHeader(IconData icon, String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: AppColors.yellow.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Row(
    children: [
      Icon(icon, size: 14, color: AppColors.textDark),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          letterSpacing: 0.8,
        ),
      ),
    ],
  ),
);

Widget _lbl(String text) => Text(
  text,
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    color: AppColors.textDark,
  ),
);

// ── Shared tile / badge / dot / empty ────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onEdit; // null = disabled (deleted user)
  final VoidCallback onDelete;
  final VoidCallback? onReassign;
  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    final isDeleted = user.isDeleted;
    return Opacity(
      opacity: isDeleted ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDeleted ? const Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDeleted
              ? Border.all(color: AppColors.red.withValues(alpha: 0.25))
              : null,
          boxShadow: isDeleted
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.person_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Code: ${user.userCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    if (user.contactNumber != null)
                      Text(
                        user.contactNumber!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    if ((user.role == 'Port Manager' ||
                            user.role == 'Driver') &&
                        user.assignedPortName != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            user.assignedPortName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              _StatusBadge(statusId: user.statusId),
              const SizedBox(width: 6),
              if (onReassign != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OutlinedButton.icon(
                    onPressed: onReassign,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text(
                      'Reassign',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(
                        color: Color(0xFF1565C0),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              _RoleBadge(role: user.role),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: onEdit != null ? AppColors.green : AppColors.textGrey,
                tooltip: onEdit != null ? 'Edit' : 'Cannot edit deleted user',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.red,
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final int? count;
  const _RoleBadge({required this.role, this.count});
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        count != null ? '$role ($count)' : role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RoleDot extends StatelessWidget {
  final String role;
  const _RoleDot({required this.role});
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: _roleColor(role), shape: BoxShape.circle),
  );
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasSearch ? Icons.search_off_rounded : Icons.group_off_rounded,
          size: 64,
          color: AppColors.yellow.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          hasSearch ? 'No users match your search' : 'No users yet',
          style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
        ),
      ],
    ),
  );
}

// ── Status widgets ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final int statusId;
  const _StatusBadge({required this.statusId});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (statusId) {
      case userStatusActive:
        color = AppColors.green;
        label = 'Active';
        break;
      case userStatusInactive:
        color = const Color(0xFFE65100);
        label = 'Inactive';
        break;
      case userStatusDeleted:
        color = AppColors.red;
        label = 'Deleted';
        break;
      default:
        color = AppColors.textGrey;
        label = 'Unknown';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final int statusId;
  final bool selected;
  final VoidCallback onTap;
  const _StatusOption({
    required this.label,
    required this.statusId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (statusId) {
      case userStatusActive:
        color = AppColors.green;
        break;
      case userStatusInactive:
        color = const Color(0xFFE65100);
        break;
      default:
        color = AppColors.red;
    }
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'Admin':
      return AppColors.green;
    case 'Port Manager':
      return const Color(0xFF1565C0);
    default:
      return const Color(0xFFE65100);
  }
}
