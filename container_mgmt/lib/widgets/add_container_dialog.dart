import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/customer_model.dart';
import '../theme/app_theme.dart';
import 'vacant_slot_allocation_dialog.dart';
import '../services/slot_allocation_service.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _green = AppColors.green;
const _yellow = AppColors.yellow;
const _red = AppColors.red;
const _white = AppColors.white;
const _textDark = AppColors.textDark;
const _textGrey = AppColors.textGrey;

class AddContainerDialog extends StatefulWidget {
  final int portId;
  final Function(VacantSlot?)? onContainerAssigned;
  const AddContainerDialog({super.key, required this.portId, this.onContainerAssigned});

  @override
  State<AddContainerDialog> createState() => _AddContainerDialogState();
}

class _AddContainerDialogState extends State<AddContainerDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _customerNameCtrl = TextEditingController();
  final _containerNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  // Selections
  int? _statusId; // 1 = Laden, 2 = Empty
  int? _sizeId; // 1 = 20ft, 2 = 40ft
  String? _containerType; // 'Food Grade' | 'Non-Food Grade'

  // Customer search
  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filtered = [];
  CustomerModel? _selectedCustomer;
  bool _showSuggestions = false;

  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _containerNoCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await _api.getCustomers();
      if (mounted) setState(() => _allCustomers = list);
    } catch (_) {}
  }

  void _onCustomerType(String q) {
    setState(() {
      _selectedCustomer = null;
      if (q.trim().isEmpty) {
        _filtered = [];
        _showSuggestions = false;
      } else {
        _filtered = _allCustomers
            .where((c) => c.fullName.toLowerCase().contains(q.toLowerCase()))
            .take(6)
            .toList();
        _showSuggestions = _filtered.isNotEmpty;
      }
    });
  }

  Future<void> _submit() async {
    // Clear previous error
    setState(() => _errorMsg = null);

    // Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // Validate radio selections
    if (_statusId == null) {
      setState(() => _errorMsg = 'Please select a Container Status.');
      return;
    }
    if (_sizeId == null) {
      setState(() => _errorMsg = 'Please select a Container Size.');
      return;
    }
    if (_containerType == null) {
      setState(() => _errorMsg = 'Please select a Container Type.');
      return;
    }

    setState(() => _loading = true);

    try {
      final remarks = _remarksCtrl.text.trim();
      // Map container type string → ContainerTypeId (1=Food Grade, 2=Non-Food Grade)
      final containerTypeId = _containerType == 'Food Grade' ? 1 : 2;
      // ContainerDesc encodes both type label + remarks
      final desc = remarks.isEmpty
          ? _containerType!
          : '$_containerType — $remarks';

      final createdContainer = await _api.createContainer(
        statusId: _statusId!,
        containerSizeId: _sizeId!,
        desc: desc,
        portId: widget.portId,
        containerNumber: _containerNoCtrl.text.trim(),
        customerId: _selectedCustomer?.customerId,
        containerStatusId: _statusId, // mirrors statusId (1=Laden,2=Empty)
        containerTypeId: containerTypeId,
        remarks: remarks.isEmpty ? null : remarks,
      );
      
      if (mounted) {
        // Close the add container dialog
        Navigator.pop(context, true);
        
        // Show the vacant slot allocation dialog
        if (createdContainer != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => VacantSlotAllocationDialog(
              container: createdContainer,
              portId: widget.portId,
              onAssigned: (assignedSlot) {
                // Container was auto-assigned to a slot
                // Notify parent with the VacantSlot for highlighting
                widget.onContainerAssigned?.call(assignedSlot);
              },
              onSkipped: () {
                // User skipped auto-assignment, they will manually assign
                // The parent widget will handle the refresh
              },
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 32,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(child: _buildForm()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        color: _yellow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_box_rounded, color: _yellow, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD CONTAINER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _textDark,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Fill in all required fields',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          // Close X
          _CloseBtn(onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer Name ──────────────────────────────────────────
            _label('Customer Name', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _customerNameCtrl,
              onChanged: _onCustomerType,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Customer name is required'
                  : null,
              decoration: _inputDeco(hint: 'Enter customer name'),
            ),
            if (_showSuggestions) _suggestionList(),
            const SizedBox(height: 16),

            // ── Container No. ──────────────────────────────────────────
            _label('Container No.', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _containerNoCtrl,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Container number is required'
                  : null,
              decoration: _inputDeco(hint: 'e.g. TEMU1234567'),
            ),
            const SizedBox(height: 16),

            // ── Container Status ───────────────────────────────────────
            _label('Container Status', required: true),
            const SizedBox(height: 8),
            _ToggleGroup(
              options: const ['Empty', 'Laden'],
              selected: _statusId == null
                  ? null
                  : _statusId == 2
                  ? 'Empty'
                  : 'Laden',
              activeColor: _green,
              onSelect: (v) => setState(() => _statusId = v == 'Empty' ? 2 : 1),
              onDeselect: () => setState(() => _statusId = null),
            ),
            const SizedBox(height: 16),

            // ── Container Size ─────────────────────────────────────────
            _label('Container Size', required: true),
            const SizedBox(height: 8),
            _ToggleGroup(
              options: const ['20ft', '40ft'],
              selected: _sizeId == null
                  ? null
                  : _sizeId == 1
                  ? '20ft'
                  : '40ft',
              activeColor: _green,
              onSelect: (v) => setState(() => _sizeId = v == '20ft' ? 1 : 2),
              onDeselect: () => setState(() => _sizeId = null),
            ),
            const SizedBox(height: 16),

            // ── Container Type ─────────────────────────────────────────
            _label('Container Type', required: true),
            const SizedBox(height: 8),
            _ToggleGroup(
              options: const ['Food Grade', 'Non-Food Grade'],
              selected: _containerType,
              activeColor: _green,
              onSelect: (v) => setState(() => _containerType = v),
              onDeselect: () => setState(() => _containerType = null),
            ),
            const SizedBox(height: 16),

            // ── Remarks ────────────────────────────────────────────────
            _label('Remarks', required: false),
            const SizedBox(height: 6),
            TextFormField(
              controller: _remarksCtrl,
              maxLines: 3,
              decoration: _inputDeco(hint: 'Additional notes (optional)'),
            ),

            // ── Error message ──────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _errorMsg!),
            ],

            const SizedBox(height: 20),

            // ── Buttons ────────────────────────────────────────────────
            Row(
              children: [
                // Close button
                Expanded(
                  child: _OutlineBtn(
                    label: 'Close',
                    onTap: _loading ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                // Add Container button
                Expanded(
                  flex: 2,
                  child: _PrimaryBtn(
                    label: _loading ? 'Saving…' : 'Add Container',
                    loading: _loading,
                    onTap: _loading ? null : _submit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Customer suggestion list ─────────────────────────────────────────────
  Widget _suggestionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        color: _white,
        border: Border.all(color: _green.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _filtered.length,
        itemBuilder: (_, i) {
          final c = _filtered[i];
          return _SuggestionTile(
            name: c.fullName,
            onTap: () => setState(() {
              _selectedCustomer = c;
              _customerNameCtrl.text = c.fullName;
              _showSuggestions = false;
            }),
          );
        },
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _label(String text, {required bool required}) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: _textDark,
        ),
      ),
      if (required)
        const Text(
          ' *',
          style: TextStyle(
            color: _red,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
    ],
  );

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textGrey, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _green, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _red, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Toggle Group — same UI for Status / Size / Type
//  Double-tap (tap selected) → deselects
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleGroup extends StatefulWidget {
  final List<String> options;
  final String? selected;
  final Color activeColor;
  final ValueChanged<String> onSelect;
  final VoidCallback onDeselect;

  const _ToggleGroup({
    required this.options,
    required this.selected,
    required this.activeColor,
    required this.onSelect,
    required this.onDeselect,
  });

  @override
  State<_ToggleGroup> createState() => _ToggleGroupState();
}

class _ToggleGroupState extends State<_ToggleGroup> {
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: widget.options.asMap().entries.map((e) {
        final idx = e.key;
        final label = e.value;
        final isActive = widget.selected == label;
        final isHovered = _hovered == label;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: idx == 0 ? 0 : 5,
              right: idx == widget.options.length - 1 ? 0 : 5,
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = label),
              onExit: (_) => setState(() => _hovered = null),
              child: GestureDetector(
                onTap: () {
                  // Double-tap (tap current selection) → deselect
                  if (isActive) {
                    widget.onDeselect();
                  } else {
                    widget.onSelect(label);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.activeColor
                        : isHovered
                        ? widget.activeColor.withValues(alpha: 0.08)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? widget.activeColor
                          : isHovered
                          ? widget.activeColor.withValues(alpha: 0.5)
                          : const Color(0xFFDDDDDD),
                      width: isActive ? 2 : 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isActive
                          ? Colors.white
                          : isHovered
                          ? widget.activeColor
                          : _textGrey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _CloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});
  @override
  State<_CloseBtn> createState() => _CloseBtnState();
}

class _CloseBtnState extends State<_CloseBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _h
                ? _textDark.withValues(alpha: 0.18)
                : _textDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, color: _textDark, size: 18),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatefulWidget {
  final String name;
  final VoidCallback onTap;
  const _SuggestionTile({required this.name, required this.onTap});
  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _h ? _green.withValues(alpha: 0.07) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: _textGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _h ? FontWeight.w700 : FontWeight.w500,
                    color: _h ? _green : _textDark,
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _red, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _PrimaryBtn({required this.label, required this.loading, this.onTap});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled
                ? (_h ? const Color(0xFF084A0A) : _green)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _white,
                  ),
                )
              else
                const Icon(Icons.add_rounded, size: 18, color: _white),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.4,
                  color: enabled ? _white : _textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, this.onTap});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _h ? const Color(0xFFF5F5F5) : _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _h
                  ? _green.withValues(alpha: 0.6)
                  : const Color(0xFFCCCCCC),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _h ? _green : _textGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
