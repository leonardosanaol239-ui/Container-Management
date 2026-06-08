import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/port_selection_dialog.dart';
import '../widgets/notification_panel.dart';
import 'landing_screen.dart';
import 'account_screen.dart';

// -- Design tokens -------------------------------------------------------------
// Gothong Southern Brand Colors
// PRIMARY:  Lincoln Green #0B560D | Scarlet Red #FF2800 | Canary Yellow #FFF200
// SECONDARY: Live Green #98F29B   | Smiley Red #E0474C  | Cyber Yellow #FFD300
class _C {
  // Backgrounds & surfaces
  static const bg = Color(0xFFF0F2EE);
  static const surface = Color(0xFFFFFFFF);

  // Navigation (dark green tones derived from Lincoln Green)
  static const navBg = Color(0xFF0B3D0F);
  static const navBg2 = Color(0xFF0D4A12);

  // PRIMARY palette
  static const lincolnGreen = Color(0xFF0B560D); // Pantone Lincoln Green
  static const scarletRed = Color(0xFFFF2800); // Pantone Scarlet Red
  static const canaryYellow = Color(0xFFFFF200); // Pantone Canary Yellow

  // SECONDARY palette
  static const liveGreen = Color(0xFF98F29B); // Pantone Live Green
  static const smileRed = Color(0xFFE0474C); // Pantone Smiley Red
  static const cyberYellow = Color(0xFFFFD300); // Pantone Cyber Yellow

  // Aliases kept for backward compatibility
  static const emerald = lincolnGreen;
  static const emeraldL = liveGreen;
  static const gold = cyberYellow;
  static const goldD = Color(0xFFCCA900);
  static const red = scarletRed;

  // Accent / semantic
  static const blue = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const purple = Color(0xFF6A1B9A);
  static const teal = Color(0xFF00695C);

  // Text
  static const textD = Color(0xFF1A1A0A);
  static const textM = Color(0xFF4A4A4A);
  static const textL = Color(0xFF757575);

  // Utility
  static const border = Color(0xFFE8EAE4);
  static const shadow = Color(0x0A000000);
}

