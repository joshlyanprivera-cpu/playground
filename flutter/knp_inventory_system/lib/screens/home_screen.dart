import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../models/ingredient.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  late final Stream<List<Ingredient>> _inventoryStream;
  String _searchQuery = '';
  String _selectedClassification = 'All';

  // ── Edit Mode State ──
  bool _isEditing = false;
  bool _isSaving = false;
  final Map<String, TextEditingController> _draftControllers = {};
  final Map<String, String> _draftUnits = {};
  final Set<String> _pendingDeletions = {};
  List<Ingredient> _lastSnapshot = [];

  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;

  final List<String> _classifications = [
    'All', 'coffee bean', 'food product', 'dairy/non-dairy',
    'syrup, sweeteners, flavorings', 'powders and blends', 'miscellaneous',
  ];

  IconData _classificationIcon(String classification) {
    switch (classification) {
      case 'coffee bean': return Icons.coffee;
      case 'food product': return Icons.fastfood_outlined;
      case 'dairy/non-dairy': return Icons.icecream_outlined;
      case 'syrup, sweeteners, flavorings': return Icons.local_cafe_outlined;
      case 'powders and blends': return Icons.blender_outlined;
      case 'miscellaneous': return Icons.category_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  int _gridColumns(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _inventoryStream = _inventoryService.getInventoryStream();
    _fabAnimController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
    _fabScaleAnim = CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut);
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    for (final c in _draftControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _enterEditMode(List<Ingredient> ingredients) {
    _lastSnapshot = ingredients;
    _draftControllers.clear();
    _draftUnits.clear();
    _pendingDeletions.clear();
    for (final item in ingredients) {
      _draftControllers[item.id] = TextEditingController(
        text: item.quantity % 1 == 0
            ? item.quantity.toInt().toString()
            : item.quantity.toString(),
      );
      _draftUnits[item.id] = item.quantityClassification;
    }
    _fabAnimController.reverse().then((_) {
      setState(() => _isEditing = true);
      _fabAnimController.forward();
    });
  }

  void _cancelEditMode() {
    _fabAnimController.reverse().then((_) {
      for (final c in _draftControllers.values) { c.dispose(); }
      _draftControllers.clear();
      _draftUnits.clear();
      _pendingDeletions.clear();
      setState(() => _isEditing = false);
      _fabAnimController.forward();
    });
  }

  Future<void> _saveEdits() async {
    if (_pendingDeletions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Confirm Changes',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          content: Text(
            'You are about to delete ${_pendingDeletions.length} item(s). This cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete & Save'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      for (final id in _pendingDeletions) {
        await _inventoryService.deleteIngredient(id);
      }
      for (final item in _lastSnapshot) {
        if (_pendingDeletions.contains(item.id)) continue;
        final ctrl = _draftControllers[item.id];
        if (ctrl == null) continue;
        final newQty = double.tryParse(ctrl.text);
        if (newQty == null) continue;
        final newUnit = _draftUnits[item.id] ?? item.quantityClassification;
        if (newQty == item.quantity && newUnit == item.quantityClassification) continue;
        await _inventoryService.updateIngredient(Ingredient(
          id: item.id, name: item.name,
          classification: item.classification,
          quantityClassification: newUnit,
          quantity: newQty,
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        for (final c in _draftControllers.values) { c.dispose(); }
        _draftControllers.clear();
        _draftUnits.clear();
        _pendingDeletions.clear();
        _fabAnimController.reverse().then((_) {
          setState(() { _isEditing = false; _isSaving = false; });
          _fabAnimController.forward();
        });
      }
    }
  }

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnim,
        child: _isEditing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cancel FAB
                  FloatingActionButton.extended(
                    heroTag: 'cancel_fab',
                    onPressed: _isSaving ? null : _cancelEditMode,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    elevation: 4,
                  ),
                  const SizedBox(width: 12),
                  // Save FAB
                  FloatingActionButton.extended(
                    heroTag: 'save_fab',
                    onPressed: _isSaving ? null : _saveEdits,
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                    elevation: 4,
                  ),
                ],
              )
            : FloatingActionButton.extended(
                heroTag: 'edit_fab',
                onPressed: () => _enterEditMode(_lastSnapshot),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
                elevation: 4,
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset('images/knp_logo.png', height: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Inventory',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    // Edit mode badge
                    if (_isEditing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_outlined, size: 14,
                              color: Theme.of(context).primaryColor),
                          const SizedBox(width: 4),
                          Text('Editing',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor)),
                        ]),
                      ),
                  ]),
                ),

                // ─── Search Bar ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search ingredients...',
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Filter Chips ───
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _classifications.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = _classifications[index];
                      final isSelected = _selectedClassification == c;
                      return ChoiceChip(
                        label: Text(c),
                        selected: isSelected,
                        onSelected: (s) { if (s) setState(() => _selectedClassification = c); },
                        selectedColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // ─── Pending deletion banner ───
                if (_isEditing && _pendingDeletions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.delete_sweep_outlined, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('${_pendingDeletions.length} item(s) marked for deletion',
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.red.shade700)),
                      ]),
                    ),
                  ),

                // ─── Content ───
                Expanded(
                  child: StreamBuilder<List<Ingredient>>(
                    stream: _inventoryStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('Error: ${snapshot.error}'),
                        ));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5));
                      }

                      final ingredients = snapshot.data ?? [];

                      // Keep snapshot in sync when not editing
                      if (!_isEditing) _lastSnapshot = ingredients;

                      final filtered = ingredients.where((item) {
                        final ms = item.name.toLowerCase().contains(_searchQuery);
                        final mc = _selectedClassification == 'All' ||
                            item.classification == _selectedClassification;
                        return ms && mc;
                      }).toList();

                      final lowStock = ingredients.where((i) => i.isLowStock).toList();

                      return Column(children: [
                        if (lowStock.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade700, Colors.red.shade900]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  '${lowStock.length} item(s) are running low on stock!',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                )),
                              ]),
                            ),
                          ),

                        Expanded(
                          child: filtered.isEmpty
                              ? Center(child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text('No items found',
                                      style: GoogleFonts.inter(
                                        fontSize: 16, color: Colors.grey,
                                        fontWeight: FontWeight.w500)),
                                  ]))
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = _gridColumns(constraints.maxWidth);
                                    if (columns == 1) {
                                      return ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) => _buildCard(
                                          filtered[index], isDark, columns),
                                      );
                                    }
                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: _isEditing ? 2.6 : 2.2,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) => _buildCard(
                                        filtered[index], isDark, columns),
                                    );
                                  },
                                ),
                        ),
                      ]);
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

  Widget _buildCard(Ingredient item, bool isDark, int columns) {
    final isMarked = _pendingDeletions.contains(item.id);
    final ctrl = _draftControllers[item.id];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isMarked ? 0.4 : 1.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _isEditing
                ? _HomeEditRow(
                    item: item,
                    ctrl: ctrl!,
                    isDark: isDark,
                    isMarked: isMarked,
                    classificationIcon: _classificationIcon,
                    onToggleDelete: () => setState(() {
                      if (isMarked) { _pendingDeletions.remove(item.id); }
                      else { _pendingDeletions.add(item.id); }
                    }),
                    currentUnit: _draftUnits[item.id] ?? item.quantityClassification,
                    unitOptions: const ['number', 'mg', 'kg', 'liters', 'milliliters'],
                    onUnitChanged: (val) => setState(() {
                      _draftUnits[item.id] = val;
                    }),
                    fmt: _fmt,
                  )
                : _HomeViewRow(
                    item: item,
                    isDark: isDark,
                    classificationIcon: _classificationIcon,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Home View Row ───
class _HomeViewRow extends StatefulWidget {
  final Ingredient item;
  final bool isDark;
  final IconData Function(String) classificationIcon;
  const _HomeViewRow({required this.item, required this.isDark, required this.classificationIcon});
  @override
  State<_HomeViewRow> createState() => _HomeViewRowState();
}

class _HomeViewRowState extends State<_HomeViewRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: _hovered
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.classificationIcon(item.classification), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.name,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.classification,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (item.lastUpdated != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Updated: ${item.lastUpdated!.month}/${item.lastUpdated!.day}/${item.lastUpdated!.year} ${item.lastUpdated!.hour}:${item.lastUpdated!.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: item.isLowStock ? Colors.redAccent : null),
              ),
              Text(item.quantityClassification,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              if (item.isLowStock)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('LOW',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.redAccent)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─── Home Edit Row ───
class _HomeEditRow extends StatelessWidget {
  final Ingredient item;
  final TextEditingController ctrl;
  final bool isDark;
  final bool isMarked;
  final IconData Function(String) classificationIcon;
  final VoidCallback onToggleDelete;
  final String currentUnit;
  final List<String> unitOptions;
  final ValueChanged<String> onUnitChanged;
  final String Function(double) fmt;

  const _HomeEditRow({
    required this.item, required this.ctrl, required this.isDark,
    required this.isMarked, required this.classificationIcon,
    required this.onToggleDelete, required this.currentUnit,
    required this.unitOptions, required this.onUnitChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: icon + name + steppers + delete
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(classificationIcon(item.classification), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600,
                decoration: isMarked ? TextDecoration.lineThrough : null),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          _SmallStepBtn(
            icon: Icons.remove, color: Colors.red.shade700,
            bg: Colors.red.withValues(alpha: 0.1),
            onPressed: isMarked ? null : () {
              double v = double.tryParse(ctrl.text) ?? 0;
              if (v > 0) { ctrl.text = fmt(v - 1); }
            },
          ),
          SizedBox(
            width: 52,
            child: TextField(
              controller: ctrl,
              enabled: !isMarked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              ),
            ),
          ),
          _SmallStepBtn(
            icon: Icons.add, color: Colors.green.shade700,
            bg: Colors.green.withValues(alpha: 0.1),
            onPressed: isMarked ? null : () {
              double v = double.tryParse(ctrl.text) ?? 0;
              ctrl.text = fmt(v + 1);
            },
          ),
          IconButton(
            icon: Icon(
              isMarked ? Icons.restore_from_trash_outlined : Icons.delete_outline,
              size: 20,
              color: isMarked ? Colors.green.shade700 : Colors.red.shade400,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: isMarked ? 'Restore' : 'Delete',
            onPressed: onToggleDelete,
          ),
        ]),
        // Bottom row: unit dropdown
        const SizedBox(height: 2),
        SizedBox(
          height: 28,
          child: DropdownButton<String>(
            value: currentUnit,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade500),
            items: unitOptions.map((u) => DropdownMenuItem(
              value: u,
              child: Text(u, style: GoogleFonts.inter(fontSize: 11)),
            )).toList(),
            onChanged: isMarked ? null : (val) {
              if (val != null) { onUnitChanged(val); }
            },
          ),
        ),
      ],
    );
  }
}

class _SmallStepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback? onPressed;
  const _SmallStepBtn({required this.icon, required this.color, required this.bg, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: IconButton(
        icon: Icon(icon, size: 16, color: onPressed == null ? Colors.grey : color),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
