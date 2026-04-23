import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_selection_dialog.dart';
import 'user_management_screen.dart';
import 'landing_screen.dart';
import 'port_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Session session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();

  int _totalContainers = 0;
  int _laden = 0;
  int _empty = 0;
  int _activePorts = 0;
  bool _loading = true;
  List<ContainerModel> _inYardContainers = [];
  List<Port> _ports = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final ports = await _api.getPorts();
      List<ContainerModel> allContainers = [];
      for (final port in ports) {
        final containers = await _api.getContainersByPort(port.portId);
        allContainers.addAll(containers);
      }
      final inYard = allContainers.where((c) => !c.isMovedOut).toList();
      setState(() {
        _totalContainers = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _activePorts = ports.length;
        _inYardContainers = inYard;
        _ports = ports;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showContainerList(String filter) {
    List<ContainerModel> filtered;
    String title;
    Color accent;

    switch (filter) {
      case 'laden':
        filtered = _inYardContainers.where((c) => c.statusId == 1).toList();
        title = 'Laden Containers';
        accent = AppColors.yellow;
        break;
      case 'empty':
        filtered = _inYardContainers.where((c) => c.statusId == 2).toList();
        title = 'Empty Containers';
        accent = AppColors.red;
        break;
      default:
        filtered = _inYardContainers;
        title = 'All Containers';
        accent = AppColors.green;
    }

    showDialog(
      context: context,
      builder: (_) => _ContainerListDialog(
        title: title,
        containers: filtered,
        accent: accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroHeader(session: widget.session, onRefresh: _loadStats),
                    _buildStatsSection(),
                    _QuickActionsSection(
                      context: context,
                      session: widget.session,
                      containers: _inYardContainers,
                      ports: _ports,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _FooterStrip(),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OVERVIEW',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                      color: AppColors.yellow,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatCard(
                        label: 'Total\nContainers',
                        value: '$_totalContainers',
                        icon: Icons.inventory_2_rounded,
                        accent: AppColors.green,
                        onTap: () => _showContainerList('all'),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Laden',
                        value: '$_laden',
                        icon: Icons.check_circle_rounded,
                        accent: AppColors.yellow,
                        accentText: AppColors.textDark,
                        onTap: () => _showContainerList('laden'),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Empty',
                        value: '$_empty',
                        icon: Icons.radio_button_unchecked_rounded,
                        accent: AppColors.red,
                        onTap: () => _showContainerList('empty'),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Active\nPorts',
                        value: '$_activePorts',
                        icon: Icons.location_on_rounded,
                        accent: AppColors.green,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final Session session;
  final VoidCallback onRefresh;
  const _HeroHeader({required this.session, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: AppColors.yellow),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/gothong_logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'CONTAINER MANAGEMENT SYSTEM',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              // Welcome text
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Welcome, ${session.fullName}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    session.role,
                    style: TextStyle(
                      color: AppColors.green.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              // Refresh button
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: AppColors.yellow,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Users button — Admin only
              if (session.isAdmin) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_accounts,
                          color: AppColors.yellow,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Users',
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Logout button
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (_) => false,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: AppColors.yellow, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color accentText;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.accentText = AppColors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onTap != null
                  ? accent.withValues(alpha: 0.5)
                  : accent.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentText, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: accent.withValues(alpha: 0.6),
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

// ── Container List Dialog ─────────────────────────────────────────────────────

class _ContainerListDialog extends StatelessWidget {
  final String title;
  final List<ContainerModel> containers;
  final Color accent;

  const _ContainerListDialog({
    required this.title,
    required this.containers,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: accent == AppColors.yellow
                    ? AppColors.yellow
                    : const Color(0xFF1E1E2E),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: accent == AppColors.yellow
                            ? AppColors.textDark
                            : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${containers.length}',
                      style: TextStyle(
                        color: accent == AppColors.yellow
                            ? AppColors.textDark
                            : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: accent == AppColors.yellow
                          ? AppColors.textDark
                          : Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // List
            Flexible(
              child: containers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No containers found.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      itemCount: containers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = containers[i];
                        final isLaden = c.statusId == 1;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isLaden
                                  ? Colors.amber.shade400
                                  : Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            c.containerNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            isLaden ? 'Laden' : 'Empty',
                            style: TextStyle(
                              fontSize: 11,
                              color: isLaden
                                  ? Colors.amber.shade700
                                  : Colors.red.shade600,
                            ),
                          ),
                          trailing: Text(
                            c.containerSizeId == 1
                                ? '20ft'
                                : c.containerSizeId == 2
                                ? '40ft'
                                : (c.type ?? '-'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final BuildContext context;
  final Session session;
  final List<ContainerModel> containers;
  final List<Port> ports;
  const _QuickActionsSection({
    required this.context,
    required this.session,
    required this.containers,
    required this.ports,
  });

  void _openPortManagement(BuildContext ctx) {
    if (session.isChecker && session.portId != null) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => PortManagementScreen(
            portId: session.portId!,
            portName: session.portDesc ?? 'Port ${session.portId}',
            session: session,
          ),
        ),
      );
    } else {
      showDialog(
        context: ctx,
        builder: (_) => PortSelectionDialog(session: session),
      );
    }
  }

  void _generateReport(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _ReportDialog(containers: containers, ports: ports),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_city_rounded,
                  label: 'Manage Container\nLocation',
                  color: AppColors.green,
                  onTap: () => _openPortManagement(ctx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.summarize_rounded,
                  label: 'Generate\nReport',
                  color: AppColors.red,
                  onTap: () => _generateReport(ctx),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Report Dialog ─────────────────────────────────────────────────────────────

class _ReportDialog extends StatefulWidget {
  final List<ContainerModel> containers;
  final List<Port> ports;
  const _ReportDialog({required this.containers, required this.ports});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _fmt(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _days(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
      return '$d day${d != 1 ? "s" : ""}';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _printReport(BuildContext context) async {
    final all = widget.containers;
    final laden = all.where((c) => c.statusId == 1).toList();
    final empty = all.where((c) => c.statusId == 2).toList();
    final pdf = pw.Document();

    final dateStr =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    pw.Widget summaryBox(String label, String value, PdfColor color) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  label,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );

    pw.Widget pageHeader() => pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(color: PdfColors.grey900),
      child: pw.Column(
        children: [
          pw.Text(
            'GOTHONG SOUTHERN — CONTAINER REPORT',
            style: pw.TextStyle(
              color: PdfColors.amber,
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Date Generated: $dateStr',
            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              summaryBox('Total', '${all.length}', PdfColors.green800),
              pw.SizedBox(width: 6),
              summaryBox('Laden', '${laden.length}', PdfColors.amber700),
              pw.SizedBox(width: 6),
              summaryBox('Empty', '${empty.length}', PdfColors.red700),
              pw.SizedBox(width: 6),
              summaryBox(
                'Ports',
                '${widget.ports.length}',
                PdfColors.blueGrey700,
              ),
            ],
          ),
        ],
      ),
    );

    pw.Widget tableHeader(List<String> cols) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: PdfColors.grey800,
      child: pw.Row(
        children: cols
            .map(
              (c) => pw.Expanded(
                child: pw.Text(
                  c,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    pw.Widget containerRow(int i, ContainerModel c) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      color: i.isEven ? PdfColors.grey100 : PdfColors.white,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              c.containerNumber,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.statusId == 1 ? 'Laden' : 'Empty',
              style: pw.TextStyle(
                fontSize: 9,
                color: c.statusId == 1 ? PdfColors.amber800 : PdfColors.red700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.containerSizeId == 1
                  ? '20ft'
                  : c.containerSizeId == 2
                  ? '40ft'
                  : '-',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.moveConfirmedDate),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.moveConfirmedDate),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );

    final containerCols = [
      'CONTAINER NO.',
      'STATUS',
      'SIZE',
      'DATE IN YARD',
      'DAYS IN YARD',
      'DATE MOVED',
      'DAYS IN SLOT',
    ];

    // Page 1: All
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pageHeader(),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'ALL CONTAINERS (${all.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          tableHeader(containerCols),
          ...all.asMap().entries.map((e) => containerRow(e.key, e.value)),
        ],
      ),
    );

    // Page 2: Laden
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pageHeader(),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'LADEN CONTAINERS (${laden.length})',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfColors.amber800,
            ),
          ),
          pw.SizedBox(height: 6),
          tableHeader(containerCols),
          ...laden.asMap().entries.map((e) => containerRow(e.key, e.value)),
        ],
      ),
    );

    // Page 3: Empty
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pageHeader(),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'EMPTY CONTAINERS (${empty.length})',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfColors.red700,
            ),
          ),
          pw.SizedBox(height: 6),
          tableHeader(containerCols),
          ...empty.asMap().entries.map((e) => containerRow(e.key, e.value)),
        ],
      ),
    );

    // Page 4: Ports
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pageHeader(),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'PORTS SUMMARY (${widget.ports.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          tableHeader(['PORT NAME', 'TOTAL', 'LADEN', 'EMPTY', '20FT', '40FT']),
          ...widget.ports.asMap().entries.map((e) {
            final i = e.key;
            final port = e.value;
            final pc = all
                .where((c) => c.currentPortId == port.portId)
                .toList();
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 8,
              ),
              color: i.isEven ? PdfColors.grey100 : PdfColors.white,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      port.portDesc,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.length}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 1).length}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.amber800,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 2).length}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.red700),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 1).length}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 2).length}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Container_Report_$dateStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.containers;
    final laden = all.where((c) => c.statusId == 1).toList();
    final empty = all.where((c) => c.statusId == 2).toList();
    final reportDate =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.summarize_rounded,
                        color: AppColors.yellow,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GOTHONG SOUTHERN — CONTAINER REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Date Generated: $reportDate',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _printReport(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.print_rounded,
                                color: AppColors.textDark,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Print',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Summary strip
                  Row(
                    children: [
                      _SummaryTile(
                        label: 'Total Containers',
                        value: '${all.length}',
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        label: 'Laden',
                        value: '${laden.length}',
                        color: Colors.amber.shade600,
                        textColor: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        label: 'Empty',
                        value: '${empty.length}',
                        color: AppColors.red,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        label: 'Total Ports',
                        value: '${widget.ports.length}',
                        color: Colors.blueGrey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tab,
                    indicatorColor: AppColors.yellow,
                    labelColor: AppColors.yellow,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(text: 'ALL'),
                      Tab(text: 'LADEN'),
                      Tab(text: 'EMPTY'),
                      Tab(text: 'PORTS'),
                    ],
                  ),
                ],
              ),
            ),
            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ContainerTable(containers: all, fmt: _fmt, days: _days),
                  _ContainerTable(containers: laden, fmt: _fmt, days: _days),
                  _ContainerTable(containers: empty, fmt: _fmt, days: _days),
                  _PortsTable(ports: widget.ports, containers: all),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContainerTable extends StatelessWidget {
  final List<ContainerModel> containers;
  final String Function(String?) fmt;
  final String Function(String?) days;
  const _ContainerTable({
    required this.containers,
    required this.fmt,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No data available.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Count label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${containers.length} record${containers.length != 1 ? "s" : ""} found',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Table
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
              borderRadius: BorderRadius.circular(6),
            ),
            columnWidths: const {
              0: FixedColumnWidth(36), // #
              1: FlexColumnWidth(2.5), // Container No.
              2: FlexColumnWidth(1.2), // Status
              3: FlexColumnWidth(0.8), // Size
              4: FlexColumnWidth(1.8), // Date in Yard
              5: FlexColumnWidth(1.4), // Days in Yard
              6: FlexColumnWidth(1.8), // Date Moved
              7: FlexColumnWidth(1.4), // Days in Slot
            },
            children: [
              // Header
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1E1E2E)),
                children: [
                  _th('#'),
                  _th('CONTAINER NO.'),
                  _th('STATUS'),
                  _th('SIZE'),
                  _th('DATE IN YARD'),
                  _th('DAYS IN YARD'),
                  _th('DATE MOVED'),
                  _th('DAYS IN SLOT'),
                ],
              ),
              // Data rows
              ...containers.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final isLaden = c.statusId == 1;
                final bg = i.isEven ? Colors.white : const Color(0xFFF8F9FA);
                return TableRow(
                  decoration: BoxDecoration(color: bg),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    _td(
                      c.containerNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _tdStatus(isLaden),
                    _td(
                      c.containerSizeId == 1
                          ? '20ft'
                          : c.containerSizeId == 2
                          ? '40ft'
                          : '-',
                      center: true,
                    ),
                    _td(fmt(c.yardEntryDate)),
                    _td(days(c.yardEntryDate), center: true),
                    _td(fmt(c.moveConfirmedDate)),
                    _td(days(c.moveConfirmedDate), center: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _th(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 0.4,
      ),
    ),
  );

  static Widget _td(String text, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style:
              style ?? const TextStyle(fontSize: 12, color: AppColors.textDark),
        ),
      );

  static Widget _tdStatus(bool isLaden) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    child: Text(
      isLaden ? 'Laden' : 'Empty',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isLaden ? Colors.amber.shade800 : Colors.red.shade700,
      ),
    ),
  );
}