// -- DashboardScreen -----------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  final Session session;
  const DashboardScreen({super.key, required this.session});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  int _total = 0, _laden = 0, _empty = 0, _ports = 0;
  int _mtFood = 0, _fsl = 0, _stripping = 0, _mtNonFood = 0;
  int _inTransit = 0, _movedOut = 0;
  // New dashboard widgets data
  int _inboundCount = 0, _outboundCount = 0;
  int _emptyFoodGrade = 0,
      _emptyNonFoodGrade = 0,
      _emptyRepairable = 0,
      _emptyFrmd = 0;
  int _ladenTotal = 0, _tempoGrounding = 0;
  int _yardIn = 0, _yardOut = 0;
  // -- Dashboard search & filter state -----------------------------------------
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterPort = 'All'; // 'All' or specific portDesc
  String _filterStatus = 'All'; // 'All' | 'Laden' | 'Empty' | 'In Transit'
  List<Port> _portList = [];
  bool _loading = true;
  List<ContainerModel> _inYard = [];
  List<ContainerModel> _allContainers =
      []; // ALL containers including moved-out
  int _navIndex = 0;
  bool _collapsed = false;
  late AnimationController _statsAnim;
  late AnimationController _pulseAnim;
  Timer? _clock;
  Timer? _pollTimer;
  DateTime _now = DateTime.now();

  static const _nav = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.anchor_rounded, 'label': 'Ports'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
    {'icon': Icons.summarize_rounded, 'label': 'Reports'},
    {'icon': Icons.notifications_rounded, 'label': 'Notifications'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    NotificationService().setSession(widget.session.fullName);
    _statsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadStats();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Auto-refresh every 5 s — keeps dashboard in sync with movements
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _statsAnim.dispose();
    _pulseAnim.dispose();
    _searchCtrl.dispose();
    _clock?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final portList = await _api.getPorts();
      List<ContainerModel> all = [];
      for (final p in portList) {
        all.addAll(await _api.getContainersByPort(p.portId));
      }
      final inYard = all.where((c) => !c.isMovedOut).toList();
      setState(() {
        _total = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _ports = portList.length;
        _mtFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).length;
        _fsl = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —') || d.startsWith('fsl -');
        }).length;
        _stripping = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).length;
        _mtNonFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).length;
        _inTransit = inYard.where((c) => c.locationStatusId == 3).length;
        _movedOut = all.where((c) => c.isMovedOut).length;
        _inYard = inYard;
        _portList = portList;
        _allContainers = all;
        _loading = false;
        // -- New widget data -----------------------------------
        // Inbound = containers that have a yardEntryDate (entered a yard)
        _inboundCount = all.where((c) => c.yardEntryDate != null).length;
        // Outbound = containers moved out
        _outboundCount = all.where((c) => c.isMovedOut).length;
        // Empty containers by type
        final emptyContainers = inYard.where((c) => c.statusId == 2);
        _emptyFoodGrade = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('food') && !d.contains('non');
        }).length;
        _emptyNonFoodGrade = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('non') && d.contains('food');
        }).length;
        _emptyRepairable = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('repair');
        }).length;
        _emptyFrmd = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('frmd') || d.contains('frmdd');
        }).length;
        // Laden including tempo grounding
        _ladenTotal = inYard.where((c) => c.statusId == 1).length;
        _tempoGrounding = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return c.statusId == 1 &&
              (d.contains('tempo') || d.contains('grounding'));
        }).length;
        // Yard In / Yard Out
        _yardIn = inYard.where((c) => c.yardId != null).length;
        _yardOut = all.where((c) => c.isMovedOut).length;
      });
      _statsAnim.forward(from: 0);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Silent refresh — updates data without showing the loading spinner.
  // Called every 5 s by the poll timer so movements reflect in real-time.
  Future<void> _silentRefresh() async {
    try {
      final portList = await _api.getPorts();
      List<ContainerModel> all = [];
      for (final p in portList) {
        all.addAll(await _api.getContainersByPort(p.portId));
      }
      final inYard = all.where((c) => !c.isMovedOut).toList();
      if (!mounted) return;
      setState(() {
        _total = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _ports = portList.length;
        _mtFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).length;
        _fsl = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —') || d.startsWith('fsl -');
        }).length;
        _stripping = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).length;
        _mtNonFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).length;
        _inTransit = inYard.where((c) => c.locationStatusId == 3).length;
        _movedOut = all.where((c) => c.isMovedOut).length;
        _inYard = inYard;
        _portList = portList;
        _allContainers = all;
        // -- New widget data -----------------------------------
        _inboundCount = all.where((c) => c.yardEntryDate != null).length;
        _outboundCount = all.where((c) => c.isMovedOut).length;
        final emptyC = inYard.where((c) => c.statusId == 2);
        _emptyFoodGrade = emptyC.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('food') && !d.contains('non');
        }).length;
        _emptyNonFoodGrade = emptyC.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('non') && d.contains('food');
        }).length;
        _emptyRepairable = emptyC.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('repair');
        }).length;
        _emptyFrmd = emptyC.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('frmd');
        }).length;
        _ladenTotal = inYard.where((c) => c.statusId == 1).length;
        _tempoGrounding = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return c.statusId == 1 &&
              (d.contains('tempo') || d.contains('grounding'));
        }).length;
        _yardIn = inYard.where((c) => c.yardId != null).length;
        _yardOut = all.where((c) => c.isMovedOut).length;
      });
    } catch (_) {
      // Silently ignore network errors during background refresh
    }
  }

  // -- Filtered containers (search + port + status) -------------------------
  // Filters _allContainers (all ports, including moved-out) so port filter
  // shows the actual real data from that port — not just in-yard subset.
  List<ContainerModel> get _filteredContainers {
    // Start from all containers when port filter is active,
    // otherwise use in-yard only (default view)
    var list = _filterPort != 'All' ? _allContainers : _inYard;

    // Port filter — match by currentPortId
    if (_filterPort != 'All') {
      final port = _portList.firstWhere(
        (p) => p.portDesc == _filterPort,
        orElse: () => _portList.first,
      );
      list = list.where((c) => c.currentPortId == port.portId).toList();
    }

    // Status filter
    if (_filterStatus == 'Laden') {
      list = list.where((c) => c.statusId == 1).toList();
    }
    if (_filterStatus == 'Empty') {
      list = list.where((c) => c.statusId == 2).toList();
    }
    if (_filterStatus == 'In Transit') {
      list = list.where((c) => c.locationStatusId == 3).toList();
    }
    if (_filterStatus == 'Moved Out') {
      list = list.where((c) => c.isMovedOut).toList();
    }

    // Search — container number or description
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.containerNumber.toLowerCase().contains(q) ||
                (c.containerDesc?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  // -- Port-filtered stats (updates KPI cards when port filter is active) ----
  List<ContainerModel> get _portBaseList {
    if (_filterPort == 'All') return _inYard;
    final port = _portList.firstWhere(
      (p) => p.portDesc == _filterPort,
      orElse: () => _portList.first,
    );
    return _allContainers.where((c) => c.currentPortId == port.portId).toList();
  }

  // -- Customer transaction summary -----------------------------------------
  Map<int, int> get _containersByCustomer {
    final map = <int, int>{};
    for (final c in _inYard) {
      if (c.customerId != null) {
        map[c.customerId!] = (map[c.customerId!] ?? 0) + 1;
      }
    }
    return map;
  }

  String get _timeStr {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s ${_now.hour < 12 ? "AM" : "PM"}';
  }

  String get _dateStr {
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const dy = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${dy[_now.weekday - 1]}, ${mo[_now.month - 1]} ${_now.day}, ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(
            items: _nav,
            activeIndex: _navIndex,
            collapsed: _collapsed,
            onSelect: (i) {
              setState(() => _navIndex = i);
            },
            onToggle: () => setState(() => _collapsed = !_collapsed),
            onLogout: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LandingScreen()),
              (_) => false,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopNav(
                  session: widget.session,
                  timeStr: _timeStr,
                  dateStr: _dateStr,
                  pulseAnim: _pulseAnim,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Switch between different pages based on nav index
    switch (_navIndex) {
      case 0: // Dashboard
        return _buildDashboardPage();
      case 1: // Ports
        return _buildPortsPage();
      case 2: // Analytics
        return _buildAnalyticsPage();
      case 3: // Reports
        return _buildReportsPage();
      case 4: // Notifications
        return _buildNotificationsPage();
      case 5: // Settings
        return _buildSettingsPage();
      default:
        return _buildDashboardPage();
    }
  }

  Widget _buildDashboardPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final isTablet = constraints.maxWidth < 1000 && !isMobile;

        // -- Compute all dashboard data from the port-filtered base ----------
        final base = _portBaseList; // in-yard or port-scoped
        final baseAll = _filterPort == 'All'
            ? _allContainers
            : _allContainers.where((c) {
                final port = _portList.firstWhere(
                  (p) => p.portDesc == _filterPort,
                  orElse: () => _portList.first,
                );
                return c.currentPortId == port.portId;
              }).toList();

        // Container Flow — Inbound / Outbound
        final inbound = baseAll.where((c) => c.yardEntryDate != null).length;
        final outbound = baseAll.where((c) => c.isMovedOut).length;

        // -- Real daily data for charts (last 7 days: index 0=oldest, 6=today) --
        final now = DateTime.now();
        final inboundByDay = List<int>.filled(7, 0);
        final outboundByDay = List<int>.filled(7, 0);
        final ladenByDay = List<int>.filled(7, 0);
        for (final c in baseAll) {
          // Inbound — grouped by yardEntryDate
          if (c.yardEntryDate != null) {
            try {
              final d = DateTime.parse(c.yardEntryDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 0 && diff < 7) inboundByDay[6 - diff]++;
            } catch (_) {}
          }
          // Outbound — grouped by moveConfirmedDate
          if (c.isMovedOut && c.moveConfirmedDate != null) {
            try {
              final d = DateTime.parse(c.moveConfirmedDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 0 && diff < 7) outboundByDay[6 - diff]++;
            } catch (_) {}
          }
          // Laden — grouped by yardEntryDate, statusId==1
          if (c.statusId == 1 && c.yardEntryDate != null) {
            try {
              final d = DateTime.parse(c.yardEntryDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 0 && diff < 7) ladenByDay[6 - diff]++;
            } catch (_) {}
          }
        }
        // Day labels: "May 11", "May 12"... for last 7 days
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final dayLabels = List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return '${months[d.month - 1]} ${d.day}';
        });

        // -- Trend vs prior 7 days --------------------------------
        final inboundPrior = List<int>.filled(7, 0);
        final outboundPrior = List<int>.filled(7, 0);
        final ladenPrior = List<int>.filled(7, 0);
        for (final c in baseAll) {
          if (c.yardEntryDate != null) {
            try {
              final d = DateTime.parse(c.yardEntryDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 7 && diff < 14) inboundPrior[13 - diff]++;
            } catch (_) {}
          }
          if (c.isMovedOut && c.moveConfirmedDate != null) {
            try {
              final d = DateTime.parse(c.moveConfirmedDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 7 && diff < 14) outboundPrior[13 - diff]++;
            } catch (_) {}
          }
          if (c.statusId == 1 && c.yardEntryDate != null) {
            try {
              final d = DateTime.parse(c.yardEntryDate!);
              final diff = now.difference(d).inDays;
              if (diff >= 7 && diff < 14) ladenPrior[13 - diff]++;
            } catch (_) {}
          }
        }
        String trendPct(List<int> cur, List<int> prior) {
          final cSum = cur.fold(0, (a, b) => a + b);
          final pSum = prior.fold(0, (a, b) => a + b);
          if (pSum == 0) return cSum > 0 ? '+100%' : '0%';
          final pct = ((cSum - pSum) / pSum * 100).round();
          return pct >= 0 ? '+$pct%' : '$pct%';
        }

        final inboundTrend = trendPct(inboundByDay, inboundPrior);
        final outboundTrend = trendPct(outboundByDay, outboundPrior);
        final ladenTrend = trendPct(ladenByDay, ladenPrior);
        final inboundTrendUp = !inboundTrend.startsWith('-');
        final outboundTrendUp = !outboundTrend.startsWith('-');
        final ladenTrendUp = !ladenTrend.startsWith('-');

        // Empty breakdown
        final emptyContainers = base.where((c) => c.statusId == 2);
        final emptyFoodGrade = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('food') && !d.contains('non');
        }).length;
        final emptyNonFoodGrade = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('non') && d.contains('food');
        }).length;
        final emptyRepairable = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('repair');
        }).length;
        final emptyFrmd = emptyContainers.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d.contains('frmd');
        }).length;
        final emptyTotal = base.where((c) => c.statusId == 2).length;

        // Laden breakdown
        final ladenTotal = base.where((c) => c.statusId == 1).length;
        final tempoGrounding = base.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return c.statusId == 1 &&
              (d.contains('tempo') || d.contains('grounding'));
        }).length;

        // Yard In / Out
        final yardIn = base.where((c) => c.yardId != null).length;
        final yardOut = baseAll.where((c) => c.isMovedOut).length;

        // Customer transactions — scoped to port
        final customerMap = <int, int>{};
        for (final c in base) {
          if (c.customerId != null) {
            customerMap[c.customerId!] = (customerMap[c.customerId!] ?? 0) + 1;
          }
        }

        // Port leaderboard — scoped to port
        final portContainers = _filterPort == 'All' ? _inYard : base;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Search & Filter bar ------------------------------
              _DashboardFilterBar(
                searchCtrl: _searchCtrl,
                searchQuery: _searchQuery,
                filterPort: _filterPort,
                filterStatus: _filterStatus,
                portList: _portList,
                resultCount: _filteredContainers.length,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onPortChanged: (v) => setState(() => _filterPort = v),
                onStatusChanged: (v) => setState(() => _filterStatus = v),
                onClear: () => setState(() {
                  _searchQuery = '';
                  _filterPort = 'All';
                  _filterStatus = 'All';
                  _searchCtrl.clear();
                }),
              ),
              const SizedBox(height: 24),

              _SectionHeader(
                title: 'OVERVIEW',
                icon: Icons.analytics_rounded,
                color: _C.emerald,
              ),
              const SizedBox(height: 14),
              _loading ? _SkeletonRow(isMobile ? 2 : 5) : _buildStatCards(),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'CONTAINER FLOW',
                icon: Icons.swap_horiz_rounded,
                color: _C.teal,
              ),
              const SizedBox(height: 14),
              if (!_loading) ...[
                // -- Row 1: Inbound | Outbound | Empty Breakdown | Laden --
                isMobile
                    ? Column(
                        children: [
                          _CF_InboundCard(allContainers: baseAll),
                          const SizedBox(height: 12),
                          _CF_OutboundCard(allContainers: baseAll),
                          const SizedBox(height: 12),
                          _CF_EmptyDonutCard(
                            foodGrade: emptyFoodGrade,
                            nonFoodGrade: emptyNonFoodGrade,
                            repairable: emptyRepairable,
                            frmd: emptyFrmd,
                            total: emptyTotal,
                            allEmpty: base
                                .where((c) => c.statusId == 2)
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          _CF_LadenSparkCard(
                            allContainers: base,
                            tempoGrounding: tempoGrounding,
                          ),
                        ],
                      )
                    : isTablet
                    ? Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_InboundCard(allContainers: baseAll),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_OutboundCard(allContainers: baseAll),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_EmptyDonutCard(
                              foodGrade: emptyFoodGrade,
                              nonFoodGrade: emptyNonFoodGrade,
                              repairable: emptyRepairable,
                              frmd: emptyFrmd,
                              total: emptyTotal,
                              allEmpty: base
                                  .where((c) => c.statusId == 2)
                                  .toList(),
                            ),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_LadenSparkCard(
                              allContainers: base,
                              tempoGrounding: tempoGrounding,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CF_InboundCard(allContainers: baseAll),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _CF_OutboundCard(allContainers: baseAll),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _CF_EmptyDonutCard(
                              foodGrade: emptyFoodGrade,
                              nonFoodGrade: emptyNonFoodGrade,
                              repairable: emptyRepairable,
                              frmd: emptyFrmd,
                              total: emptyTotal,
                              allEmpty: base
                                  .where((c) => c.statusId == 2)
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _CF_LadenSparkCard(
                              allContainers: base,
                              tempoGrounding: tempoGrounding,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 14),
                // -- Row 2: Total In Yard | Status Overview | Containers per Port --
                isMobile
                    ? Column(
                        children: [
                          _CF_YardInOutCard(
                            allInYard: base
                                .where((c) => c.yardId != null)
                                .toList(),
                            allOutYard: baseAll
                                .where((c) => c.isMovedOut)
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          _CF_StatusOverviewCard(
                            inYard: base.where((c) => !c.isMovedOut).length,
                            laden: ladenTotal,
                            empty: emptyTotal,
                            allContainers: base,
                          ),
                          const SizedBox(height: 12),
                          _CF_ContainersPerPortCard(
                            portList: _portList,
                            containers: portContainers,
                            allContainers: baseAll,
                            onTapPort: (port, list) => _showContainerList(
                              context,
                              '${port.portDesc} Containers',
                              list,
                              _C.blue,
                            ),
                          ),
                        ],
                      )
                    : isTablet
                    ? Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_YardInOutCard(
                              allInYard: base
                                  .where((c) => c.yardId != null)
                                  .toList(),
                              allOutYard: baseAll
                                  .where((c) => c.isMovedOut)
                                  .toList(),
                            ),
                          ),
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _CF_StatusOverviewCard(
                              inYard: base.where((c) => !c.isMovedOut).length,
                              laden: ladenTotal,
                              empty: emptyTotal,
                              allContainers: base,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _CF_ContainersPerPortCard(
                              portList: _portList,
                              containers: portContainers,
                              allContainers: baseAll,
                              onTapPort: (port, list) => _showContainerList(
                                context,
                                '${port.portDesc} Containers',
                                list,
                                _C.blue,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _CF_YardInOutCard(
                              allInYard: base
                                  .where((c) => c.yardId != null)
                                  .toList(),
                              allOutYard: baseAll
                                  .where((c) => c.isMovedOut)
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _CF_StatusOverviewCard(
                              inYard: base.where((c) => !c.isMovedOut).length,
                              laden: ladenTotal,
                              empty: emptyTotal,
                              allContainers: base,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _CF_ContainersPerPortCard(
                              portList: _portList,
                              containers: portContainers,
                              allContainers: baseAll,
                              onTapPort: (port, list) => _showContainerList(
                                context,
                                '${port.portDesc} Containers',
                                list,
                                _C.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
              const SizedBox(height: 24),

              // -- Customer Transactions — port-scoped ---------------
              if (!_loading && customerMap.isNotEmpty) ...[
                _SectionHeader(
                  title: 'CUSTOMER TRANSACTIONS',
                  icon: Icons.people_alt_rounded,
                  color: _C.purple,
                ),
                const SizedBox(height: 14),
                _CustomerSummaryCard(
                  containersByCustomer: customerMap,
                  totalContainers: base.length,
                  allContainers: base,
                  onTapCustomer: (custId, list) => _showContainerList(
                    context,
                    'Customer #$custId Containers',
                    list,
                    _C.purple,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // -- Filtered results ---------------------------------
              if (!_loading &&
                  (_searchQuery.isNotEmpty ||
                      _filterPort != 'All' ||
                      _filterStatus != 'All')) ...[
                _SectionHeader(
                  title: 'FILTERED RESULTS',
                  icon: Icons.filter_list_rounded,
                  color: _C.orange,
                ),
                const SizedBox(height: 14),
                _FilteredContainerList(
                  containers: _filteredContainers,
                  portList: _portList,
                ),
                const SizedBox(height: 24),
              ],

              _SectionHeader(
                title: 'PORT ACTIVITY',
                icon: Icons.anchor_rounded,
                color: _C.blue,
              ),
              const SizedBox(height: 14),
              _PortLeaderboard(
                portList: _portList,
                containers: portContainers,
                allContainers: baseAll,
                onTapPort: (port, list) => _showContainerList(
                  context,
                  '${port.portDesc} Containers',
                  list,
                  _C.blue,
                ),
              ),
              const SizedBox(height: 16),
              _Footer(year: _now.year),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'PORT MANAGEMENT',
            icon: Icons.anchor_rounded,
            color: _C.blue,
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => PortSelectionDialog(session: widget.session),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Manage Ports'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.emerald,
                foregroundColor: _C.gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'ANALYTICS',
            icon: Icons.bar_chart_rounded,
            color: _C.purple,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Analytics page coming soon',
              style: TextStyle(color: _C.textL, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'REPORTS',
            icon: Icons.summarize_rounded,
            color: _C.orange,
          ),
          const SizedBox(height: 24),
          _ReportsPageContent(containers: _inYard, portList: _portList),
        ],
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'NOTIFICATIONS',
            icon: Icons.notifications_rounded,
            color: _C.emerald,
          ),
          const SizedBox(height: 24),
          const _NotificationsPageContent(),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'SETTINGS',
            icon: Icons.settings_rounded,
            color: _C.textM,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Settings page coming soon',
              style: TextStyle(color: _C.textL, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    // Use port-filtered data when a port is selected — real data per port
    final base = _portBaseList;
    final baseAll = _filterPort != 'All'
        ? _allContainers.where((c) {
            final port = _portList.firstWhere(
              (p) => p.portDesc == _filterPort,
              orElse: () => _portList.first,
            );
            return c.currentPortId == port.portId;
          }).toList()
        : _allContainers;

    final total = base.where((c) => !c.isMovedOut).length;
    final laden = base.where((c) => c.statusId == 1 && !c.isMovedOut).length;
    final empty = base.where((c) => c.statusId == 2 && !c.isMovedOut).length;
    final inTransit = base.where((c) => c.locationStatusId == 3).length;
    final movedOut = baseAll.where((c) => c.isMovedOut).length;

    final portLabel = _filterPort == 'All' ? 'In yard' : _filterPort;

    final cards = [
      (
        label: 'Total Containers',
        value: '$total',
        icon: Icons.inventory_2_rounded,
        color: _C.emerald,
        sub: portLabel,
        trend: '+16.0%',
        up: true,
        dark: false,
        filter: 'all',
      ),
      (
        label: 'Laden Containers',
        value: '$laden',
        icon: Icons.check_circle_rounded,
        color: _C.gold,
        sub: 'Loaded',
        trend: '+11.1%',
        up: true,
        dark: true,
        filter: 'laden',
      ),
      (
        label: 'Empty Containers',
        value: '$empty',
        icon: Icons.radio_button_unchecked_rounded,
        color: _C.red,
        sub: 'Available',
        trend: '-6.7%',
        up: false,
        dark: false,
        filter: 'empty',
      ),
      (
        label: 'Pending Deliveries',
        value: '$movedOut',
        icon: Icons.local_shipping_rounded,
        color: _C.orange,
        sub: 'Dispatched',
        trend: '-12.5%',
        up: false,
        dark: false,
        filter: 'out',
      ),
      (
        label: 'Containers In Transit',
        value: '$inTransit',
        icon: Icons.directions_boat_rounded,
        color: _C.blue,
        sub: 'Move requests',
        trend: '+14.3%',
        up: true,
        dark: false,
        filter: 'transit',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final w = constraints.maxWidth;
        // Responsive column count: 5 on wide, 3 on medium, 2 on small
        final n = w >= 900
            ? 5
            : w >= 560
            ? 3
            : 2;
        final cardW = (w - spacing * (n - 1)) / n;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.asMap().entries.map((e) {
            final c = e.value;
            return SizedBox(
              width: cardW,
              child: _StatCard(
                label: c.label,
                value: c.value,
                icon: c.icon,
                color: c.color,
                subtitle: c.sub,
                trend: c.trend,
                trendUp: c.up,
                textDark: c.dark,
                anim: _statsAnim,
                delay: e.key * 0.1,
                onTap: c.filter.isNotEmpty ? () => _showList(c.filter) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showContainerList(
    BuildContext context,
    String title,
    List<ContainerModel> containers,
    Color accent,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          _ListDialog(title: title, containers: containers, accent: accent),
    );
  }

  void _showList(String filter) {
    final base = _portBaseList;
    final filtered = filter == 'laden'
        ? base.where((c) => c.statusId == 1).toList()
        : filter == 'empty'
        ? base.where((c) => c.statusId == 2).toList()
        : filter == 'transit'
        ? base.where((c) => c.locationStatusId == 3).toList()
        : filter == 'out'
        ? _allContainers.where((c) => c.isMovedOut).toList()
        : base;
    final title = filter == 'laden'
        ? 'Laden Containers'
        : filter == 'empty'
        ? 'Empty Containers'
        : filter == 'transit'
        ? 'In Transit Containers'
        : filter == 'out'
        ? 'Moved Out Containers'
        : 'All Containers';
    final accent = filter == 'laden'
        ? _C.gold
        : filter == 'empty'
        ? _C.red
        : filter == 'transit'
        ? _C.orange
        : filter == 'out'
        ? _C.teal
        : _C.emerald;
    _showContainerList(context, title, filtered, accent);
  }
}

// -- Sidebar -------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int activeIndex;
  final bool collapsed;
  final void Function(int) onSelect;
  final VoidCallback onToggle, onLogout;
  const _Sidebar({
    required this.items,
    required this.activeIndex,
    required this.collapsed,
    required this.onSelect,
    required this.onToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      width: collapsed ? 52 : 180,
      decoration: const BoxDecoration(
        color: _C.navBg,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/gothong_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'GOTHONG',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'SOUTHERN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 7,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: List.generate(
                items.length,
                (i) => _NavItem(
                  icon: items[i]['icon'] as IconData,
                  label: items[i]['label'] as String,
                  active: activeIndex == i,
                  collapsed: collapsed,
                  showBadge: i == 4, // Show badge for Notifications (index 4)
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ),
          // Bottom
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  active: false,
                  collapsed: collapsed,
                  color: _C.red,
                  showBadge: false,
                  onTap: onLogout,
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns: collapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white.withOpacity(0.35),
                        size: 18,
                      ),
                    ),
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

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active, collapsed;
  final bool showBadge;
  final Color? color;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.color,
    this.showBadge = false,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _h = false;

  @override
  void initState() {
    super.initState();
    if (widget.showBadge) {
      NotificationService().addListener(_onNotifChanged);
    }
  }

  @override
  void dispose() {
    if (widget.showBadge) {
      NotificationService().removeListener(_onNotifChanged);
    }
    super.dispose();
  }

  void _onNotifChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? (widget.active ? Colors.white : Colors.white);
    final unreadCount = widget.showBadge
        ? NotificationService().unreadCount
        : 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 9,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.active
                ? Colors.white.withValues(alpha: 0.13)
                : _h
                ? Colors.white.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: widget.active
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: widget.collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (widget.active && !widget.collapsed)
                    Container(
                      width: 3,
                      height: 14,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Icon(widget.icon, color: c, size: 15),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: c,
                          fontSize: 11.5,
                          fontWeight: widget.active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Badge indicator
              if (widget.showBadge && unreadCount > 0)
                Positioned(
                  top: widget.collapsed ? -4 : 0,
                  right: widget.collapsed ? -4 : 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: _C.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.navBg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _C.red.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
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

// -- Top Nav -------------------------------------------------------------------
class _TopNav extends StatelessWidget {
  final Session session;
  final String timeStr, dateStr;
  final AnimationController pulseAnim;
  const _TopNav({
    required this.session,
    required this.timeStr,
    required this.dateStr,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.textD,
                ),
              ),
              Text(
                'Container Management System',
                style: TextStyle(fontSize: 10, color: _C.textL),
              ),
            ],
          ),
          const Spacer(),
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _C.textD,
                  ),
                ),
                Text(dateStr, style: TextStyle(fontSize: 8.5, color: _C.textL)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ProfileBtn(session: session),
        ],
      ),
    );
  }
}

// -- Profile Button ------------------------------------------------------------
class _ProfileBtn extends StatefulWidget {
  final Session session;
  const _ProfileBtn({required this.session});
  @override
  State<_ProfileBtn> createState() => _ProfileBtnState();
}

class _ProfileBtnState extends State<_ProfileBtn> {
  bool _h = false;
  final _link = LayerLink();
  OverlayEntry? _ov;
  final _inMenu = ValueNotifier<bool>(false);

  String get _ini {
    final p = widget.session.fullName.trim().split(' ');
    return p.length >= 2
        ? '${p.first[0]}${p.last[0]}'.toUpperCase()
        : p.first.isNotEmpty
        ? p.first[0].toUpperCase()
        : '?';
  }

  void _show() {
    _inMenu.value = true;
    if (_ov != null) return;
    _ov = OverlayEntry(
      builder: (_) => _ProfileDropdown(
        link: _link,
        initials: _ini,
        session: widget.session,
        inMenu: _inMenu,
        onHide: _hide,
        onScheduleHide: _sched,
        onProfile: () {
          _hide();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountScreen(
                session: widget.session,
                isAdmin: widget.session.isAdmin,
              ),
            ),
          );
        },
        onLogout: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (_) => false,
        ),
      ),
    );
    Overlay.of(context).insert(_ov!);
    setState(() => _h = true);
  }

  void _sched() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_inMenu.value && mounted) _hide();
    });
  }

  void _hide() {
    _ov?.remove();
    _ov = null;
    if (mounted) setState(() => _h = false);
  }

  @override
  void dispose() {
    _hide();
    _inMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _show(),
        onExit: (_) {
          _inMenu.value = false;
          _sched();
        },
        child: GestureDetector(
          onTap: () => _ov != null ? _hide() : _show(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _h ? _C.bg : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _h ? _C.border : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: _C.lincolnGreen,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _ini,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.session.fullName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _C.textD,
                      ),
                    ),
                    Text(
                      widget.session.role,
                      style: const TextStyle(fontSize: 9.5, color: _C.textL),
                    ),
                  ],
                ),
                const SizedBox(width: 3),
                AnimatedRotation(
                  turns: _h ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: _C.textL,
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

// -- Profile Dropdown ----------------------------------------------------------
class _ProfileDropdown extends StatefulWidget {
  final LayerLink link;
  final String initials;
  final Session session;
  final ValueNotifier<bool> inMenu;
  final VoidCallback onHide, onScheduleHide, onLogout;
  final VoidCallback onProfile;
  const _ProfileDropdown({
    required this.link,
    required this.initials,
    required this.session,
    required this.inMenu,
    required this.onHide,
    required this.onScheduleHide,
    required this.onProfile,
    required this.onLogout,
  });
  @override
  State<_ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<_ProfileDropdown> {
  void _sched() {
    widget.inMenu.value = false;
    widget.onScheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: const Offset(0, 50),
      targetAnchor: Alignment.topRight,
      followerAnchor: Alignment.topRight,
      child: Align(
        alignment: Alignment.topRight,
        child: MouseRegion(
          onEnter: (_) => widget.inMenu.value = true,
          onExit: (_) => _sched(),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 210,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: const BoxDecoration(
                      color: _C.emerald,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: _C.lincolnGreen,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.session.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.session.role,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  _DDItem(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Manage Profile',
                    onTap: widget.onProfile,
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 14,
                    endIndent: 14,
                  ),
                  const SizedBox(height: 3),
                  _DDItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: _C.red,
                    onTap: widget.onLogout,
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DDItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _DDItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _C.textD,
  });
  @override
  State<_DDItem> createState() => _DDItemState();
}

class _DDItemState extends State<_DDItem> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: _h ? widget.color.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: widget.color),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Welcome Banner ------------------------------------------------------------
class _WelcomeBanner extends StatelessWidget {
  final Session session;
  final VoidCallback onRefresh;
  final bool loading;
  const _WelcomeBanner({
    required this.session,
    required this.onRefresh,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.navBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/gothong_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${session.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        session.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Gothong Southern Container Management',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                    const SizedBox(width: 7),
                    const Text(
                      'Refresh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Section Header ------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _C.textD,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: _C.border)),
      ],
    );
  }
}

// -- Skeleton ------------------------------------------------------------------
class _SkeletonRow extends StatelessWidget {
  final int count;
  const _SkeletonRow(this.count);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 14 : 0),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -- Stat Card -----------------------------------------------------------------
// White-background card with colored icon, large value, trend badge, sparkline.
class _StatCard extends StatefulWidget {
  final String label, value, subtitle, trend;
  final IconData icon;
  final Color color;
  final bool trendUp, textDark;
  final AnimationController anim;
  final double delay;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.trend,
    required this.trendUp,
    required this.textDark,
    required this.anim,
    required this.delay,
    this.onTap,
  });
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _h = false;

  // Fixed sparkline points — unique wavy shape per card based on color hue
  List<double> get _sparkPoints {
    final seed = widget.color.value % 7;
    const waves = [
      [0.5, 0.55, 0.45, 0.6, 0.5, 0.65, 0.55, 0.7],
      [0.6, 0.5, 0.65, 0.55, 0.7, 0.6, 0.75, 0.65],
      [0.7, 0.6, 0.55, 0.65, 0.5, 0.6, 0.45, 0.55],
      [0.45, 0.55, 0.5, 0.6, 0.55, 0.65, 0.6, 0.7],
      [0.55, 0.65, 0.6, 0.5, 0.65, 0.55, 0.7, 0.6],
      [0.6, 0.7, 0.55, 0.65, 0.5, 0.6, 0.55, 0.65],
      [0.5, 0.45, 0.55, 0.5, 0.6, 0.5, 0.65, 0.55],
    ];
    return List<double>.from(waves[seed]);
  }

  @override
  Widget build(BuildContext context) {
    final trendColor = widget.trendUp
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);
    return AnimatedBuilder(
      animation: widget.anim,
      builder: (_, child) {
        final t = ((widget.anim.value - widget.delay) / (1 - widget.delay))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _h ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _h ? 0.10 : 0.05),
                  blurRadius: _h ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // -- Top section: icon + label + value + trend --
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Colored icon box
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.label,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF616161),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.value,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Trend badge: ? 16.0% from yesterday
                      Row(
                        children: [
                          Icon(
                            widget.trendUp
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: trendColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.trend} from yesterday',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // -- Sparkline at bottom --
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 44,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        points: _sparkPoints,
                        color: widget.color,
                        trendUp: widget.trendUp,
                      ),
                      size: const Size(double.infinity, 44),
                    ),
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

// -- Sparkline painter ----------------------------------------------------------
class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool trendUp;

  const _SparklinePainter({
    required this.points,
    required this.color,
    required this.trendUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final n = points.length;
    final xs = List.generate(n, (i) => i / (n - 1) * size.width);
    final ys = points.map((p) => (1.0 - p) * size.height).toList();

    // Build path
    final path = Path();
    path.moveTo(xs[0], ys[0]);
    for (int i = 1; i < n; i++) {
      final cpx = (xs[i - 1] + xs[i]) / 2;
      path.cubicTo(cpx, ys[i - 1], cpx, ys[i], xs[i], ys[i]);
    }

    // Fill under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

// -- Donut Chart Card ----------------------------------------------------------
class _DonutCard extends StatelessWidget {
  final int laden, empty, total;
  const _DonutCard({
    required this.laden,
    required this.empty,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final ladenPct = total > 0 ? laden / total : 0.0;
    final emptyPct = total > 0 ? empty / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.donut_large_rounded,
                color: _C.emerald,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Container Distribution',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $total',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _C.textM,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutPainter(
                    ladenPct: ladenPct,
                    emptyPct: emptyPct,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _C.textD,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 10, color: _C.textL),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _DonutLegend(
                      color: _C.gold,
                      label: 'Laden',
                      value: laden,
                      pct: (ladenPct * 100).round(),
                    ),
                    const SizedBox(height: 10),
                    _DonutLegend(
                      color: _C.red,
                      label: 'Empty',
                      value: empty,
                      pct: (emptyPct * 100).round(),
                    ),
                    const SizedBox(height: 10),
                    _DonutLegend(
                      color: _C.border,
                      label: 'Other',
                      value: total - laden - empty,
                      pct: total > 0
                          ? (((total - laden - empty) / total) * 100).round()
                          : 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int value, pct;
  const _DonutLegend({
    required this.color,
    required this.label,
    required this.value,
    required this.pct,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _C.textM,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _C.textD,
          ),
        ),
        const SizedBox(width: 6),
        Text('$pct%', style: TextStyle(fontSize: 10, color: _C.textL)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double ladenPct, emptyPct;
  const _DonutPainter({required this.ladenPct, required this.emptyPct});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 10;
    final stroke = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Background
    paint.color = _C.border;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    // Laden arc
    paint.color = _C.gold;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * ladenPct,
      false,
      paint,
    );
    // Empty arc
    paint.color = _C.red;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2 + 2 * math.pi * ladenPct,
      2 * math.pi * emptyPct,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.ladenPct != ladenPct || o.emptyPct != emptyPct;
}

// -- Occupancy Card ------------------------------------------------------------
class _OccupancyCard extends StatelessWidget {
  final int laden, empty, mtFood, fsl, stripping, mtNonFood, total;
  const _OccupancyCard({
    required this.laden,
    required this.empty,
    required this.mtFood,
    required this.fsl,
    required this.stripping,
    required this.mtNonFood,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final bars = [
      (
        label: 'Laden',
        value: laden,
        color: _C.gold,
        icon: Icons.check_circle_rounded,
      ),
      (
        label: 'Empty',
        value: empty,
        color: _C.red,
        icon: Icons.radio_button_unchecked_rounded,
      ),
      (
        label: 'MT Food',
        value: mtFood,
        color: _C.emeraldL,
        icon: Icons.restaurant_rounded,
      ),
      (
        label: 'FSL',
        value: fsl,
        color: _C.blue,
        icon: Icons.inventory_2_rounded,
      ),
      (
        label: 'Stripping',
        value: stripping,
        color: _C.orange,
        icon: Icons.content_cut_rounded,
      ),
      (
        label: 'MT Non-Food',
        value: mtNonFood,
        color: _C.purple,
        icon: Icons.no_food_rounded,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: _C.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Yard Occupancy by Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...bars.map((b) {
            final pct = total > 0 ? b.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(b.icon, color: b.color, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _C.textM,
                          ),
                        ),
                      ),
                      Text(
                        '${b.value}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: b.color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${(pct * 100).round()}%',
                        style: const TextStyle(fontSize: 10, color: _C.textL),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: b.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(b.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// -- Recent Activity Card ------------------------------------------------------
class _ActivityCard extends StatelessWidget {
  final List<ContainerModel> containers;
  const _ActivityCard({required this.containers});
  @override
  Widget build(BuildContext context) {
    // Show last 6 containers sorted by createdDate desc
    final recent = [...containers]
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    final shown = recent.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: _C.orange, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Recent Containers',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
              const Spacer(),
              Text(
                '${containers.length} total',
                style: const TextStyle(fontSize: 10.5, color: _C.textL),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No containers',
                  style: TextStyle(color: _C.textL, fontSize: 12),
                ),
              ),
            )
          else
            ...shown.map((c) {
              final isLaden = c.statusId == 1;
              final color = isLaden ? _C.gold : _C.red;
              final desc = c.containerDesc ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.containerNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textD,
                            ),
                          ),
                          if (desc.isNotEmpty)
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textL,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLaden ? 'Laden' : 'Empty',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// -- Port Leaderboard ----------------------------------------------------------
class _PortLeaderboard extends StatelessWidget {
  final List<Port> portList;
  final List<ContainerModel> containers;
  final List<ContainerModel> allContainers;
  final void Function(Port port, List<ContainerModel> list)? onTapPort;
  const _PortLeaderboard({
    required this.portList,
    required this.containers,
    this.allContainers = const [],
    this.onTapPort,
  });
  @override
  Widget build(BuildContext context) {
    if (portList.isEmpty) return const SizedBox.shrink();
    final data = portList.map((p) {
      final pc = containers.where((c) => c.currentPortId == p.portId).toList();
      return (
        port: p,
        total: pc.length,
        laden: pc.where((c) => c.statusId == 1).length,
        empty: pc.where((c) => c.statusId == 2).length,
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
    final maxTotal = data.isEmpty ? 1 : data.first.total.clamp(1, 999999);
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _C.navBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 28),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'PORT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'LADEN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'EMPTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'OCCUPANCY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...data.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            final pct = d.total / maxTotal;
            final rankColor = i == 0
                ? _C.gold
                : i == 1
                ? Colors.grey.shade400
                : i == 2
                ? const Color(0xFFCD7F32)
                : _C.textL;
            final portContainers = allContainers.isNotEmpty
                ? allContainers
                      .where((c) => c.currentPortId == d.port.portId)
                      .toList()
                : containers
                      .where((c) => c.currentPortId == d.port.portId)
                      .toList();
            return MouseRegion(
              cursor: onTapPort != null
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: GestureDetector(
                onTap: onTapPort != null
                    ? () => onTapPort!(d.port, portContainers)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: i.isEven ? _C.surface : _C.bg,
                    borderRadius: i == data.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          )
                        : null,
                    border: Border(
                      bottom: BorderSide(
                        color: _C.border,
                        width: i < data.length - 1 ? 1 : 0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: rankColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _C.emerald.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.anchor_rounded,
                                color: _C.emerald,
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.port.portDesc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _C.textD,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${d.total}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.textD,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${d.laden}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.gold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${d.empty}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.red,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 7,
                                  backgroundColor: _C.emerald.withOpacity(0.1),
                                  valueColor: const AlwaysStoppedAnimation(
                                    _C.emerald,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${(pct * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textL,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), // Container
              ), // GestureDetector
            ); // MouseRegion
          }),
        ],
      ),
    );
  }
}

// -- Container Table -----------------------------------------------------------
class _ContainerTable extends StatefulWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ContainerTable({required this.containers, required this.portList});
  @override
  State<_ContainerTable> createState() => _ContainerTableState();
}

class _ContainerTableState extends State<_ContainerTable> {
  String _search = '';
  String _statusFilter = 'all';
  int _page = 0;
  static const _perPage = 10;

  List<ContainerModel> get _filtered {
    var list = widget.containers;
    if (_statusFilter == 'laden') {
      list = list.where((c) => c.statusId == 1).toList();
    }
    if (_statusFilter == 'empty') {
      list = list.where((c) => c.statusId == 2).toList();
    }
    if (_search.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.containerNumber.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
    }
    return list;
  }

  String _portName(int portId) {
    try {
      return widget.portList.firstWhere((p) => p.portId == portId).portDesc;
    } catch (_) {
      return 'Port $portId';
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pages = (filtered.length / _perPage).ceil().clamp(1, 9999);
    final start = _page * _perPage;
    final pageItems = filtered.skip(start).take(_perPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                // Search
                Container(
                  width: 220,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: _C.textL,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() {
                            _search = v;
                            _page = 0;
                          }),
                          style: const TextStyle(fontSize: 12, color: _C.textD),
                          decoration: InputDecoration(
                            hintText: 'Search by container no…',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: _C.textL,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Filter chips
                ...[('all', 'All'), ('laden', 'Laden'), ('empty', 'Empty')].map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _statusFilter = f.$1;
                        _page = 0;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusFilter == f.$1
                              ? _C.emerald
                              : _C.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusFilter == f.$1
                                ? _C.emerald
                                : _C.border,
                          ),
                        ),
                        child: Text(
                          f.$2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _statusFilter == f.$1
                                ? Colors.white
                                : _C.textM,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} records',
                  style: const TextStyle(fontSize: 11, color: _C.textL),
                ),
              ],
            ),
          ),
          // Header
          Container(
            color: _C.navBg,
            child: _TableRow(
              cells: const [
                '#',
                'CONTAINER NO.',
                'STATUS',
                'SIZE',
                'TYPE',
                'PORT',
                'DATE IN YARD',
                'DAYS IN YARD',
              ],
              isHeader: true,
            ),
          ),
          // Rows
          if (pageItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No containers found',
                  style: TextStyle(color: _C.textL, fontSize: 13),
                ),
              ),
            )
          else
            ...pageItems.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final isLaden = c.statusId == 1;
              final days = c.yardEntryDate != null
                  ? DateTime.now()
                        .difference(
                          DateTime.tryParse(c.yardEntryDate!) ?? DateTime.now(),
                        )
                        .inDays
                  : 0;
              return _TableRow(
                bg: i.isEven ? _C.surface : _C.bg,
                isLast: i == pageItems.length - 1,
                cells: [
                  '${start + i + 1}',
                  c.containerNumber,
                  isLaden ? 'Laden' : 'Empty',
                  c.containerSizeId == 1
                      ? '20ft'
                      : c.containerSizeId == 2
                      ? '40ft'
                      : '—',
                  c.containerDesc ?? '—',
                  _portName(c.currentPortId),
                  _fmt(c.yardEntryDate),
                  '$days days',
                ],
                statusIndex: 2,
                isLaden: isLaden,
              );
            }),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Page ${_page + 1} of $pages',
                  style: const TextStyle(fontSize: 11, color: _C.textL),
                ),
                const Spacer(),
                ...[
                  Icons.first_page_rounded,
                  Icons.chevron_left_rounded,
                  Icons.chevron_right_rounded,
                  Icons.last_page_rounded,
                ].asMap().entries.map((e) {
                  final enabled = e.key < 2 ? _page > 0 : _page < pages - 1;
                  return GestureDetector(
                    onTap: enabled
                        ? () => setState(() {
                            if (e.key == 0) {
                              _page = 0;
                            } else if (e.key == 1)
                              _page--;
                            else if (e.key == 2)
                              _page++;
                            else
                              _page = pages - 1;
                          })
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: enabled ? _C.surface : _C.bg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _C.border),
                      ),
                      child: Icon(
                        e.value,
                        size: 14,
                        color: enabled ? _C.textD : _C.textL,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final List<String> cells;
  final bool isHeader;
  final Color? bg;
  final bool isLast;
  final int statusIndex;
  final bool? isLaden;
  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.bg,
    this.isLast = false,
    this.statusIndex = -1,
    this.isLaden,
  });
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!widget.isHeader) setState(() => _h = true);
      },
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: widget.isHeader
            ? Colors.transparent
            : _h
            ? _C.emerald.withOpacity(0.04)
            : (widget.bg ?? _C.surface),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: widget.cells.asMap().entries.map((e) {
              final isStatus = e.key == widget.statusIndex;
              final flex = e.key == 1
                  ? 2
                  : e.key == 4
                  ? 2
                  : e.key == 5
                  ? 2
                  : 1;
              Widget cell;
              if (widget.isHeader) {
                cell = Text(
                  e.value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                );
              } else if (isStatus) {
                final isLaden = widget.isLaden ?? false;
                cell = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isLaden ? _C.gold : _C.red).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isLaden ? _C.goldD : _C.red,
                    ),
                  ),
                );
              } else {
                cell = Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: e.key == 0 ? _C.textL : _C.textD,
                    fontWeight: e.key == 1 ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }
              return Expanded(flex: flex, child: cell);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// NEW CONTAINER FLOW WIDGETS
// ----------------------------------------------------------------------------

// -- Shared card shell ---------------------------------------------------------
// ----------------------------------------------------------------------------
// CONTAINER FLOW WIDGETS  (rewritten with full interactivity)
// ----------------------------------------------------------------------------

// -- Time-range enum shared by all CF cards ------------------------------------
enum _CFRange { thisWeek, lastWeek, thisMonth }

extension _CFRangeLabel on _CFRange {
  String get label {
    switch (this) {
      case _CFRange.thisWeek:
        return 'This Week';
      case _CFRange.lastWeek:
        return 'Last Week';
      case _CFRange.thisMonth:
        return 'This Month';
    }
  }
}

// -- Shared card shell ---------------------------------------------------------
class _CF_Card extends StatelessWidget {
  final Widget child;
  const _CF_Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// -- Range dropdown pill -------------------------------------------------------
class _CF_RangePill extends StatelessWidget {
  final _CFRange value;
  final ValueChanged<_CFRange> onChanged;
  const _CF_RangePill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) async {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset offset = box.localToGlobal(Offset.zero);
        final result = await showMenu<_CFRange>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + box.size.height + 4,
            offset.dx + box.size.width,
            0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 6,
          items: _CFRange.values
              .map(
                (r) => PopupMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      Icon(
                        r == value
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 14,
                        color: r == value ? _C.emerald : _C.textL,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: r == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: r == value ? _C.emerald : _C.textD,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 12,
              color: Color(0xFF757575),
            ),
          ],
        ),
      ),
    );
  }
}

// -- CF header row with live range picker --------------------------------------
class _CF_Header extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final _CFRange range;
  final ValueChanged<_CFRange>? onRangeChanged;
  const _CF_Header({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.range = _CFRange.thisWeek,
    this.onRangeChanged,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 220;
        final iconBox = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        );
        final titleCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
        if (tight && onRangeChanged != null) {
          // Stacked layout when very narrow: icon+title on top, pill below
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  iconBox,
                  const SizedBox(width: 10),
                  Expanded(child: titleCol),
                ],
              ),
              const SizedBox(height: 6),
              _CF_RangePill(value: range, onChanged: onRangeChanged!),
            ],
          );
        }
        return Row(
          children: [
            iconBox,
            const SizedBox(width: 10),
            Expanded(child: titleCol),
            if (onRangeChanged != null)
              _CF_RangePill(value: range, onChanged: onRangeChanged!),
          ],
        );
      },
    );
  }
}

