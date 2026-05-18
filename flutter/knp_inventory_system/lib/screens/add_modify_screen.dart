import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ingredient.dart';
import '../services/inventory_service.dart';
import '../models/category_model.dart';

class AddModifyScreen extends StatefulWidget {
  const AddModifyScreen({super.key});

  @override
  State<AddModifyScreen> createState() => _AddModifyScreenState();
}

class _AddModifyScreenState extends State<AddModifyScreen> {
  final InventoryService _inventoryService = InventoryService();
  late final Stream<List<Ingredient>> _inventoryStream;
  late final Stream<List<CategoryModel>> _categoryStream;

  // ── Add-form selection state ──
  String _selectedCategory = '';
  String _selectedQtyClassification = 'number';
  final List<String> _qtyClassifications = [
    'number', 'mg', 'kg', 'liters', 'milliliters',
  ];

  // ── Edit-mode draft maps ──
  final Map<String, String> _draftCategories = {};

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _listScrollController = ScrollController();

  String _searchQuery = '';
  String _filterClassification = 'All';
  List<String> _filterClassifications = ['All'];

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // ── Edit Mode State ──
  bool _isEditing = false;
  final Map<String, TextEditingController> _draftControllers = {};
  final Map<String, String> _draftUnits = {};
  final Set<String> _pendingDeletions = {};
  List<Ingredient> _lastSnapshot = [];

