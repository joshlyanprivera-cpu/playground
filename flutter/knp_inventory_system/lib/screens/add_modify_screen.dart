import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ingredient.dart';
import '../services/inventory_service.dart';

class AddModifyScreen extends StatefulWidget {
  const AddModifyScreen({super.key});

  @override
  State<AddModifyScreen> createState() => _AddModifyScreenState();
}

class _AddModifyScreenState extends State<AddModifyScreen> {
  final InventoryService _inventoryService = InventoryService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _listScrollController = ScrollController();

  String _selectedClassification = 'coffee bean';
  final List<String> _classifications = [
    'coffee bean',
    'food product',
    'dairy/non-dairy',
    'syrup, sweeteners, flavorings',
    'powders and blends',
    'miscellaneous',
  ];

  String _searchQuery = '';
  String _filterClassification = 'All';
  final List<String> _filterClassifications = [
    'All',
    'coffee bean',
    'food product',
    'dairy/non-dairy',
    'syrup, sweeteners, flavorings',
    'powders and blends',
    'miscellaneous',
  ];

  String _selectedQtyClassification = 'number';
  final List<String> _qtyClassifications = [
    'number',
    'mg',
    'kg',
    'liters',
    'milliliters',
  ];

  bool _isLoading = false;

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
                content: Text('Similar ingredient already exists in the database.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return; // Abort saving
        }

        final ingredient = Ingredient(
          id: '',
          name: newNameRaw, // preserves user's casing
          classification: _selectedClassification,
          quantityClassification: _selectedQtyClassification,
          quantity: double.parse(_quantityController.text.trim()),
        );

        await _inventoryService.addIngredient(ingredient);

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
            SnackBar(content: Text('Error adding item: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showAdjustQuantityDialog(Ingredient ingredient) {
    final adjustController = TextEditingController(
      text: ingredient.quantity % 1 == 0 ? ingredient.quantity.toInt().toString() : ingredient.quantity.toString()
    );
    String dialogQtyClassification = ingredient.quantityClassification;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modify Ingredient',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ingredient.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (ingredient.lastUpdated != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last Updated: ${ingredient.lastUpdated!.month}/${ingredient.lastUpdated!.day}/${ingredient.lastUpdated!.year} at ${ingredient.lastUpdated!.hour}:${ingredient.lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Subtract Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.remove, color: Colors.red.shade700),
                          onPressed: () {
                            double current = double.tryParse(adjustController.text) ?? 0;
                            if (current > 0) {
                              setStateDialog(() {
                                current -= 1;
                                adjustController.text = current % 1 == 0 ? current.toInt().toString() : current.toString();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // TextField
                      Expanded(
                        child: TextField(
                          controller: adjustController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            labelText: 'Total Quantity',
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add, color: Colors.green.shade700),
                          onPressed: () {
                            double current = double.tryParse(adjustController.text) ?? 0;
                            setStateDialog(() {
                              current += 1;
                              adjustController.text = current % 1 == 0 ? current.toInt().toString() : current.toString();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Unit Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: dialogQtyClassification,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                    ),
                    items: _qtyClassifications.map((c) {
                      return DropdownMenuItem(
                          value: c, child: Text(c, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        dialogQtyClassification = val!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    final newTotal = double.tryParse(adjustController.text);
                    if (newTotal != null && newTotal >= 0) {
                      final updatedIngredient = Ingredient(
                        id: ingredient.id,
                        name: ingredient.name, // preserves casing
                        classification: ingredient.classification,
                        quantityClassification: dialogQtyClassification, // updated unit
                        quantity: newTotal, // absolute new total
                      );
                      await _inventoryService
                          .updateIngredient(updatedIngredient);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    }
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Update'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _listScrollController.dispose();
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset('images/knp_logo.png', height: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add / Modify',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
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
                        Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 20,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'New Ingredient',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedClassification,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Classification',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _classifications.map((c) {
                            return DropdownMenuItem(
                                value: c, child: Text(c, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) => setState(
                              () => _selectedClassification = val!),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  prefixIcon:
                                      Icon(Icons.numbers_outlined),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedQtyClassification,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                ),
                                items: _qtyClassifications.map((c) {
                                  return DropdownMenuItem(
                                      value: c, child: Text(c, overflow: TextOverflow.ellipsis));
                                }).toList(),
                                onChanged: (val) => setState(() =>
                                    _selectedQtyClassification = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: AnimatedSwitcher(
                            duration:
                                const Duration(milliseconds: 200),
                            child: _isLoading
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12),
                                      child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2.5),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _submit,
                                    icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20),
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

              // ─── Existing Ingredients Section ───
              Row(
                children: [
                  Icon(Icons.edit_note,
                      size: 22,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Existing Ingredients',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any item to adjust its quantity',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey,
                ),
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
                          onPressed: () =>
                              setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 12),

              // ─── Filter Chips ───
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterClassifications.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final classification = _filterClassifications[index];
                    final isSelected =
                        _filterClassification == classification;
                    return ChoiceChip(
                      label: Text(classification),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() =>
                              _filterClassification = classification);
                        }
                      },
                      selectedColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<Ingredient>>(
                stream: _inventoryService.getInventoryStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5)),
                    );
                  }
                  final ingredients = snapshot.data ?? [];
                  
                  final filteredIngredients = ingredients.where((ingredient) {
                    final matchesSearch = ingredient.name.toLowerCase().contains(_searchQuery);
                    final matchesClassification = _filterClassification == 'All' || ingredient.classification == _filterClassification;
                    return matchesSearch && matchesClassification;
                  }).toList();

                  if (ingredients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48,
                                color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No items yet. Add your first ingredient above!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (filteredIngredients.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No items match your search.',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) => true, // absorb scroll events
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 450),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black12 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          width: 1,
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
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Card(
                              child: InkWell(
                                onTap: () =>
                                    _showAdjustQuantityDialog(item),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.quantityClassification}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            if (item.lastUpdated != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Updated: ${item.lastUpdated!.month}/${item.lastUpdated!.day}/${item.lastUpdated!.year} ${item.lastUpdated!.hour}:${item.lastUpdated!.minute.toString().padLeft(2, '0')}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                        ),
                                        child: const Icon(
                                            Icons.tune,
                                            size: 20),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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
