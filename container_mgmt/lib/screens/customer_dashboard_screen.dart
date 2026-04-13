import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  final Session session;
  const CustomerDashboardScreen({super.key, required this.session});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboardScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  ContainerModel? _result;
  bool _searching = false;
  bool _searched = false;
  String _error = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searched = false;
      _error = '';
      _result = null;
    });
    try {
      final container = await _api.searchContainer(q);
      setState(() {
        _result = container;
        _searched = true;
        _searching = false;
        if (container == null) _error = 'No container found for "$q".';
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _searched = true;
        _error = 'Could not reach the server. Check your connection.';
      });
    }
  }

  void _logout() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeBanner(),
                  const SizedBox(height: 28),
                  _buildSearchSection(),
                  const SizedBox(height: 24),
                  if (_searching)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(
                          color: AppColors.yellow,
                        ),
                      ),
                    )
                  else if (_searched && _error.isNotEmpty)
                    _buildError()
                  else if (_result != null)
                    _buildContainerResult(_result!)
                  else if (!_searched)
                    _buildHint(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: AppColors.yellow,
      boxShadow: [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          children: [
            Image.asset(
              'assets/gothong_logo.png',
              height: 38,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'CUSTOMER PORTAL',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.session.fullName,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  widget.session.role,
                  style: TextStyle(
                    color: AppColors.green.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _logout,
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
                      Icons.logout_rounded,
                      color: AppColors.yellow,
                      size: 15,
                    ),
                    SizedBox(width: 5),
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

  // ── Welcome Banner ───────────────────────────────────────────────────────

  Widget _buildWelcomeBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.green.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.green,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${widget.session.fullName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track your containers using the search below.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Search ───────────────────────────────────────────────────────────────

  Widget _buildSearchSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('TRACK YOUR CONTAINER'),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Enter container number (e.g. TCKU1234567)',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.green,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.yellow.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.yellow.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.yellow,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _searching ? null : _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.yellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 3,
              ),
              child: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.yellow,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'TRACK',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Hint ─────────────────────────────────────────────────────────────────

  Widget _buildHint() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: AppColors.yellow,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enter a container number above\nto see its current status and location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _error,
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Result Card ───────────────────────────────────────────────────────────

  Widget _buildContainerResult(ContainerModel c) {
    final isLaden = c.statusId == 1;
    final statusColor = isLaden ? AppColors.green : AppColors.red;
    final statusLabel = isLaden ? 'Laden' : 'Empty';

    String locationText;
    String locationSub;
    IconData locationIcon;

    if (c.isMovedOut) {
      locationText = 'Moved Out';
      locationSub = c.boundTo != null
          ? 'Bound to: ${c.boundTo}'
          : 'Departed from port';
      locationIcon = Icons.local_shipping_rounded;
    } else if (c.isInYard) {
      locationText = 'In Yard';
      locationSub = [
        if (c.yardId != null) 'Yard ${c.yardId}',
        if (c.blockId != null) 'Block ${c.blockId}',
        if (c.bayId != null) 'Bay ${c.bayId}',
        if (c.rowId != null) 'Row ${c.rowId}',
        if (c.tier != null) 'Tier ${c.tier}',
      ].join(' · ');
      locationIcon = Icons.warehouse_rounded;
    } else {
      locationText = 'At Port';
      locationSub = 'Awaiting yard assignment';
      locationIcon = Icons.location_on_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('CONTAINER DETAILS'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.yellow.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top accent bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Container number + status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: AppColors.yellow,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.containerNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: AppColors.textDark,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (c.type != null)
                                Text(
                                  c.type!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: isLaden ? Colors.white : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Location card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.yellow.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              locationIcon,
                              color: AppColors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locationText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (locationSub.isNotEmpty)
                                  Text(
                                    locationSub,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detail rows
                    _detailRow(
                      Icons.tag_rounded,
                      'Container ID',
                      '#${c.containerId}',
                    ),
                    if (c.containerDesc != null && c.containerDesc!.isNotEmpty)
                      _detailRow(
                        Icons.notes_rounded,
                        'Description',
                        c.containerDesc!,
                      ),
                    if (c.boundTo != null)
                      _detailRow(Icons.near_me_rounded, 'Bound To', c.boundTo!),
                    _detailRow(
                      Icons.calendar_today_rounded,
                      'Created',
                      c.createdDate.length > 10
                          ? c.createdDate.substring(0, 10)
                          : c.createdDate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textGrey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() => Container(
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

Widget _sectionTitle(String text) => Row(
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
    Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.textDark,
        letterSpacing: 1.2,
      ),
    ),
  ],
);