  void _enterEditMode(List<Ingredient> ingredients) {
    _lastSnapshot = ingredients;
    _draftControllers.clear();
    _draftUnits.clear();
    _draftCategories.clear();
    _pendingDeletions.clear();
    for (final item in ingredients) {
      _draftControllers[item.id] = TextEditingController(
        text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
      );
      _draftUnits[item.id] = item.quantityClassification;
      _draftCategories[item.id] = item.classification;
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditMode() {
    for (final c in _draftControllers.values) { c.dispose(); }
    _draftControllers.clear();
    _draftUnits.clear();
    _pendingDeletions.clear();
    setState(() => _isEditing = false);
  }

  Future<void> _saveEdits() async {
    if (_pendingDeletions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
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
              'You are about to delete ${_pendingDeletions.length} item(s). This cannot be undone. Proceed?',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Delete & Save'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);
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
        final newCat = _draftCategories[item.id] ?? item.classification;
        if (newQty == item.quantity && newUnit == item.quantityClassification && newCat == item.classification) continue;
        await _inventoryService.updateIngredient(Ingredient(
          id: item.id,
          name: item.name,
          classification: newCat,
          quantityClassification: newUnit,
          quantity: newQty,
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        for (final c in _draftControllers.values) { c.dispose(); }
        _draftControllers.clear();
        _draftUnits.clear();
        _pendingDeletions.clear();
        setState(() { _isEditing = false; _isLoading = false; });
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final newNameRaw = _nameController.text.trim();
        final newNameLower = newNameRaw.toLowerCase();
        final existingSnapshot = await _inventoryService.getInventoryStream().first;
        final isDuplicate = existingSnapshot.any((item) => item.name.toLowerCase() == newNameLower);
        if (isDuplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Similar ingredient already exists.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        await _inventoryService.addIngredient(Ingredient(
          id: '',
          name: newNameRaw,
          classification: _selectedCategory,
          quantityClassification: _selectedQtyClassification,
          quantity: double.parse(_quantityController.text.trim()),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingredient added successfully!')),
          );
          _nameController.clear();
          _quantityController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ───────────────────────────────────────────
  // Manage Categories Modal
  // ───────────────────────────────────────────
  void _showManageCategoriesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ManageCategoriesSheet(
        inventoryService: _inventoryService,
        // Fresh stream each open → new Firestore listener → immediate data emit
        categoryStream: _inventoryService.getCategoriesStream(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _inventoryStream = _inventoryService.getInventoryStream();
    _categoryStream = _inventoryService.getCategoriesStream();
    // Populate category dropdown & filter chips once loaded
    _categoryStream.listen((cats) {
      if (!mounted) return;
      setState(() {
        _filterClassifications = ['All', ...cats.map((c) => c.name)];
        if (_selectedCategory.isEmpty && cats.isNotEmpty) {
          _selectedCategory = cats.first.name;
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _listScrollController.dispose();
    for (final c in _draftControllers.values) { c.dispose(); }
    _draftUnits.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header ───
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset('images/knp_logo.png', height: 32),
                    ),
                    const SizedBox(width: 12),
                    Text('Add / Modify',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 20),

                  // ─── Add New Ingredient Card ───
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.add_circle_outline, size: 20,
                                  color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text('New Ingredient',
                                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                prefixIcon: Icon(Icons.label_outline),
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<List<CategoryModel>>(
                              stream: _categoryStream,
                              builder: (context, catSnap) {
                                final cats = catSnap.data ?? [];
                                
                                String? effectiveCategory = _selectedCategory;
                                if (effectiveCategory.isEmpty || !cats.any((c) => c.name == effectiveCategory)) {
                                  effectiveCategory = cats.isNotEmpty ? cats.first.name : null;
                                }

                                return DropdownButtonFormField<String>(
                                  value: effectiveCategory,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Select a category' : null,
                                  items: cats.map((c) => DropdownMenuItem(
                                    value: c.name,
                                    child: Row(children: [
                                      Icon(c.icon, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                                    ]),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val ?? ''),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _quantityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    prefixIcon: Icon(Icons.numbers_outlined),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedQtyClassification,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Unit'),
                                  items: _qtyClassifications.map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                                  ).toList(),
                                  onChanged: (val) => setState(() => _selectedQtyClassification = val ?? 'number'),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isLoading && !_isEditing
                                    ? const Center(child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      ))
                                    : ElevatedButton.icon(
                                        onPressed: _submit,
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        label: const Text('Add Item'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Existing Ingredients Header ───
                  Row(children: [
                    Icon(Icons.edit_note, size: 22, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Existing Ingredients',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    TextButton.icon(
                      onPressed: () => _showManageCategoriesModal(context),
                      icon: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('Categories'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _isEditing
                        ? 'Edit quantity, unit, and category per item. Tap 🗑 to delete.'
                        : 'Tap "Edit" to manage stock. Tap "Categories" to add or remove categories.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  // ─── Search Bar ───
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search existing ingredients...',
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
                  const SizedBox(height: 12),

                  // ─── Filter Chips ───
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterClassifications.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final c = _filterClassifications[index];
                        final isSelected = _filterClassification == c;
                        return ChoiceChip(
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (s) { if (s) setState(() => _filterClassification = c); },
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
                  const SizedBox(height: 16),

                  // ─── Ingredient List ───
                  StreamBuilder<List<Ingredient>>(
                    stream: _inventoryStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                        );
                      }

                      final ingredients = snapshot.data ?? [];

                      // Sync draft controllers when stream updates (non-editing mode)
                      if (!_isEditing) {
                        _lastSnapshot = ingredients;
                      }

                      final filteredIngredients = ingredients.where((item) {
                        final matchesSearch = item.name.toLowerCase().contains(_searchQuery);
                        final matchesClass = _filterClassification == 'All' ||
                            item.classification == _filterClassification;
                        return matchesSearch && matchesClass;
                      }).toList();

                      if (ingredients.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No items yet. Add your first ingredient above!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.grey)),
                            ]),
                          ),
                        );
                      }

                      if (filteredIngredients.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('No items match your search.',
                              style: GoogleFonts.inter(color: Colors.grey)),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Edit / Save+Cancel toggle bar
                          if (!_isEditing)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _enterEditMode(ingredients),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Inventory'),
                            )
                          else
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: Colors.grey.shade600,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _isLoading ? null : _cancelEditMode,
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _isLoading ? null : _saveEdits,
                                  icon: _isLoading
                                      ? const SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.save_outlined, size: 18),
                                  label: const Text('Save Changes'),
                                ),
                              ),
                            ]),

                          const SizedBox(height: 12),

                          // Pending deletion count badge
                          if (_isEditing && _pendingDeletions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(children: [
                                  Icon(Icons.delete_sweep_outlined, color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_pendingDeletions.length} item(s) marked for deletion',
                                    style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ]),
                              ),
                            ),

                          // The scrollable list
                          NotificationListener<ScrollNotification>(
                            onNotification: (_) => true,
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 480),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black12 : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                ),
                              ),
                              child: ListView.builder(
                                controller: _listScrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                shrinkWrap: true,
                                itemCount: filteredIngredients.length,
                                itemBuilder: (context, index) {
                                  final item = filteredIngredients[index];
                                  final isMarkedForDelete = _pendingDeletions.contains(item.id);
                                  final ctrl = _draftControllers[item.id];

                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: isMarkedForDelete ? 0.4 : 1.0,
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: _isEditing
                                            ? _EditRow(
                                                item: item,
                                                ctrl: ctrl!,
                                                isDark: isDark,
                                                isMarkedForDelete: isMarkedForDelete,
                                                currentUnit: _draftUnits[item.id] ?? item.quantityClassification,
                                                unitOptions: _qtyClassifications,
                                                currentCategory: _draftCategories[item.id] ?? item.classification,
                                                categoryOptions: _filterClassifications.where((c) => c != 'All').toList(),
                                                onUnitChanged: (val) => setState(() {
                                                  _draftUnits[item.id] = val;
                                                }),
                                                onCategoryChanged: (val) => setState(() {
                                                  _draftCategories[item.id] = val;
                                                }),
                                                onToggleDelete: () => setState(() {
                                                  if (isMarkedForDelete) {
                                                    _pendingDeletions.remove(item.id);
                                                  } else {
                                                    _pendingDeletions.add(item.id);
                                                  }
                                                }),
                                              )
                                            : _ViewRow(item: item, isDark: isDark),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── View Row (non-edit mode) ───
class _ViewRow extends StatelessWidget {
  final Ingredient item;
  final bool isDark;
  const _ViewRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.quantityClassification}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
            if (item.lastUpdated != null) ...[
              const SizedBox(height: 2),
              Text(
                'Updated: ${item.lastUpdated!.month}/${item.lastUpdated!.day}/${item.lastUpdated!.year} ${item.lastUpdated!.hour}:${item.lastUpdated!.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.lock_outline, size: 18),
      ),
    ]);
  }
}

// ─── Edit Row (edit mode) ───
class _EditRow extends StatelessWidget {
  final Ingredient item;
  final TextEditingController ctrl;
  final bool isDark;
  final bool isMarkedForDelete;
  final String currentUnit;
  final List<String> unitOptions;
  final String currentCategory;
  final List<String> categoryOptions;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onToggleDelete;

  const _EditRow({
    required this.item,
    required this.ctrl,
    required this.isDark,
    required this.isMarkedForDelete,
    required this.currentUnit,
    required this.unitOptions,
    required this.currentCategory,
    required this.categoryOptions,
    required this.onUnitChanged,
    required this.onCategoryChanged,
    required this.onToggleDelete,
  });

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final effectiveCategory = categoryOptions.contains(currentCategory)
        ? currentCategory
        : (categoryOptions.isNotEmpty ? categoryOptions.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width name
        Text(item.name,
          style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600,
            decoration: isMarkedForDelete ? TextDecoration.lineThrough : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Category dropdown
        if (categoryOptions.isNotEmpty)
          SizedBox(
            height: 28,
            child: DropdownButton<String>(
              value: effectiveCategory,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
              icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade400),
              items: categoryOptions.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: GoogleFonts.inter(fontSize: 11)),
              )).toList(),
              onChanged: isMarkedForDelete ? null : (val) {
                if (val != null) onCategoryChanged(val);
              },
            ),
          ),
        const SizedBox(height: 4),
        // Controls row: unit dropdown + steppers + delete
        Row(children: [
          // Unit dropdown
          SizedBox(
            height: 32,
            child: DropdownButton<String>(
              value: currentUnit,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade500),
              items: unitOptions.map((u) => DropdownMenuItem(
                value: u,
                child: Text(u, style: GoogleFonts.inter(fontSize: 12)),
              )).toList(),
              onChanged: isMarkedForDelete ? null : (val) {
                if (val != null) { onUnitChanged(val); }
              },
            ),
          ),
          const Spacer(),
          // Subtract
          _StepperBtn(
            icon: Icons.remove,
            color: Colors.red.shade700,
            bg: Colors.red.withValues(alpha: 0.1),
            onPressed: isMarkedForDelete ? null : () {
              double v = double.tryParse(ctrl.text) ?? 0;
              if (v > 0) { ctrl.text = _fmt(v - 1); }
            },
          ),
          // Quantity input
          SizedBox(
            width: 64,
            child: TextField(
              controller: ctrl,
              enabled: !isMarkedForDelete,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
          // Add
          _StepperBtn(
            icon: Icons.add,
            color: Colors.green.shade700,
            bg: Colors.green.withValues(alpha: 0.1),
            onPressed: isMarkedForDelete ? null : () {
              double v = double.tryParse(ctrl.text) ?? 0;
              ctrl.text = _fmt(v + 1);
            },
          ),
          const SizedBox(width: 4),
          // Delete toggle
          IconButton(
            icon: Icon(
              isMarkedForDelete ? Icons.restore_from_trash_outlined : Icons.delete_outline,
              size: 22,
              color: isMarkedForDelete ? Colors.green.shade700 : Colors.red.shade400,
            ),
            tooltip: isMarkedForDelete ? 'Restore' : 'Mark for deletion',
            onPressed: onToggleDelete,
          ),
        ]),
      ],
    );
  }
}



class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback? onPressed;
  const _StepperBtn({required this.icon, required this.color, required this.bg, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: IconButton(
        icon: Icon(icon, color: onPressed == null ? Colors.grey : color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ─── Manage Categories Bottom Sheet ───
class _ManageCategoriesSheet extends StatefulWidget {
  final InventoryService inventoryService;
  final Stream<List<CategoryModel>> categoryStream;
  const _ManageCategoriesSheet({required this.inventoryService, required this.categoryStream});

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  final _addNameCtrl = TextEditingController();
  String _addIconKey = 'inventory_2';
  // Map of category id → edit state
  final Map<String, TextEditingController> _editCtrls = {};
  final Map<String, String> _editIconKeys = {};
  String? _expandedId; // which card is in edit mode

  @override
  void dispose() {
    _addNameCtrl.dispose();
    for (final c in _editCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _addNameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.inventoryService.addCategory(
      CategoryModel(id: '', name: name, iconString: _addIconKey),
    );
    _addNameCtrl.clear();
    setState(() => _addIconKey = 'inventory_2');
  }

  Future<void> _saveEdit(CategoryModel cat) async {
    final ctrl = _editCtrls[cat.id];
    if (ctrl == null) return;
    final newName = ctrl.text.trim();
    final newIcon = _editIconKeys[cat.id] ?? cat.iconString;
    if (newName.isEmpty) return;
    await widget.inventoryService.renameCategory(cat.id, cat.name, newName, newIcon);
    setState(() => _expandedId = null);
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'All items in this category will be moved to "Uncategorized".',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.inventoryService.deleteCategory(cat.id, cat.name);
    }
  }

  Widget _iconPicker(String selectedKey, ValueChanged<String> onPick) {
    final icons = CategoryModel.iconMap;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: icons.entries.map((e) {
        final isSelected = e.key == selectedKey;
        return GestureDetector(
          onTap: () => onPick(e.key),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
              border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
            ),
            child: Icon(e.value,
              size: 22,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.category_outlined, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              Text('Manage Categories',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          // Add new category
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Category',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _addNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Category name...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Icon:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                _iconPicker(_addIconKey, (k) => setState(() => _addIconKey = k)),
              ],
            ),
          ),
          const Divider(height: 24),
          // Existing categories list
          Expanded(
            child: StreamBuilder<List<CategoryModel>>(
              stream: widget.categoryStream,
              builder: (context, snap) {
                final cats = snap.data ?? [];
                if (cats.isEmpty) {
                  return Center(
                    child: Text('No categories yet.',
                      style: GoogleFonts.inter(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: cats.length,
                  itemBuilder: (context, i) {
                    final cat = cats[i];
                    final isExpanded = _expandedId == cat.id;

                    // Initialise edit controllers on demand
                    if (!_editCtrls.containsKey(cat.id)) {
                      _editCtrls[cat.id] = TextEditingController(text: cat.name);
                      _editIconKeys[cat.id] = cat.iconString;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(children: [
                              Icon(cat.icon, size: 22, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              Expanded(child: Text(cat.name,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600))),
                              IconButton(
                                icon: Icon(isExpanded ? Icons.expand_less : Icons.edit_outlined, size: 20),
                                tooltip: 'Edit',
                                onPressed: () => setState(() {
                                  _expandedId = isExpanded ? null : cat.id;
                                  // reset edit ctrl to current name
                                  _editCtrls[cat.id]!.text = cat.name;
                                  _editIconKeys[cat.id] = cat.iconString;
                                }),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                tooltip: 'Delete',
                                onPressed: () => _deleteCategory(cat),
                              ),
                            ]),
                            if (isExpanded) ...[ 
                              const SizedBox(height: 12),
                              TextField(
                                controller: _editCtrls[cat.id],
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Icon:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              _iconPicker(_editIconKeys[cat.id] ?? cat.iconString, (k) {
                                setState(() => _editIconKeys[cat.id] = k);
                              }),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveEdit(cat),
                                  icon: const Icon(Icons.save_outlined, size: 18),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