class _PortsTable extends StatelessWidget {
  final List<Port> ports;
  final List<ContainerModel> containers;
  const _PortsTable({required this.ports, required this.containers});

  @override
  Widget build(BuildContext context) {
    if (ports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No data available.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ),
      );
    }

    // Compute totals for footer
    int grandTotal = 0,
        grandLaden = 0,
        grandEmpty = 0,
        grand20 = 0,
        grand40 = 0;
    final portData = ports.map((port) {
      final pc = containers
          .where((c) => c.currentPortId == port.portId)
          .toList();
      final laden = pc.where((c) => c.statusId == 1).length;
      final empty = pc.where((c) => c.statusId == 2).length;
      final ft20 = pc.where((c) => c.containerSizeId == 1).length;
      final ft40 = pc.where((c) => c.containerSizeId == 2).length;
      grandTotal += pc.length;
      grandLaden += laden;
      grandEmpty += empty;
      grand20 += ft20;
      grand40 += ft40;
      return (
        port: port,
        total: pc.length,
        laden: laden,
        empty: empty,
        ft20: ft20,
        ft40: ft40,
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${ports.length} port${ports.length != 1 ? "s" : ""} active',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
              borderRadius: BorderRadius.circular(6),
            ),
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.2),
              6: FlexColumnWidth(1.2),
            },
            children: [
              // Header
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1E1E2E)),
                children: [
                  _th('#'),
                  _th('PORT NAME'),
                  _th('TOTAL'),
                  _th('LADEN'),
                  _th('EMPTY'),
                  _th('20FT'),
                  _th('40FT'),
                ],
              ),
              // Data rows
              ...portData.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                final bg = i.isEven ? Colors.white : const Color(0xFFF8F9FA);
                return TableRow(
                  decoration: BoxDecoration(color: bg),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    _td(
                      d.port.portDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _td(
                      '${d.total}',
                      center: true,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _td(
                      '${d.laden}',
                      center: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    _td(
                      '${d.empty}',
                      center: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                    _td('${d.ft20}', center: true),
                    _td('${d.ft40}', center: true),
                  ],
                );
              }),
              // Totals footer
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF0F4F8)),
                children: [
                  _td('', center: true),
                  _td(
                    'TOTAL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  _td(
                    '$grandTotal',
                    center: true,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$grandLaden',
                    center: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  _td(
                    '$grandEmpty',
                    center: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade700,
                    ),
                  ),
                  _td(
                    '$grand20',
                    center: true,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$grand40',
                    center: true,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _th(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 0.4,
      ),
    ),
  );

  static Widget _td(String text, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style:
              style ?? const TextStyle(fontSize: 12, color: AppColors.textDark),
        ),
      );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _FooterStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: const BoxDecoration(color: AppColors.yellow),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, color: AppColors.green, size: 18),
          SizedBox(width: 8),
          Text(
            'Gothong Southern  ·  Container Management System',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