// -- Helper: filter daily data by range ---------------------------------------
List<int> _cfFilterByRange(
  List<ContainerModel> containers,
  _CFRange range,
  String Function(ContainerModel) getDate,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  int days;
  int offsetStart;
  switch (range) {
    case _CFRange.thisWeek:
      days = 7;
      offsetStart = 0;
      break;
    case _CFRange.lastWeek:
      days = 7;
      offsetStart = 7;
      break;
    case _CFRange.thisMonth:
      days = 30;
      offsetStart = 0;
      break;
  }
  final result = List<int>.filled(days, 0);
  for (final c in containers) {
    final dateStr = getDate(c);
    if (dateStr.isEmpty) continue;
    try {
      final d = DateTime.parse(dateStr);
      final dayDate = DateTime(d.year, d.month, d.day);
      final diff = today.difference(dayDate).inDays;
      if (diff >= offsetStart && diff < offsetStart + days) {
        result[(days - 1) - (diff - offsetStart)]++;
      }
    } catch (_) {}
  }
  return result;
}

List<String> _cfDayLabels(_CFRange range) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  int days;
  int offsetStart;
  switch (range) {
    case _CFRange.thisWeek:
      days = 7;
      offsetStart = 0;
      break;
    case _CFRange.lastWeek:
      days = 7;
      offsetStart = 7;
      break;
    case _CFRange.thisMonth:
      days = 30;
      offsetStart = 0;
      break;
  }
  return List.generate(days, (i) {
    final d = today.subtract(Duration(days: (days - 1 - i) + offsetStart));
    return '${months[d.month - 1]} ${d.day}';
  });
}

