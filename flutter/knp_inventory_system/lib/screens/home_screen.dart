import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../models/ingredient.dart';
import '../models/category_model.dart';
import '../utils/inventory_validators.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  late final Stream<List<Ingredient>> _inventoryStream;
  late final Stream<List<CategoryModel>> _categoryStream;
  StreamSubscription<List<CategoryModel>>? _categorySub;
  String _searchQuery = '';
  String _selectedClassification = 'All';
  List<String> _dynamicClassifications = ['All'];
  List<CategoryModel> _categories = [];

  // ── Edit Mode State ──
  bool _isEditing = false;
  bool _isSaving = false;
  final Map<String, TextEditingController> _draftControllers = {};
  final Map<String, String> _draftUnits = {};
  final Map<String, String> _draftCategories = {};
  final Set<String> _pendingDeletions = {};
  List<Ingredient> _lastSnapshot = [];

  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;

  // Resolves a category name to its icon using the CategoryModel map,
  // falling back to Uncategorized or a default if not found.
  IconData _getCategoryIcon(String name) {
    if (name == 'Uncategorized') {
      return Icons.inbox_outlined;
    }
    for (final cat in _categories) {
      if (cat.name.toLowerCase() == name.toLowerCase()) {
        return cat.icon;
      }
    }
    return Icons.inventory_2_outlined;
  }

  void _showLowStockBottomSheet(BuildContext context, List<Ingredient> lowStockItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group items by category (classification)
    final Map<String, List<Ingredient>> grouped = {};
    for (final item in lowStockItems) {
      (grouped[item.classification] ??= []).add(item);
    }

    // Build ordered list of categories containing low stock items
    final categoryOrder = _dynamicClassifications
        .where((c) => c != 'All' && grouped.containsKey(c))
        .toList();
    for (final key in grouped.keys) {
      if (!categoryOrder.contains(key)) categoryOrder.add(key);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Stock Warning',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The following items require replenishment',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: categoryOrder.length,
                    itemBuilder: (context, catIdx) {
                      final catName = categoryOrder[catIdx];
                      final catItems = grouped[catName]!;
                      final catIcon = _getCategoryIcon(catName);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: PageStorageKey('low_stock_$catName'),
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                catIcon,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            title: Text(
                              catName,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${catItems.length}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            children: catItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    child: _HomeViewRow(
                                      item: item,
                                      isDark: isDark,
                                      categoryIcon: _getCategoryIcon(item.classification),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
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
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _inventoryStream = _inventoryService.getInventoryStream();
    _categoryStream = _inventoryService.getCategoriesStream();
    _categorySub = _categoryStream.listen((cats) {
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _dynamicClassifications = ['All', ...cats.map((c) => c.name)];
        // Reset filter if it no longer exists
        if (!_dynamicClassifications.contains(_selectedClassification)) {
          _selectedClassification = 'All';
        }
      });
    });
    _fabAnimController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
    _fabScaleAnim = CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut);
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    _fabAnimController.dispose();
    for (final c in _draftControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _enterEditMode(List<Ingredient> ingredients) {
    _lastSnapshot = ingredients;
    _draftControllers.clear();
    _draftUnits.clear();
    _draftCategories.clear();
    _pendingDeletions.clear();
    for (final item in ingredients) {
      _draftControllers[item.id] = TextEditingController(
        text: item.quantity % 1 == 0
            ? item.quantity.toInt().toString()
            : item.quantity.toString(),
      );
      _draftUnits[item.id] = item.quantityClassification;
      _draftCategories[item.id] = item.classification;
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditMode() {
    final toDispose = _draftControllers.values.toList();
    _draftControllers.clear();
    _draftUnits.clear();
    _draftCategories.clear();
    _pendingDeletions.clear();
    setState(() => _isEditing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in toDispose) { c.dispose(); }
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
      final List<Ingredient> toUpdate = [];
      final validCategories = _dynamicClassifications.where((c) => c != 'All').toList();
      for (final item in _lastSnapshot) {
        if (_pendingDeletions.contains(item.id)) continue;
        final ctrl = _draftControllers[item.id];
        if (ctrl == null) continue;
        final newQty = InventoryValidators.parseQuantity(ctrl.text);
        if (newQty == null) {
          throw InventoryValidationException(
            'Invalid quantity for "${item.name}".',
          );
        }
        final newUnit = _draftUnits[item.id] ?? item.quantityClassification;
        var newCat = _draftCategories[item.id] ?? item.classification;
        // If the saved category no longer exists, use the first valid one
        if (!validCategories.contains(newCat) && validCategories.isNotEmpty) {
          newCat = validCategories.first;
        }
        if (InventoryValidators.validateQuantityUnit(newUnit) != null ||
            InventoryValidators.validateClassification(newCat) != null) {
          throw InventoryValidationException(
            'Invalid data for "${item.name}".',
          );
        }
        if (newQty == item.quantity && newUnit == item.quantityClassification && newCat == item.classification) continue;
        toUpdate.add(Ingredient(
          id: item.id, name: item.name,
          classification: newCat,
          quantityClassification: newUnit,
          quantity: newQty,
        ));
      }

      await _inventoryService.batchSaveIngredients(
        toUpdate: toUpdate,
        toDelete: _pendingDeletions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved!')),
        );
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('Save edits failed: $e\n$st');
      if (mounted) {
        final message = e is InventoryValidationException
            ? e.message
            : InventoryValidators.userSafeErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        final toDispose = _draftControllers.values.toList();
        _draftControllers.clear();
        _draftUnits.clear();
        _draftCategories.clear();
        _pendingDeletions.clear();
        setState(() { _isEditing = false; _isSaving = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final c in toDispose) { c.dispose(); }
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

                // ─── Filter Chips (dynamic from Firestore) ───
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _dynamicClassifications.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = _dynamicClassifications[index];
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

                // ─── Content: grouped by category ───
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
                      if (!_isEditing) _lastSnapshot = ingredients;

                      // Use frozen snapshot while editing so stream updates don't crash
                      final sourceItems = _isEditing ? _lastSnapshot : ingredients;

                      // Apply search + classification filter
                      final filtered = sourceItems.where((item) {
                        final ms = item.name.toLowerCase().contains(_searchQuery);
                        final mc = _selectedClassification == 'All' ||
                            item.classification == _selectedClassification;
                        return ms && mc;
                      }).toList();

                      final lowStock = ingredients.where((i) => i.isLowStock).toList();

                      // Group filtered items by classification
                      final Map<String, List<Ingredient>> grouped = {};
                      for (final item in filtered) {
                        (grouped[item.classification] ??= []).add(item);
                      }
                      // Build ordered list of non-empty category names
                      final categoryOrder = _dynamicClassifications
                          .where((c) => c != 'All' && grouped.containsKey(c))
                          .toList();
                      // Append any categories not in _dynamicClassifications
                      for (final key in grouped.keys) {
                        if (!categoryOrder.contains(key)) categoryOrder.add(key);
                      }

                      if (filtered.isEmpty) {
                        return Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No items found',
                              style: GoogleFonts.inter(
                                fontSize: 16, color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                          ]));
                      }

                      return Column(children: [
                        // Low-stock banner
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
                                const SizedBox(width: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => _showLowStockBottomSheet(context, lowStock),
                                  child: Text(
                                    'Check',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),

                        // Category folders
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                            itemCount: categoryOrder.length,
                            itemBuilder: (context, catIdx) {
                              final catName = categoryOrder[catIdx];
                              final catItems = grouped[catName]!;
                              final catIcon = _getCategoryIcon(catName);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    key: PageStorageKey('home_$catName'),
                                    initiallyExpanded: false,
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                    leading: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(catIcon, size: 20,
                                        color: Theme.of(context).primaryColor),
                                    ),
                                    title: Text(catName,
                                      style: GoogleFonts.inter(
                                        fontSize: 15, fontWeight: FontWeight.w700)),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('${catItems.length}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12, fontWeight: FontWeight.w700,
                                            color: Theme.of(context).primaryColor)),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.expand_more),
                                    ]),
                                    children: catItems.map((item) =>
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: _buildCard(item, isDark, 1),
                                      ),
                                    ).toList(),
                                  ),
                                ),
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
    final categoryChoices = _dynamicClassifications.where((c) => c != 'All').toList();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isMarked ? 0.4 : 1.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: _isEditing ? 8 : 14),
            child: _isEditing
                ? _HomeEditRow(
                    item: item,
                    ctrl: ctrl!,
                    isDark: isDark,
                    isMarked: isMarked,
                    categoryIcon: _getCategoryIcon(item.classification),
                    onToggleDelete: () => setState(() {
                      if (isMarked) { _pendingDeletions.remove(item.id); }
                      else { _pendingDeletions.add(item.id); }
                    }),
                    currentUnit: _draftUnits[item.id] ?? item.quantityClassification,
                    unitOptions: const ['number', 'mg', 'kg', 'liters', 'milliliters'],
                    onUnitChanged: (val) => setState(() {
                      _draftUnits[item.id] = val;
                    }),
                    currentCategory: _draftCategories[item.id] ?? item.classification,
                    categoryOptions: categoryChoices,
                    onCategoryChanged: (val) => setState(() {
                      _draftCategories[item.id] = val;
                    }),
                    fmt: _fmt,
                  )
                : _HomeViewRow(
                    item: item,
                    isDark: isDark,
                    categoryIcon: _getCategoryIcon(item.classification),
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
  final IconData categoryIcon;
  const _HomeViewRow({required this.item, required this.isDark, required this.categoryIcon});
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
            child: Icon(widget.categoryIcon, size: 22),
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
  final IconData categoryIcon;
  final VoidCallback onToggleDelete;
  final String currentUnit;
  final List<String> unitOptions;
  final ValueChanged<String> onUnitChanged;
  final String currentCategory;
  final List<String> categoryOptions;
  final ValueChanged<String> onCategoryChanged;
  final String Function(double) fmt;

  const _HomeEditRow({
    required this.item, required this.ctrl, required this.isDark,
    required this.isMarked, required this.categoryIcon,
    required this.onToggleDelete, required this.currentUnit,
    required this.unitOptions, required this.onUnitChanged,
    required this.currentCategory, required this.categoryOptions,
    required this.onCategoryChanged, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCat = categoryOptions.contains(currentCategory)
        ? currentCategory
        : (categoryOptions.isNotEmpty ? categoryOptions.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: icon + name
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600,
                decoration: isMarked ? TextDecoration.lineThrough : null),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        // Category dropdown
        if (categoryOptions.isNotEmpty)
          SizedBox(
            height: 26,
            child: DropdownButton<String>(
              value: effectiveCat,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
              icon: Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey.shade400),
              items: categoryOptions.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: GoogleFonts.inter(fontSize: 10)),
              )).toList(),
              onChanged: isMarked ? null : (val) {
                if (val != null) onCategoryChanged(val);
              },
            ),
          ),
        const SizedBox(height: 4),
        // Bottom row: unit dropdown + steppers + delete
        Row(children: [
          // Unit dropdown
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
          const Spacer(),
          // Subtract
          _SmallStepBtn(
            icon: Icons.remove, color: Colors.red.shade700,
            bg: Colors.red.withValues(alpha: 0.1),
            onPressed: isMarked ? null : () {
              final v = InventoryValidators.parseQuantity(ctrl.text) ?? 0;
              if (v > 0) {
                final newText = fmt(v - 1);
                ctrl.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: newText.length),
                );
              }
            },
          ),
          // Input
          SizedBox(
            width: 52,
            child: TextField(
              key: PageStorageKey('tf_${item.id}'),
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
          // Add
          _SmallStepBtn(
            icon: Icons.add, color: Colors.green.shade700,
            bg: Colors.green.withValues(alpha: 0.1),
            onPressed: isMarked ? null : () {
              final v = InventoryValidators.parseQuantity(ctrl.text) ?? 0;
              final next = v + 1;
              if (InventoryValidators.validateQuantity(next) == null) {
                final newText = fmt(next);
                ctrl.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: newText.length),
                );
              }
            },
          ),
          // Delete toggle
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