String _cfTrendPct(List<int> cur, List<int> prior) {
  final c = cur.fold(0, (a, b) => a + b);
  final p = prior.fold(0, (a, b) => a + b);
  if (p == 0) return c > 0 ? '+100%' : '0%';
  final pct = ((c - p) / p * 100).round();
  return pct >= 0 ? '+$pct%' : '$pct%';
}

// -- 1. Total Inbound Card -----------------------------------------------------
class _CF_InboundCard extends StatefulWidget {
  final List<ContainerModel> allContainers;
  const _CF_InboundCard({required this.allContainers});
  @override
  State<_CF_InboundCard> createState() => _CF_InboundCardState();
}

class _CF_InboundCardState extends State<_CF_InboundCard> {
  _CFRange _range = _CFRange.thisWeek;
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final inboundAll = widget.allContainers
        .where((c) => c.yardEntryDate != null)
        .toList();
    final cur = _cfFilterByRange(
      inboundAll,
      _range,
      (c) => c.yardEntryDate ?? '',
    );
    final prev = _cfFilterByRange(
      inboundAll,
      _range == _CFRange.lastWeek ? _CFRange.thisWeek : _CFRange.lastWeek,
      (c) => c.yardEntryDate ?? '',
    );
    final labels = _cfDayLabels(_range);
    final total = cur.fold(0, (a, b) => a + b);
    final trend = _cfTrendPct(cur, prev);
    final trendUp = !trend.startsWith('-');
    final trendColor = trendUp ? _C.emerald : _C.red;
    final data = cur.map((v) => v.toDouble()).toList();
    final maxV = data
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final weekTotal = total.clamp(1, 999999);

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.arrow_downward_rounded,
            iconColor: _C.emerald,
            title: 'Total Inbound Containers',
            range: _range,
            onRangeChanged: (r) => setState(() {
              _range = r;
              _sel = null;
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF212121),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trendUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: trendColor,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '$trend from previous period',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Total Inbound',
                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // -- Bar chart --
          SizedBox(
            height: 90,
            child: Column(
              children: [
                // Inline info panel
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _sel != null ? 22 : 0,
                  child: _sel != null
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _C.emerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _C.emerald.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: _C.emerald,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${labels[_sel!]}  ·  ${data[_sel!].round()} containers  ·  ${((data[_sel!] / weekTotal) * 100).round()}% of total',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: _C.emerald,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(data.length, (i) {
                      final pct = maxV > 0 ? data[i] / maxV : 0.0;
                      final barH = data[i] == 0
                          ? 0.0
                          : (58 * pct).clamp(3.0, 58.0);
                      final isActive = _sel == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _sel = _sel == i ? null : i),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i < data.length - 1 ? 3 : 0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _C.emerald
                                          : _C.emerald.withValues(alpha: 0.35),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    labels[i]
                                        .split(' ')
                                        .last, // show day number only
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isActive
                                          ? _C.emerald
                                          : const Color(0xFF9E9E9E),
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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

// -- 2. Total Outbound Card ----------------------------------------------------
class _CF_OutboundCard extends StatefulWidget {
  final List<ContainerModel> allContainers;
  const _CF_OutboundCard({required this.allContainers});
  @override
  State<_CF_OutboundCard> createState() => _CF_OutboundCardState();
}

class _CF_OutboundCardState extends State<_CF_OutboundCard> {
  _CFRange _range = _CFRange.thisWeek;
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final outboundAll = widget.allContainers
        .where((c) => c.isMovedOut && c.moveConfirmedDate != null)
        .toList();
    final cur = _cfFilterByRange(
      outboundAll,
      _range,
      (c) => c.moveConfirmedDate ?? '',
    );
    final prev = _cfFilterByRange(
      outboundAll,
      _range == _CFRange.lastWeek ? _CFRange.thisWeek : _CFRange.lastWeek,
      (c) => c.moveConfirmedDate ?? '',
    );
    final labels = _cfDayLabels(_range);
    final total = cur.fold(0, (a, b) => a + b);
    final trend = _cfTrendPct(cur, prev);
    final trendUp = !trend.startsWith('-');
    final trendColor = trendUp ? _C.emerald : _C.red;
    final data = cur.map((v) => v.toDouble()).toList();
    final maxV = data
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final weekTotal = total.clamp(1, 999999);

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.arrow_upward_rounded,
            iconColor: _C.blue,
            title: 'Total Outbound Containers',
            range: _range,
            onRangeChanged: (r) => setState(() {
              _range = r;
              _sel = null;
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF212121),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trendUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: trendColor,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '$trend from previous period',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Total Outbound',
                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _sel != null ? 22 : 0,
                  child: _sel != null
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _C.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _C.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: _C.blue,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${labels[_sel!]}  ·  ${data[_sel!].round()} containers  ·  ${((data[_sel!] / weekTotal) * 100).round()}% of total',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: _C.blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(data.length, (i) {
                      final pct = maxV > 0 ? data[i] / maxV : 0.0;
                      final barH = data[i] == 0
                          ? 0.0
                          : (58 * pct).clamp(3.0, 58.0);
                      final isActive = _sel == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _sel = _sel == i ? null : i),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i < data.length - 1 ? 3 : 0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _C.blue
                                          : _C.blue.withValues(alpha: 0.35),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    labels[i].split(' ').last,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isActive
                                          ? _C.blue
                                          : const Color(0xFF9E9E9E),
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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

// -- 3. Total Empty Containers — donut + legend --------------------------------
class _CF_EmptyDonutCard extends StatefulWidget {
  final int foodGrade, nonFoodGrade, repairable, frmd, total;
  final List<ContainerModel> allEmpty;
  final void Function(String label, List<ContainerModel> list)? onTapType;
  const _CF_EmptyDonutCard({
    required this.foodGrade,
    required this.nonFoodGrade,
    required this.repairable,
    required this.frmd,
    required this.total,
    this.allEmpty = const [],
    this.onTapType,
  });
  @override
  State<_CF_EmptyDonutCard> createState() => _CF_EmptyDonutCardState();
}

class _CF_EmptyDonutCardState extends State<_CF_EmptyDonutCard> {
  int? _sel;
  _CFRange _range = _CFRange.thisWeek;

  @override
  Widget build(BuildContext context) {
    final slices = [
      (label: 'Food Grade', count: widget.foodGrade, color: _C.emerald),
      (label: 'Non-Food Grade', count: widget.nonFoodGrade, color: _C.blue),
      (label: 'Repairable', count: widget.repairable, color: _C.gold),
      (label: 'FRMD Containers', count: widget.frmd, color: _C.red),
    ];
    final total = widget.total.clamp(1, 999999);
    final selSlice = _sel != null ? slices[_sel!] : null;

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.donut_large_rounded,
            iconColor: _C.orange,
            title: 'Total Empty Containers',
            subtitle: '(By Type)',
            range: _range,
            onRangeChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // -- Donut (tappable) --
              GestureDetector(
                onTapUp: (d) => _handleDonutTap(d.localPosition, slices),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(110, 110),
                        painter: _CF_DonutPainter(
                          values: slices
                              .map((s) => s.count.toDouble())
                              .toList(),
                          colors: slices.map((s) => s.color).toList(),
                          selected: _sel,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selSlice != null
                                ? '${selSlice.count}'
                                : '${widget.total}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: selSlice != null
                                  ? selSlice.color
                                  : const Color(0xFF212121),
                            ),
                          ),
                          Text(
                            selSlice != null ? selSlice.label : 'Total',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9E9E9E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // -- Legend --
              Expanded(
                child: Column(
                  children: slices.asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    final pct = (s.count / total * 100).round();
                    final isSelected = _sel == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _sel = _sel == i ? null : i);
                        if (widget.onTapType != null && _sel == i) {
                          final list = widget.allEmpty.where((c) {
                            final d = c.containerDesc?.toLowerCase() ?? '';
                            if (s.label == 'Food Grade') {
                              return d.contains('food') && !d.contains('non');
                            }
                            if (s.label == 'Non-Food Grade') {
                              return d.contains('non') && d.contains('food');
                            }
                            if (s.label == 'Repairable') {
                              return d.contains('repair');
                            }
                            return d.contains('frmd');
                          }).toList();
                          widget.onTapType!(s.label, list);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: isSelected
                            ? const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              )
                            : EdgeInsets.zero,
                        decoration: isSelected
                            ? BoxDecoration(
                                color: s.color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: s.color.withValues(alpha: 0.25),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? s.color
                                      : const Color(0xFF424242),
                                ),
                              ),
                            ),
                            Text(
                              '${s.count}  ($pct%)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: s.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          // -- Inline detail bar --
          if (_sel != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: slices[_sel!].color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: slices[_sel!].color.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: slices[_sel!].color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${slices[_sel!].label}: ${slices[_sel!].count} containers  ·  ${(slices[_sel!].count / total * 100).round()}% of empty stock',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: slices[_sel!].color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _sel = null),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: slices[_sel!].color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleDonutTap(
    Offset pos,
    List<({Color color, int count, String label})> slices,
  ) {
    final cx = 55.0;
    final cy = 55.0;
    final dx = pos.dx - cx;
    final dy = pos.dy - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final r = 55.0 - 6;
    const hole = 0.55;
    final innerR = r * hole;
    final outerR = r;
    if (dist < innerR || dist > outerR) {
      setState(() => _sel = null);
      return;
    }
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final total = slices.fold(0, (a, s) => a + s.count).toDouble();
    if (total == 0) return;
    double start = 0;
    for (int i = 0; i < slices.length; i++) {
      if (slices[i].count == 0) continue;
      final sweep = (slices[i].count / total) * 2 * math.pi;
      if (angle >= start && angle < start + sweep) {
        setState(() => _sel = _sel == i ? null : i);
        return;
      }
      start += sweep;
    }
  }
}

// -- Donut painter -------------------------------------------------------------
class _CF_DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final int? selected;
  const _CF_DonutPainter({
    required this.values,
    required this.colors,
    this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 6;
    const hole = 0.55;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi;
      final isSelected = i == selected;
      final offset = isSelected ? 5.0 : 0.0;
      final mid = start + sweep / 2;
      final ox = math.cos(mid) * offset;
      final oy = math.sin(mid) * offset;
      final innerR = r * hole + (r * (1 - hole) / 2);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + ox, cy + oy), radius: innerR),
        start,
        sweep - 0.03,
        false,
        Paint()
          ..color = isSelected ? colors[i] : colors[i].withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (1 - hole)
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_CF_DonutPainter old) =>
      old.selected != selected ||
      old.values.length != values.length ||
      List.generate(
        values.length,
        (i) => old.values[i] != values[i],
      ).any((e) => e);
}

// -- 4. Total Laden Card — interactive sparkline -------------------------------
class _CF_LadenSparkCard extends StatefulWidget {
  final List<ContainerModel> allContainers;
  final int tempoGrounding;
  final void Function(String label, List<ContainerModel> list)? onTap;
  const _CF_LadenSparkCard({
    required this.allContainers,
    required this.tempoGrounding,
    this.onTap,
  });
  @override
  State<_CF_LadenSparkCard> createState() => _CF_LadenSparkCardState();
}

class _CF_LadenSparkCardState extends State<_CF_LadenSparkCard> {
  _CFRange _range = _CFRange.thisWeek;
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final ladenAll = widget.allContainers
        .where((c) => c.statusId == 1 && c.yardEntryDate != null)
        .toList();
    final cur = _cfFilterByRange(
      ladenAll,
      _range,
      (c) => c.yardEntryDate ?? '',
    );
    final prev = _cfFilterByRange(
      ladenAll,
      _range == _CFRange.lastWeek ? _CFRange.thisWeek : _CFRange.lastWeek,
      (c) => c.yardEntryDate ?? '',
    );
    final labels = _cfDayLabels(_range);
    final total = widget.allContainers.where((c) => c.statusId == 1).length;
    final trend = _cfTrendPct(cur, prev);
    final trendUp = !trend.startsWith('-');
    final trendColor = trendUp ? _C.emerald : _C.red;
    final data = cur.map((v) => v.toDouble()).toList();
    final weekTotal = cur.fold(0, (a, b) => a + b).clamp(1, 999999);

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.check_circle_rounded,
            iconColor: _C.gold,
            title: 'Total Laden Containers',
            subtitle: '(Including Tempo Grounding)',
            range: _range,
            onRangeChanged: (r) => setState(() {
              _range = r;
              _sel = null;
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF212121),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trendUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: trendColor,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '$trend from previous period',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Total Laden',
                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          if (widget.tempoGrounding > 0) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _C.purple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Tempo Grounding: ${widget.tempoGrounding}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF616161),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // -- Interactive sparkline — fixed height, chip overlays inside --
          SizedBox(
            height: 90,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return Stack(
                  children: [
                    // Sparkline + day labels
                    Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTapUp: (d) {
                              if (data.isEmpty || data.length < 2) return;
                              final step =
                                  constraints.maxWidth / (data.length - 1);
                              final i = (d.localPosition.dx / step)
                                  .round()
                                  .clamp(0, data.length - 1);
                              setState(() => _sel = _sel == i ? null : i);
                            },
                            child: CustomPaint(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight - 16,
                              ),
                              painter: _CF_InteractiveSparklinePainter(
                                values: data,
                                color: _C.gold,
                                selectedIndex: _sel,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: labels
                              .map(
                                (d) => Text(
                                  d.split(' ').last,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    // Detail chip overlays at top — does NOT resize card
                    if (_sel != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _C.gold,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.show_chart_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${labels[_sel!]}  ·  ${data[_sel!].round()} laden  ·  ${((data[_sel!] / weekTotal) * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _sel = null),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -- Interactive sparkline painter ---------------------------------------------
class _CF_InteractiveSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int? selectedIndex;
  const _CF_InteractiveSparklinePainter({
    required this.values,
    required this.color,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;
    final maxV = values
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final n = values.length;
    final step = size.width / (n - 1);

    Offset pt(int i) =>
        Offset(i * step, size.height - (values[i] / maxV) * size.height * 0.88);

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) {
      final cpx = (pt(i - 1).dx + pt(i).dx) / 2;
      path.cubicTo(cpx, pt(i - 1).dy, cpx, pt(i).dy, pt(i).dx, pt(i).dy);
    }
    // Fill
    canvas.drawPath(
      Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Dots + selected highlight
    for (int i = 0; i < n; i++) {
      final isSelected = i == selectedIndex;
      if (isSelected) {
        // Vertical guide line
        canvas.drawLine(
          Offset(pt(i).dx, 0),
          Offset(pt(i).dx, size.height),
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
        // Large dot
        canvas.drawCircle(
          pt(i),
          6,
          Paint()..color = color.withValues(alpha: 0.15),
        );
        canvas.drawCircle(pt(i), 4, Paint()..color = Colors.white);
        canvas.drawCircle(
          pt(i),
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(pt(i), 2.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          pt(i),
          2,
          Paint()..color = color.withValues(alpha: 0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CF_InteractiveSparklinePainter old) =>
      old.selectedIndex != selectedIndex ||
      old.color != color ||
      old.values.length != values.length ||
      List.generate(
        values.length,
        (i) => old.values[i] != values[i],
      ).any((e) => e);
}

// -- Sparkline painter (non-interactive, for yard sub-cards) -------------------
class _CF_SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _CF_SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;
    final maxV = values
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final n = values.length;
    final step = size.width / (n - 1);
    Offset pt(int i) =>
        Offset(i * step, size.height - (values[i] / maxV) * size.height * 0.85);
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) {
      final cpx = (pt(i - 1).dx + pt(i).dx) / 2;
      path.cubicTo(cpx, pt(i - 1).dy, cpx, pt(i).dy, pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pt(i), 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(pt(i), 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CF_SparklinePainter old) =>
      old.color != color ||
      old.values.length != values.length ||
      List.generate(
        values.length,
        (i) => old.values[i] != values[i],
      ).any((e) => e);
}

// -- 5. Total Container In Yard ------------------------------------------------
class _CF_YardInOutCard extends StatefulWidget {
  final List<ContainerModel> allInYard;
  final List<ContainerModel> allOutYard;
  final void Function(String label, List<ContainerModel> list)? onTap;
  const _CF_YardInOutCard({required this.allInYard, required this.allOutYard, this.onTap});
  @override
  State<_CF_YardInOutCard> createState() => _CF_YardInOutCardState();
}

class _CF_YardInOutCardState extends State<_CF_YardInOutCard> {
  _CFRange _range = _CFRange.thisWeek;

  @override
  Widget build(BuildContext context) {
    final labels = _cfDayLabels(_range);
    final inData = _cfFilterByRange(
      widget.allInYard,
      _range,
      (c) => c.yardEntryDate ?? '',
    );
    final outData = _cfFilterByRange(
      widget.allOutYard,
      _range,
      (c) => c.moveConfirmedDate ?? '',
    );

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Container In Yard',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
              _CF_RangePill(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CF_YardSubCard(
                  label: 'Container Yard In',
                  value: widget.allInYard.length,
                  color: _C.emerald,
                  icon: Icons.arrow_downward_rounded,
                  dailyData: inData,
                  dayLabels: labels,
                  onTap: widget.onTap != null
                      ? () =>
                            widget.onTap!('Container Yard In', widget.allInYard)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CF_YardSubCard(
                  label: 'Container Yard Out',
                  value: widget.allOutYard.length,
                  color: _C.blue,
                  icon: Icons.arrow_upward_rounded,
                  dailyData: outData,
                  dayLabels: labels,
                  onTap: widget.onTap != null
                      ? () => widget.onTap!(
                          'Container Yard Out',
                          widget.allOutYard,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -- Yard sub-card with interactive sparkline ----------------------------------
class _CF_YardSubCard extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final List<int> dailyData;
  final List<String> dayLabels;
  final VoidCallback? onTap;
  const _CF_YardSubCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.dailyData,
    required this.dayLabels,
    this.onTap,
  });
  @override
  State<_CF_YardSubCard> createState() => _CF_YardSubCardState();
}

class _CF_YardSubCardState extends State<_CF_YardSubCard> {
  int? _sel;
  @override
  Widget build(BuildContext context) {
    final data = widget.dailyData.map((v) => v.toDouble()).toList();
    final weekTotal = widget.dailyData
        .fold(0, (a, b) => a + b)
        .clamp(1, 999999);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        // Fixed height so both cards are always equal
        height: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Value
            Text(
              '${widget.value}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: widget.color,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            // Chart area — fixed height, detail chip overlays inside via Stack
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      // Sparkline fills full area
                      Column(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTapUp: (d) {
                                if (data.length < 2) return;
                                final step =
                                    constraints.maxWidth / (data.length - 1);
                                final i = (d.localPosition.dx / step)
                                    .round()
                                    .clamp(0, data.length - 1);
                                setState(() => _sel = _sel == i ? null : i);
                              },
                              child: CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight - 16,
                                ),
                                painter: _CF_InteractiveSparklinePainter(
                                  values: data,
                                  color: widget.color,
                                  selectedIndex: _sel,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: widget.dayLabels
                                .map(
                                  (d) => Text(
                                    d.split(' ').last,
                                    style: const TextStyle(
                                      fontSize: 7,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      // Detail chip overlays at top — DOES NOT change card height
                      if (_sel != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${widget.dayLabels[_sel!]}  ·  ${data[_sel!].round()}  ·  ${((data[_sel!] / weekTotal) * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _sel = null),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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

// -- 6. Container Status Overview — donut --------------------------------------
class _CF_StatusOverviewCard extends StatefulWidget {
  final int inYard, laden, empty;
  final List<ContainerModel> allContainers;
  final void Function(String label, List<ContainerModel> list)? onTap;
  const _CF_StatusOverviewCard({
    required this.inYard,
    required this.laden,
    required this.empty,
    this.allContainers = const [],
    this.onTap,
  });
  @override
  State<_CF_StatusOverviewCard> createState() => _CF_StatusOverviewCardState();
}

class _CF_StatusOverviewCardState extends State<_CF_StatusOverviewCard> {
  int? _sel;
  _CFRange _range = _CFRange.thisWeek;

  @override
  Widget build(BuildContext context) {
    final other = (widget.inYard - widget.laden - widget.empty).clamp(
      0,
      999999,
    );
    final total = widget.inYard.clamp(1, 999999);
    // Donut segments: laden, empty, other (non-overlapping)
    final segments = [
      (
        label: 'Laden',
        count: widget.laden,
        color: _C.gold,
        list: widget.allContainers
            .where((c) => c.statusId == 1 && !c.isMovedOut)
            .toList(),
      ),
      (
        label: 'Empty',
        count: widget.empty,
        color: _C.red,
        list: widget.allContainers
            .where((c) => c.statusId == 2 && !c.isMovedOut)
            .toList(),
      ),
      (
        label: 'Other',
        count: other,
        color: _C.emerald.withValues(alpha: 0.6),
        list: widget.allContainers
            .where((c) => !c.isMovedOut && c.statusId != 1 && c.statusId != 2)
            .toList(),
      ),
    ];
    final selSeg = _sel != null ? segments[_sel!] : null;

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.pie_chart_rounded,
            iconColor: _C.teal,
            title: 'Container Status Overview',
            range: _range,
            onRangeChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // -- Donut (tappable) --
              GestureDetector(
                onTapUp: (d) => _handleTap(d.localPosition, segments),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(110, 110),
                        painter: _CF_DonutPainter(
                          values: segments
                              .map((s) => s.count.toDouble())
                              .toList(),
                          colors: segments.map((s) => s.color).toList(),
                          selected: _sel,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selSeg != null
                                ? '${selSeg.count}'
                                : '${widget.inYard}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: selSeg != null
                                  ? selSeg.color
                                  : const Color(0xFF212121),
                            ),
                          ),
                          Text(
                            selSeg != null ? selSeg.label : 'Total',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9E9E9E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: segments.asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    final pct = (s.count / total * 100).round();
                    final isSelected = _sel == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _sel = _sel == i ? null : i);
                        if (widget.onTap != null && _sel == i) {
                          widget.onTap!(s.label, s.list);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: isSelected
                            ? const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              )
                            : EdgeInsets.zero,
                        decoration: isSelected
                            ? BoxDecoration(
                                color: s.color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: s.color.withValues(alpha: 0.3),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? s.color
                                      : const Color(0xFF424242),
                                ),
                              ),
                            ),
                            Text(
                              '${s.count} ($pct%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: s.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          // -- Inline detail --
          if (_sel != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: segments[_sel!].color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: segments[_sel!].color.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: segments[_sel!].color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${segments[_sel!].label}: ${segments[_sel!].count} containers  ·  ${(segments[_sel!].count / total * 100).round()}% of in-yard stock',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: segments[_sel!].color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _sel = null),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: segments[_sel!].color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleTap(
    Offset pos,
    List<({Color color, int count, String label, List<ContainerModel> list})>
    segs,
  ) {
    const cx = 55.0;
    const cy = 55.0;
    final dx = pos.dx - cx;
    final dy = pos.dy - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final r = 55.0 - 6;
    const hole = 0.55;
    if (dist < r * hole || dist > r) {
      setState(() => _sel = null);
      return;
    }
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final total = segs.fold(0, (a, s) => a + s.count).toDouble();
    if (total == 0) return;
    double start = 0;
    for (int i = 0; i < segs.length; i++) {
      if (segs[i].count == 0) continue;
      final sweep = (segs[i].count / total) * 2 * math.pi;
      if (angle >= start && angle < start + sweep) {
        setState(() => _sel = _sel == i ? null : i);
        if (_sel == i && widget.onTap != null) {
          widget.onTap!(segs[i].label, segs[i].list);
        }
        return;
      }
      start += sweep;
    }
  }
}

// -- 7. Containers per Port -----------------------------------------------------
class _CF_ContainersPerPortCard extends StatefulWidget {
  final List<Port> portList;
  final List<ContainerModel> containers;
  final List<ContainerModel> allContainers;
  final void Function(Port port, List<ContainerModel> list)? onTapPort;
  const _CF_ContainersPerPortCard({
    required this.portList,
    required this.containers,
    this.allContainers = const [],
    this.onTapPort,
  });
  @override
  State<_CF_ContainersPerPortCard> createState() =>
      _CF_ContainersPerPortCardState();
}

class _CF_ContainersPerPortCardState extends State<_CF_ContainersPerPortCard> {
  _CFRange _range = _CFRange.thisWeek;
  int? _selPort;

  @override
  Widget build(BuildContext context) {
    if (widget.portList.isEmpty) return const SizedBox.shrink();
    final data = widget.portList.map((p) {
      final pc = widget.containers
          .where((c) => c.currentPortId == p.portId)
          .toList();
      return (
        port: p,
        total: pc.length,
        laden: pc.where((c) => c.statusId == 1).length,
        empty: pc.where((c) => c.statusId == 2).length,
        list: pc,
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
    final maxTotal = data.isEmpty ? 1 : data.first.total.clamp(1, 999999);

    return _CF_Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CF_Header(
            icon: Icons.anchor_rounded,
            iconColor: _C.blue,
            title: 'Containers per Port',
            range: _range,
            onRangeChanged: (r) => setState(() {
              _range = r;
              _selPort = null;
            }),
          ),
          const SizedBox(height: 14),
          ...data.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            final pct = d.total / maxTotal;
            final isSelected = _selPort == i;
            final portAll = widget.allContainers.isNotEmpty
                ? widget.allContainers
                      .where((c) => c.currentPortId == d.port.portId)
                      .toList()
                : d.list;
            return GestureDetector(
              onTap: () {
                setState(() => _selPort = _selPort == i ? null : i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: isSelected ? const EdgeInsets.all(8) : EdgeInsets.zero,
                decoration: isSelected
                    ? BoxDecoration(
                        color: _C.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _C.blue.withValues(alpha: 0.2),
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.port.portDesc,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${d.total}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _C.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'L:${d.laden}',
                            style: TextStyle(
                              fontSize: 9,
                              color: _C.goldD,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _C.red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'E:${d.empty}',
                            style: TextStyle(
                              fontSize: 9,
                              color: _C.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Segmented bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 8, color: const Color(0xFFF0F0F0)),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _C.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor:
                                (d.laden / d.total.clamp(1, 999999)) * pct,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _C.gold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Inline detail row when selected
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            _CF_PortStatChip(
                              label: 'Total',
                              value: d.total,
                              color: _C.blue,
                            ),
                            const SizedBox(width: 6),
                            _CF_PortStatChip(
                              label: 'Laden',
                              value: d.laden,
                              color: _C.gold,
                            ),
                            const SizedBox(width: 6),
                            _CF_PortStatChip(
                              label: 'Empty',
                              value: d.empty,
                              color: _C.red,
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onTapPort != null
                                  ? () => widget.onTapPort!(d.port, portAll)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _C.blue,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          // Legend
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _C.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Laden',
                style: TextStyle(fontSize: 10, color: Color(0xFF616161)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _C.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Empty',
                style: TextStyle(fontSize: 10, color: Color(0xFF616161)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CF_PortStatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _CF_PortStatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Inbound Card (bar chart — interactive) ------------------------------------
class _InboundCard extends StatefulWidget {
  final int inbound;
  final List<int> dailyData;
  final List<String> dayLabels;
  const _InboundCard({
    required this.inbound,
    required this.dailyData,
    required this.dayLabels,
  });

  @override
  State<_InboundCard> createState() => _InboundCardState();
}

class _InboundCardState extends State<_InboundCard> {
  int? _selectedBar;

  @override
  void didUpdateWidget(_InboundCard old) {
    super.didUpdateWidget(old);
    if (old.inbound != widget.inbound) _selectedBar = null;
  }

  @override
  Widget build(BuildContext context) {
    // Use real daily data — actual container counts per day
    final data = widget.dailyData.map((v) => v.toDouble()).toList();
    final maxVal = data
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final days = widget.dayLabels;
    final sel = _selectedBar;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.emerald.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // -- Header ----------------------------------------------
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: _C.emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Inbound',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    Text(
                      'Tap a bar to see daily details',
                      style: TextStyle(fontSize: 11, color: _C.textL),
                    ),
                  ],
                ),
              ),
              // Dismiss selection button
              if (sel != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedBar = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _C.textL,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // -- Big count --------------------------------------------
          widget.inbound == 0
              ? const Text(
                  'No data available.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.textL,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Text(
                  '${widget.inbound}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: _C.emerald,
                    height: 1,
                  ),
                ),
          const SizedBox(height: 24),

          // -- Bar chart — exact pixel budget prevents overflow ------
          // Budget: 16 label + 2 gap + 95 bar + 5 gap + 14 day = 132px
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                const double maxBarH = 95.0;
                final pct = maxVal > 0 ? data[i] / maxVal : 0.0;
                final isActive = sel == i;
                final barH = (maxBarH * pct).clamp(0.0, maxBarH);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _selectedBar = _selectedBar == i ? null : i,
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Value label — fixed 16px
                            SizedBox(
                              height: 16,
                              child: widget.inbound > 0
                                  ? Center(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isActive ? 3 : 0,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? _C.emerald
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          data[i].round().toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: isActive
                                                ? Colors.white
                                                : _C.textL,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 2),
                            // Bar — exact calculated height, no clamp needed
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              height: barH,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _C.emerald
                                    : _C.emerald.withValues(alpha: 0.45),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                border: isActive
                                    ? Border.all(color: _C.emerald, width: 2)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Day label — fixed 14px
                            SizedBox(
                              height: 14,
                              child: Text(
                                days[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isActive ? _C.emerald : _C.textL,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // -- Inline info panel — shown when a bar is selected -----
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: sel != null
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: sel != null
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _C.emerald.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _C.emerald.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.emerald,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                days[sel],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _C.emerald,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data[sel].round()} containers received',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _C.textM,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${((data[sel] / widget.inbound) * 100).round()}% of weekly total',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textL,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          data[sel].round().toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _C.emerald,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// -- Outbound Card (line graph — interactive) ----------------------------------
class _OutboundCard extends StatefulWidget {
  final int outbound;
  final List<int> dailyData;
  final List<String> dayLabels;
  const _OutboundCard({
    required this.outbound,
    required this.dailyData,
    required this.dayLabels,
  });

  @override
  State<_OutboundCard> createState() => _OutboundCardState();
}

class _OutboundCardState extends State<_OutboundCard> {
  int? _selectedPoint;

  @override
  void didUpdateWidget(_OutboundCard old) {
    super.didUpdateWidget(old);
    if (old.outbound != widget.outbound) _selectedPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    // Real daily data — actual outbound counts per day
    final data = widget.dailyData.map((v) => v.toDouble()).toList();
    final days = widget.dayLabels;
    final sel = _selectedPoint;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // -- Header ----------------------------------------------
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: _C.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Outbound',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    Text(
                      'Tap a point to see daily details',
                      style: TextStyle(fontSize: 11, color: _C.textL),
                    ),
                  ],
                ),
              ),
              if (sel != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedPoint = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _C.textL,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // -- Big count --------------------------------------------
          widget.outbound == 0
              ? const Text(
                  'No data available.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _C.textL,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Text(
                  '${widget.outbound}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: _C.red,
                    height: 1,
                  ),
                ),
          const SizedBox(height: 24),

          // -- Line graph with tap targets --------------------------
          SizedBox(
            height: 130,
            child: widget.outbound == 0
                ? const Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: _C.textL, fontSize: 24),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final maxV = data
                          .reduce((a, b) => a > b ? a : b)
                          .clamp(1.0, double.infinity);
                      final step = w / 6;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Line graph fills entire area
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _LineGraphPainter(
                                values: data,
                                selectedIndex: sel,
                              ),
                            ),
                          ),
                          // Tap targets — clamped to stay within bounds
                          ...List.generate(7, (i) {
                            final dx = (i * step).clamp(0.0, w - 36);
                            final rawDy = h - (data[i] / maxV) * h;
                            final dy = rawDy.clamp(0.0, h - 36);
                            final isS = sel == i;
                            return Positioned(
                              left: dx,
                              top: dy,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedPoint = sel == i ? null : i,
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isS
                                          ? _C.red.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: isS
                                          ? Border.all(
                                              color: _C.red.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // -- Day labels -------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              7,
              (i) => Text(
                days[i],
                style: TextStyle(
                  fontSize: 10,
                  color: sel == i ? _C.red : _C.textL,
                  fontWeight: sel == i ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),

          // -- Inline info panel ------------------------------------
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: sel != null
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: sel != null
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _C.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                days[sel],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _C.red,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data[sel].round()} containers dispatched',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _C.textM,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${((data[sel] / widget.outbound) * 100).round()}% of weekly total',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.textL,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          data[sel].round().toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _C.red,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LineGraphPainter extends CustomPainter {
  final List<double> values;
  final int? selectedIndex;
  const _LineGraphPainter({required this.values, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    final linePaint = Paint()
      ..color = const Color(0xFFFF2800)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF2800).withValues(alpha: 0.2),
          const Color(0xFFFF2800).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final n = values.length;
    final step = size.width / (n - 1);

    Offset point(int i) =>
        Offset(i * step, size.height - (values[i] / maxV) * size.height);

    // Fill path
    final fillPath = Path()..moveTo(0, size.height);
    for (int i = 0; i < n; i++) {
      final p = point(i);
      if (i == 0) {
        fillPath.lineTo(p.dx, p.dy);
      } else {
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.lineTo((n - 1) * step, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Line path
    final linePath = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < n; i++) {
      linePath.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()
      ..color = const Color(0xFFFF2800)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final isSelected = i == selectedIndex;
      // White fill
      canvas.drawCircle(
        point(i),
        isSelected ? 6 : 3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      // Colored ring
      canvas.drawCircle(point(i), isSelected ? 6 : 2, dotPaint);
      // Extra outer ring for selected
      if (isSelected) {
        canvas.drawCircle(
          point(i),
          10,
          Paint()
            ..color = const Color(0xFFFF2800).withOpacity(0.2)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          point(i),
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(point(i), 5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_LineGraphPainter old) =>
      old.values != values || old.selectedIndex != selectedIndex;
}

// -- Empty Containers Breakdown Card -----------------------------------------
class _EmptyBreakdownCard extends StatefulWidget {
  final int foodGrade, nonFoodGrade, repairable, frmd, total;
  final List<ContainerModel> allEmpty;
  final void Function(String label, List<ContainerModel> list)? onTapType;
  const _EmptyBreakdownCard({
    required this.foodGrade,
    required this.nonFoodGrade,
    required this.repairable,
    required this.frmd,
    required this.total,
    this.allEmpty = const [],
    this.onTapType,
  });

  @override
  State<_EmptyBreakdownCard> createState() => _EmptyBreakdownCardState();
}

class _EmptyBreakdownCardState extends State<_EmptyBreakdownCard> {
  int? _selectedSlice; // 0=Food, 1=NonFood, 2=Repair, 3=FRMD

  static const _sliceNames = [
    'Food Grade',
    'Non-Food Grade',
    'Repairable',
    'FRMD',
  ];
  static const _sliceColors = [_C.emeraldL, _C.orange, _C.blue, _C.purple];

  List<ContainerModel> _filterForSlice(int idx) {
    return widget.allEmpty.where((c) {
      final d = c.containerDesc?.toLowerCase() ?? '';
      switch (idx) {
        case 0:
          return d.contains('food') && !d.contains('non');
        case 1:
          return d.contains('non') && d.contains('food');
        case 2:
          return d.contains('repair');
        case 3:
          return d.contains('frmd');
        default:
          return false;
      }
    }).toList();
  }

  List<int> get _values => [
    widget.foodGrade,
    widget.nonFoodGrade,
    widget.repairable,
    widget.frmd,
  ];

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final hasData = widget.total > 0;
    final sel = _selectedSlice;

    return _FlowCard(
      title: 'Empty Containers',
      icon: Icons.pie_chart_outline_rounded,
      iconColor: _C.orange,
      children: [
        // -- Pie + Legend row ----------------------------------
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pie — GestureDetector wraps it, tap position maps to slice
            GestureDetector(
              onTapUp: (details) {
                if (!hasData) return;
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                // Pie is 120×120, centered in its SizedBox
                final localPos = details.localPosition;
                // Compute centre of pie widget (approximate — 120px wide, positioned left)
                const cx = 60.0, cy = 60.0;
                final dx = localPos.dx - cx;
                final dy = localPos.dy - cy;
                // Determine angle (0 = top, clockwise)
                double angle = (math.atan2(dy, dx) + math.pi / 2);
                if (angle < 0) angle += 2 * math.pi;
                // Map angle to slice index
                final total = values.fold(0, (a, b) => a + b).toDouble();
                if (total == 0) return;
                double cursor = 0;
                for (int i = 0; i < values.length; i++) {
                  final sweep = (values[i] / total) * 2 * math.pi;
                  if (angle <= cursor + sweep) {
                    setState(
                      () => _selectedSlice = (_selectedSlice == i ? null : i),
                    );
                    return;
                  }
                  cursor += sweep;
                }
                setState(() => _selectedSlice = null);
              },
              child: MouseRegion(
                cursor: hasData ? SystemMouseCursors.click : MouseCursor.defer,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: hasData
                      ? CustomPaint(
                          painter: _InteractivePiePainter(
                            values: values.map((v) => v.toDouble()).toList(),
                            colors: _sliceColors,
                            selectedIndex: sel,
                          ),
                          child: Center(
                            child: sel != null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${values[sel]}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: _sliceColors[sel],
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        '${(values[sel] / widget.total * 100).round()}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: _C.textL,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '${widget.total}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _C.textD,
                                    ),
                                  ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No data\navailable.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: _C.textL,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // -- Legend rows -----------------------------------------
            Expanded(
              child: Column(
                children: List.generate(4, (i) {
                  final lbl = _sliceNames[i];
                  final val = values[i];
                  final clr = _sliceColors[i];
                  final pct = widget.total > 0
                      ? (val / widget.total * 100).round()
                      : 0;
                  final isS = sel == i;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSlice = isS ? null : i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isS
                              ? clr.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isS
                                ? clr.withValues(alpha: 0.4)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: isS ? 10 : 8,
                              height: isS ? 10 : 8,
                              decoration: BoxDecoration(
                                color: clr,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lbl,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isS ? clr : _C.textM,
                                  fontWeight: isS
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '$val',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: clr,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: _C.textL,
                              ),
                            ),
                            if (isS) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 9,
                                color: clr.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ), // end Row(pie+legend)
        // -- Info strip — fixed height, no card resize ---------
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: sel != null
              ? Container(
                  key: ValueKey(sel),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _sliceColors[sel].withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _sliceColors[sel].withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _sliceColors[sel],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.pie_chart_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_sliceNames[sel]} — ${values[sel]} containers (${(values[sel] / widget.total * 100).round()}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _sliceColors[sel],
                          ),
                        ),
                      ),
                      Text(
                        '${values[sel]}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _sliceColors[sel],
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('empty'),
                  height: 38,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Tap a slice to see details',
                    style: TextStyle(fontSize: 11, color: _C.textL),
                  ),
                ),
        ),
      ],
    );
  }
}

// -- Laden Containers Card ------------------------------------------------------
class _LadenCard extends StatelessWidget {
  final int laden, tempoGrounding;
  final List<ContainerModel> allLaden;
  final void Function(String label, List<ContainerModel> list)? onTap;
  const _LadenCard({required this.laden, required this.tempoGrounding, this.allLaden = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final tempoList = allLaden.where((c) {
      final d = c.containerDesc?.toLowerCase() ?? '';
      return d.contains('tempo') || d.contains('grounding');
    }).toList();
    return _FlowCard(
      title: 'Laden Containers',
      icon: Icons.check_circle_outline_rounded,
      iconColor: _C.blue,
      children: [
        _FlowRow(
          label: 'Total Laden',
          value: laden,
          color: _C.blue,
          icon: Icons.inventory_2_rounded,
          subtitle: 'Including all laden types',
          onTap: onTap != null
              ? () => onTap!('Total Laden Containers', allLaden)
              : null,
        ),
        const SizedBox(height: 12),
        _FlowRow(
          label: 'Tempo Grounding',
          value: tempoGrounding,
          color: _C.purple,
          icon: Icons.anchor_rounded,
          subtitle: 'Laden — tempo grounding',
          onTap: onTap != null
              ? () => onTap!('Tempo Grounding Containers', tempoList)
              : null,
        ),
      ],
    );
  }
}

// -- Yard Flow Card -------------------------------------------------------------
class _YardFlowCard extends StatelessWidget {
  final int yardIn, yardOut;
  final List<ContainerModel> allInYard;
  final List<ContainerModel> allOutYard;
  final void Function(String label, List<ContainerModel> list)? onTap;
  const _YardFlowCard({required this.yardIn, required this.yardOut, this.allInYard = const [], this.allOutYard = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = (yardIn + yardOut).clamp(1, 999999);
    return _FlowCard(
      title: 'Total in Yard',
      icon: Icons.warehouse_rounded,
      iconColor: _C.emerald,
      children: [
        _FlowRow(
          label: 'Container Yard In',
          value: yardIn,
          color: _C.emerald,
          icon: Icons.login_rounded,
          subtitle: 'Currently in yard',
          onTap: onTap != null
              ? () => onTap!('Container Yard In', allInYard)
              : null,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: yardIn / total,
            minHeight: 6,
            backgroundColor: _C.red.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(_C.emerald),
          ),
        ),
        const SizedBox(height: 12),
        _FlowRow(
          label: 'Container Yard Out',
          value: yardOut,
          color: _C.red,
          icon: Icons.logout_rounded,
          subtitle: 'Moved out of yard',
          onTap: onTap != null
              ? () => onTap!('Container Yard Out', allOutYard)
              : null,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: yardOut / total,
            minHeight: 6,
            backgroundColor: _C.red.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(_C.red),
          ),
        ),
      ],
    );
  }
}

// -- Shared Flow Card shell -----------------------------------------------------
class _FlowCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _FlowCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.textD,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

// -- Shared Flow Row ------------------------------------------------------------
class _FlowRow extends StatelessWidget {
  final String label, subtitle;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _FlowRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: onTap != null ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.textM,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9.5, color: _C.textL),
                  ),
                ],
              ),
            ),
            value == 0
                ? const Text(
                    'No data\navailable.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _C.textL,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: color,
                          height: 1,
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

// -- Interactive Pie Chart Painter --------------------------------------------
class _InteractivePiePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final int? selectedIndex;

  const _InteractivePiePainter({
    required this.values,
    required this.colors,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 8;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi;
      final isSelected = i == selectedIndex;
      // Selected slice pops out slightly
      final offset = isSelected ? 6.0 : 0.0;
      final midAngle = startAngle + sweep / 2;
      final ox = math.cos(midAngle) * offset;
      final oy = math.sin(midAngle) * offset;

      final paint = Paint()
        ..color = isSelected ? colors[i] : colors[i].withOpacity(0.65)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + ox, cy + oy), radius: r),
        startAngle,
        sweep,
        true,
        paint,
      );

      // Stroke for selected slice
      if (isSelected) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx + ox, cy + oy), radius: r),
          startAngle,
          sweep,
          true,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      startAngle += sweep;
    }

    // Donut hole
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.52,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_InteractivePiePainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.selectedIndex != selectedIndex;
}

// -- Simple Pie Chart Painter ---------------------------------------------------
class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 6;
    double startAngle = -3.14159265 / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * 3.14159265;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweep,
        true,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill,
      );
      startAngle += sweep;
    }
    // White hole for donut effect
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.55,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.values != values || old.colors != colors;
}

// -- Dashboard Filter Bar -----------------------------------------------------
class _DashboardFilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery, filterPort, filterStatus;
  final List<Port> portList;
  final ValueChanged<String> onSearchChanged, onPortChanged, onStatusChanged;
  final VoidCallback onClear;
  final int resultCount;

  const _DashboardFilterBar({
    required this.searchCtrl,
    required this.searchQuery,
    required this.filterPort,
    required this.filterStatus,
    required this.portList,
    required this.onSearchChanged,
    required this.onPortChanged,
    required this.onStatusChanged,
    required this.onClear,
    required this.resultCount,
  });

  bool get _isActive =>
      searchQuery.isNotEmpty || filterPort != 'All' || filterStatus != 'All';

  @override
  Widget build(BuildContext context) {
    // Only Cebu and Manila are active — filter port options accordingly
    const enabledPorts = ['cebu', 'manila'];
    final portOptions = [
      'All',
      ...portList
          .where((p) {
            final n = p.portDesc.toLowerCase();
            return enabledPorts.any((e) => n.contains(e));
          })
          .map((p) => p.portDesc),
    ];
    const statusOptions = ['All', 'Laden', 'Empty', 'In Transit', 'Moved Out'];

    final searchField = Container(
      height: 42,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: searchQuery.isNotEmpty ? _C.emerald : _C.border,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearchChanged,
        style: const TextStyle(fontSize: 13, color: _C.textD),
        decoration: InputDecoration(
          hintText: 'Search by container no. or type…',
          hintStyle: const TextStyle(color: _C.textL, fontSize: 12),
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: _C.textL,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: _C.textL,
                  ),
                  onPressed: () {
                    searchCtrl.clear();
                    onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                )
              : null,
        ),
      ),
    );

    final dropdowns = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactDropdown(
          icon: Icons.anchor_rounded,
          label: 'Port',
          value: filterPort,
          options: portOptions,
          onChanged: onPortChanged,
          active: filterPort != 'All',
        ),
        const SizedBox(width: 10),
        _CompactDropdown(
          icon: Icons.filter_list_rounded,
          label: 'Status',
          value: filterStatus,
          options: statusOptions,
          onChanged: onStatusChanged,
          active: filterStatus != 'All',
        ),
        if (_isActive) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.emerald.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: _C.emerald,
                ),
                const SizedBox(width: 6),
                Text(
                  '$resultCount result${resultCount != 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _C.emerald,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _C.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.red.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 14, color: _C.red),
                    SizedBox(width: 5),
                    Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: _C.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Stack search above dropdowns on narrow widths
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchField, const SizedBox(height: 10), dropdowns],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: searchField),
            const SizedBox(width: 10),
            dropdowns,
          ],
        );
      },
    );
  }
}

// -- Compact Dropdown ----------------------------------------------------------
class _CompactDropdown extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool active;

  const _CompactDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? _C.emerald.withValues(alpha: 0.08) : _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? _C.emerald : _C.border,
          width: active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? _C.emerald : _C.textL),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: active ? _C.emerald : _C.textL,
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? _C.emerald : _C.textM,
              ),
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o == 'All' ? '$label: All' : o,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active && o == value ? _C.emerald : _C.textD,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -- Customer Summary Card -----------------------------------------------------
class _CustomerSummaryCard extends StatelessWidget {
  final Map<int, int> containersByCustomer;
  final int totalContainers;
  final List<ContainerModel> allContainers;
  final void Function(int customerId, List<ContainerModel> list)? onTapCustomer;
  const _CustomerSummaryCard({
    required this.containersByCustomer,
    required this.totalContainers,
    this.allContainers = const [],
    this.onTapCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = containersByCustomer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: _C.purple, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Customer Container Distribution',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.textD,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _C.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${containersByCustomer.length} customers',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...top.map((e) {
            final pct = totalContainers > 0 ? e.value / totalContainers : 0.0;
            final custContainers = allContainers
                .where((c) => c.customerId == e.key)
                .toList();
            return MouseRegion(
              cursor: onTapCustomer != null
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: GestureDetector(
                onTap: onTapCustomer != null
                    ? () => onTapCustomer!(e.key, custContainers)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _C.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'C${e.key}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: _C.purple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Customer #${e.key}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _C.textM,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value} containers',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _C.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: _C.textL,
                            ),
                          ),
                          if (onTapCustomer != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: _C.purple.withValues(alpha: 0.5),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: _C.purple.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation(_C.purple),
                        ),
                      ),
                    ],
                  ),
                ), // Padding
              ), // GestureDetector
            ); // MouseRegion
          }),
          if (sorted.length > 5) ...[
            const SizedBox(height: 4),
            Text(
              '+${sorted.length - 5} more customers',
              style: const TextStyle(fontSize: 11, color: _C.textL),
            ),
          ],
        ],
      ),
    );
  }
}

// -- Filtered Container List ---------------------------------------------------
class _FilteredContainerList extends StatelessWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _FilteredContainerList({
    required this.containers,
    required this.portList,
  });

  String _portName(int portId) {
    try {
      return portList.firstWhere((p) => p.portId == portId).portDesc;
    } catch (_) {
      return 'Port $portId';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: _C.textL),
              SizedBox(height: 12),
              Text(
                'No containers match the current filter.',
                style: TextStyle(color: _C.textL, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final shown = containers.take(20).toList();
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: _C.navBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'CONTAINER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'PORT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'STATUS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'TYPE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${containers.length} results',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          // Rows
          ...shown.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            final isLaden = c.statusId == 1;
            final statusColor = isLaden ? _C.blue : _C.red;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: i.isEven ? _C.surface : _C.bg,
                border: Border(
                  bottom: BorderSide(
                    color: _C.border,
                    width: i < shown.length - 1 ? 1 : 0,
                  ),
                ),
                borderRadius: i == shown.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(14))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.containerNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.textD,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _portName(c.currentPortId),
                      style: const TextStyle(fontSize: 11, color: _C.textM),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isLaden ? 'Laden' : 'Empty',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        c.containerDesc ?? '-',
                        style: const TextStyle(fontSize: 11, color: _C.textL),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (containers.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  '+ ${containers.length - 20} more results — refine your filter',
                  style: const TextStyle(fontSize: 11, color: _C.textL),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -- Footer --------------------------------------------------------------------
class _Footer extends StatelessWidget {
  final int year;
  const _Footer({required this.year});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: _C.navBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _C.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/gothong_logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gothong Southern  ·  Container Management System  ·  v1.0.0',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '© $year All rights reserved',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// -- Container List Dialog -----------------------------------------------------
class _ListDialog extends StatelessWidget {
  final String title;
  final List<ContainerModel> containers;
  final Color accent;
  const _ListDialog({
    required this.title,
    required this.containers,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) {
    final laden = containers.where((c) => c.statusId == 1).length;
    final empty = containers.where((c) => c.statusId == 2).length;
    final ft20 = containers.where((c) => c.containerSizeId == 1).length;
    final ft40 = containers.where((c) => c.containerSizeId == 2).length;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: accent == _C.gold ? _C.textD : Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accent == _C.gold ? _C.textD : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${containers.length} containers',
                          style: TextStyle(
                            color: (accent == _C.gold ? _C.textD : Colors.white)
                                .withOpacity(0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: accent == _C.gold ? _C.textD : Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _MiniStat('Laden', '$laden', _C.gold),
                  const SizedBox(width: 10),
                  _MiniStat('Empty', '$empty', _C.red),
                  const SizedBox(width: 10),
                  _MiniStat('20ft', '$ft20', _C.emerald),
                  const SizedBox(width: 10),
                  _MiniStat('40ft', '$ft40', _C.blue),
                ],
              ),
            ),
            // List
            Flexible(
              child: containers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No containers found',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: containers.length,
                      itemBuilder: (_, i) {
                        final c = containers[i];
                        final isLaden = c.statusId == 1;
                        final sc = isLaden ? _C.gold : _C.red;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: sc.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sc.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: sc,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.containerNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _C.textD,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sc.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isLaden ? 'Laden' : 'Empty',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: sc,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _C.emerald.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.containerSizeId == 1
                                      ? '20ft'
                                      : c.containerSizeId == 2
                                      ? '40ft'
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _C.emerald,
                                  ),
                                ),
                              ),
                            ],
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

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _C.textL,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Report Dialog -------------------------------------------------------------
class _ReportDialog extends StatefulWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ReportDialog({required this.containers, required this.portList});
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  String _days(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
      return '$d day${d != 1 ? "s" : ""}';
    } catch (_) {
      return '—';
    }
  }

  List<ContainerModel> _filter(String type) {
    final all = widget.containers;
    switch (type) {
      case 'laden':
        return all.where((c) => c.statusId == 1).toList();
      case 'empty':
        return all.where((c) => c.statusId == 2).toList();
      case 'mtfood':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).toList();
      case 'fsl':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —');
        }).toList();
      case 'strip':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).toList();
      case 'nonfood':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).toList();
      default:
        return all;
    }
  }

  Future<void> _print(BuildContext ctx) async {
    final all = widget.containers;
    final laden = _filter('laden');
    final empty = _filter('empty');
    final mtFood = _filter('mtfood');
    final fsl = _filter('fsl');
    final strip = _filter('strip');
    final nonFood = _filter('nonfood');
    final dateStr = _fmt(DateTime.now().toIso8601String());
    final pdf = pw.Document();

    pw.Widget hdr() => pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey900),
      child: pw.Column(
        children: [
          pw.Text(
            'GOTHONG SOUTHERN — CONTAINER REPORT',
            style: pw.TextStyle(
              color: PdfColors.yellow,
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Date: $dateStr',
            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              for (final s in [
                ('Total', '${all.length}', PdfColors.green800),
                ('Laden', '${laden.length}', PdfColors.yellow800),
                ('MT Food', '${mtFood.length}', PdfColors.green700),
                ('FSL', '${fsl.length}', PdfColors.blue800),
                ('Stripping', '${strip.length}', PdfColors.orange800),
                ('MT Non-Food', '${nonFood.length}', PdfColors.purple800),
                ('Empty', '${empty.length}', PdfColors.red700),
                ('Ports', '${widget.portList.length}', PdfColors.blueGrey700),
              ]) ...[
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 4),
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: s.$3,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          s.$2,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          s.$1,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    pw.Widget tblHdr(List<String> cols) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
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
                    fontSize: 8,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    pw.Widget tblRow(int i, ContainerModel c) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 7),
      color: i.isEven ? PdfColors.grey100 : PdfColors.white,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              c.containerNumber,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.statusId == 1 ? 'Laden' : 'Empty',
              style: pw.TextStyle(
                fontSize: 8,
                color: c.statusId == 1 ? PdfColors.yellow800 : PdfColors.red700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.containerSizeId == 1
                  ? '20ft'
                  : c.containerSizeId == 2
                  ? '40ft'
                  : '—',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.moveConfirmedDate ?? c.createdDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.moveConfirmedDate ?? c.createdDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );

    final cols = [
      'CONTAINER NO.',
      'STATUS',
      'SIZE',
      'DATE IN YARD',
      'DAYS IN YARD',
      'DATE MOVED',
      'DAYS IN SLOT',
    ];
    for (final s in [
      ('ALL CONTAINERS', all),
      ('LADEN', laden),
      ('MT FOOD', mtFood),
      ('FSL', fsl),
      ('STRIPPING', strip),
      ('MT NON-FOOD', nonFood),
      ('EMPTY', empty),
    ]) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(22),
          header: (_) => hdr(),
          build: (_) => [
            pw.SizedBox(height: 10),
            pw.Text(
              '${s.$1} (${s.$2.length})',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 5),
            tblHdr(cols),
            ...s.$2.asMap().entries.map((e) => tblRow(e.key, e.value)),
          ],
        ),
      );
    }
    // Ports page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => hdr(),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'PORTS SUMMARY (${widget.portList.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          tblHdr(['PORT NAME', 'TOTAL', 'LADEN', 'EMPTY', '20FT', '40FT']),
          ...widget.portList.asMap().entries.map((e) {
            final pc = all
                .where((c) => c.currentPortId == e.value.portId)
                .toList();
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 7,
              ),
              color: e.key.isEven ? PdfColors.grey100 : PdfColors.white,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      e.value.portDesc,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 1).length}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.yellow800,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 2).length}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 1).length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 2).length}',
                      style: const pw.TextStyle(fontSize: 8),
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
    final laden = _filter('laden');
    final empty = _filter('empty');
    final mtFood = _filter('mtfood');
    final fsl = _filter('fsl');
    final strip = _filter('strip');
    final nonFood = _filter('nonfood');
    final date = _fmt(DateTime.now().toIso8601String());

    final tiles = [
      ('Total', '${all.length}', _C.emerald),
      ('Laden', '${laden.length}', _C.gold),
      ('MT Food', '${mtFood.length}', _C.emeraldL),
      ('FSL', '${fsl.length}', _C.blue),
      ('Stripping', '${strip.length}', _C.orange),
      ('MT Non-Food', '${nonFood.length}', _C.purple),
      ('Empty', '${empty.length}', _C.red),
      ('Ports', '${widget.portList.length}', Colors.blueGrey),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.summarize_rounded,
                        color: _C.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GOTHONG SOUTHERN — CONTAINER REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Generated: $date',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _print(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _C.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.print_rounded,
                                color: _C.textD,
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Print',
                                style: TextStyle(
                                  color: _C.textD,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
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
                          Icons.close_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: tiles
                          .map(
                            (t) => Container(
                              width: 78,
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                vertical: 7,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: t.$3,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    t.$2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    t.$1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _tab,
                    indicatorColor: _C.gold,
                    labelColor: _C.gold,
                    unselectedLabelColor: Colors.white38,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                    tabs: const [
                      Tab(text: 'ALL'),
                      Tab(text: 'LADEN'),
                      Tab(text: 'MT FOOD'),
                      Tab(text: 'FSL'),
                      Tab(text: 'STRIPPING'),
                      Tab(text: 'MT NON-FOOD'),
                      Tab(text: 'EMPTY'),
                      Tab(text: 'PORTS'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ReportTable(containers: all, fmt: _fmt, days: _days),
                  _ReportTable(containers: laden, fmt: _fmt, days: _days),
                  _ReportTable(containers: mtFood, fmt: _fmt, days: _days),
                  _ReportTable(containers: fsl, fmt: _fmt, days: _days),
                  _ReportTable(containers: strip, fmt: _fmt, days: _days),
                  _ReportTable(containers: nonFood, fmt: _fmt, days: _days),
                  _ReportTable(containers: empty, fmt: _fmt, days: _days),
                  _ReportPortsTable(portList: widget.portList, containers: all),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Report Table --------------------------------------------------------------
class _ReportTable extends StatelessWidget {
  final List<ContainerModel> containers;
  final String Function(String?) fmt, days;
  const _ReportTable({
    required this.containers,
    required this.fmt,
    required this.days,
  });

  static Widget _th(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 9),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        letterSpacing: 0.3,
      ),
    ),
  );

  static Widget _td(String t, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        child: Text(
          t,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style ?? const TextStyle(fontSize: 11.5, color: _C.textD),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Text(
            'No data available.',
            style: TextStyle(color: _C.textL, fontSize: 13),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '${containers.length} record${containers.length != 1 ? "s" : ""} found',
              style: const TextStyle(
                fontSize: 10.5,
                color: _C.textL,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade200,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            columnWidths: const {
              0: FixedColumnWidth(32),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(0.8),
              4: FlexColumnWidth(1.8),
              5: FlexColumnWidth(1.4),
              6: FlexColumnWidth(1.8),
              7: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
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
              ...containers.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final isLaden = c.statusId == 1;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8F9FA),
                  ),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(fontSize: 10.5, color: _C.textL),
                    ),
                    _td(
                      c.containerNumber,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 9,
                      ),
                      child: Text(
                        isLaden ? 'Laden' : 'Empty',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isLaden
                              ? Colors.amber.shade800
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                    _td(
                      c.containerSizeId == 1
                          ? '20ft'
                          : c.containerSizeId == 2
                          ? '40ft'
                          : '—',
                      center: true,
                    ),
                    _td(fmt(c.yardEntryDate ?? c.createdDate)),
                    _td(days(c.yardEntryDate ?? c.createdDate), center: true),
                    _td(fmt(c.moveConfirmedDate ?? c.createdDate)),
                    _td(
                      days(c.moveConfirmedDate ?? c.createdDate),
                      center: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// -- Report Ports Table --------------------------------------------------------
class _ReportPortsTable extends StatelessWidget {
  final List<Port> portList;
  final List<ContainerModel> containers;
  const _ReportPortsTable({required this.portList, required this.containers});

  static Widget _th(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 9),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        letterSpacing: 0.3,
      ),
    ),
  );
  static Widget _td(String t, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        child: Text(
          t,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style ?? const TextStyle(fontSize: 11.5, color: _C.textD),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (portList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Text(
            'No data available.',
            style: TextStyle(color: _C.textL, fontSize: 13),
          ),
        ),
      );
    }
    int gTotal = 0, gLaden = 0, gEmpty = 0, g20 = 0, g40 = 0;
    final data = portList.map((p) {
      final pc = containers.where((c) => c.currentPortId == p.portId).toList();
      final l = pc.where((c) => c.statusId == 1).length;
      final e = pc.where((c) => c.statusId == 2).length;
      final f20 = pc.where((c) => c.containerSizeId == 1).length;
      final f40 = pc.where((c) => c.containerSizeId == 2).length;
      gTotal += pc.length;
      gLaden += l;
      gEmpty += e;
      g20 += f20;
      g40 += f40;
      return (
        port: p,
        total: pc.length,
        laden: l,
        empty: e,
        ft20: f20,
        ft40: f40,
      );
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '${portList.length} port${portList.length != 1 ? "s" : ""} active',
              style: const TextStyle(
                fontSize: 10.5,
                color: _C.textL,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade200,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            columnWidths: const {
              0: FixedColumnWidth(32),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.2),
              6: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
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
              ...data.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8F9FA),
                  ),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(fontSize: 10.5, color: _C.textL),
                    ),
                    _td(
                      d.port.portDesc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _td(
                      '${d.total}',
                      center: true,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _td(
                      '${d.laden}',
                      center: true,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    _td(
                      '${d.empty}',
                      center: true,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                    _td('${d.ft20}', center: true),
                    _td('${d.ft40}', center: true),
                  ],
                );
              }),
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF0F4F8)),
                children: [
                  _td('', center: true),
                  _td(
                    'TOTAL',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _C.textD,
                    ),
                  ),
                  _td(
                    '$gTotal',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$gLaden',
                    center: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  _td(
                    '$gEmpty',
                    center: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade700,
                    ),
                  ),
                  _td(
                    '$g20',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$g40',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
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
}

// -- Reports Page Content ------------------------------------------------------
class _ReportsPageContent extends StatelessWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ReportsPageContent({required this.containers, required this.portList});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: _C.orange,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate Container Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Export all container data to PDF format',
                      style: TextStyle(fontSize: 13, color: _C.textL),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => _ReportDialog(
                      containers: containers,
                      portList: portList,
                    ),
                  );
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('Generate PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: _C.border),
          const SizedBox(height: 24),
          Text(
            'Report Summary',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.textD,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ReportStat(
                label: 'Total Containers',
                value: '${containers.length}',
                icon: Icons.inventory_2_rounded,
                color: _C.emerald,
              ),
              _ReportStat(
                label: 'Laden',
                value: '${containers.where((c) => c.statusId == 1).length}',
                icon: Icons.check_circle_rounded,
                color: _C.gold,
              ),
              _ReportStat(
                label: 'Empty',
                value: '${containers.where((c) => c.statusId == 2).length}',
                icon: Icons.radio_button_unchecked_rounded,
                color: _C.red,
              ),
              _ReportStat(
                label: 'Active Ports',
                value: '${portList.length}',
                icon: Icons.anchor_rounded,
                color: _C.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ReportStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: _C.textM)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Notifications Page Content ------------------------------------------------
class _NotificationsPageContent extends StatefulWidget {
  const _NotificationsPageContent();

  @override
  State<_NotificationsPageContent> createState() =>
      _NotificationsPageContentState();
}

class _NotificationsPageContentState extends State<_NotificationsPageContent> {
  NotifType? _filter;

  @override
  void initState() {
    super.initState();
    NotificationService().addListener(_rebuild);
  }

  @override
  void dispose() {
    NotificationService().removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  List<AppNotification> _filtered(List<AppNotification> all) {
    if (_filter == null) return all;
    return all.where((n) => n.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService();
    final all = svc.notifications;
    final shown = _filtered(all);
    final unread = svc.unreadCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: _C.emerald,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unread > 0
                          ? '$unread unread notification${unread != 1 ? "s" : ""}'
                          : 'All caught up!',
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0 ? _C.red : _C.textL,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                TextButton.icon(
                  onPressed: () => svc.markAllRead(),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark all read'),
                  style: TextButton.styleFrom(foregroundColor: _C.emerald),
                ),
              if (all.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => svc.clearAll(),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(foregroundColor: _C.red),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          // Filter tabs
          if (all.isNotEmpty)
            Row(
              children: [
                _FilterChipPage(
                  label: 'All',
                  count: all.length,
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                _FilterChipPage(
                  label: 'Movements',
                  count: all.where((n) => n.type == NotifType.movement).length,
                  selected: _filter == NotifType.movement,
                  onTap: () => setState(
                    () => _filter = _filter == NotifType.movement
                        ? null
                        : NotifType.movement,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChipPage(
                  label: 'Move Out',
                  count: all.where((n) => n.type == NotifType.moveOut).length,
                  selected: _filter == NotifType.moveOut,
                  onTap: () => setState(
                    () => _filter = _filter == NotifType.moveOut
                        ? null
                        : NotifType.moveOut,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(color: _C.border),
          const SizedBox(height: 16),
          // Notifications list
          if (shown.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 64,
                      color: _C.textL.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter != null
                          ? 'No notifications in this category'
                          : 'No notifications yet',
                      style: TextStyle(fontSize: 16, color: _C.textL),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(shown.length, (i) {
                final n = shown[i];
                return _NotifTilePage(
                  notif: n,
                  onTap: () {
                    svc.markRead(n.id);
                    showDialog(
                      context: context,
                      builder: (_) => NotifDetailDialog(notif: n),
                    );
                  },
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _FilterChipPage extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipPage({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _C.emerald : _C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _C.emerald : _C.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _C.textD,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : _C.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _C.emerald,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifTilePage extends StatefulWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifTilePage({required this.notif, required this.onTap});

  @override
  State<_NotifTilePage> createState() => _NotifTilePageState();
}

class _NotifTilePageState extends State<_NotifTilePage> {
  bool _hovered = false;

  Color get _accentColor {
    switch (widget.notif.type) {
      case NotifType.movement:
        return _C.emerald;
      case NotifType.moveOut:
        return _C.blue;
    }
  }

  IconData get _icon {
    switch (widget.notif.type) {
      case NotifType.movement:
        return Icons.check_circle_rounded;
      case NotifType.moveOut:
        return Icons.local_shipping_rounded;
    }
  }

  String get _typeLabel {
    switch (widget.notif.type) {
      case NotifType.movement:
        return 'Movement';
      case NotifType.moveOut:
        return 'Move Out';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    final isRead = widget.notif.isRead;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withOpacity(0.05)
                : isRead
                ? Colors.white
                : color.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? _C.border : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(widget.notif.timestamp),
                          style: TextStyle(fontSize: 11, color: _C.textL),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.notif.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.notif.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: _C.textM,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
