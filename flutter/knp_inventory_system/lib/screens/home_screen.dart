import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../models/ingredient.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final InventoryService _inventoryService = InventoryService();
  String _searchQuery = '';
  String _selectedClassification = 'All';

  final List<String> _classifications = [
    'All',
    'coffee bean',
    'food product',
    'dairy/non-dairy',
    'syrup, sweeteners, flavorings',
    'powders and blends',
    'miscellaneous',
  ];

  IconData _classificationIcon(String classification) {
    switch (classification) {
      case 'coffee bean':
        return Icons.coffee;
      case 'food product':
        return Icons.fastfood_outlined;
      case 'dairy/non-dairy':
        return Icons.icecream_outlined;
      case 'syrup, sweeteners, flavorings':
        return Icons.local_cafe_outlined;
      case 'powders and blends':
        return Icons.blender_outlined;
      case 'miscellaneous':
        return Icons.category_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
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
                  Expanded(
                    child: Text(
                      'Inventory',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
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
                          onPressed: () =>
                              setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
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
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final classification = _classifications[index];
                  final isSelected =
                      _selectedClassification == classification;
                  return ChoiceChip(
                    label: Text(classification),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() =>
                            _selectedClassification = classification);
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
            const SizedBox(height: 8),

            // ─── Content ───
            Expanded(
              child: StreamBuilder<List<Ingredient>>(
                stream: _inventoryService.getInventoryStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    );
                  }

                  final ingredients = snapshot.data ?? [];

                  final filteredIngredients =
                      ingredients.where((ingredient) {
                    final matchesSearch = ingredient.name
                        .toLowerCase()
                        .contains(_searchQuery);
                    final matchesClassification =
                        _selectedClassification == 'All' ||
                            ingredient.classification ==
                                _selectedClassification;
                    return matchesSearch && matchesClassification;
                  }).toList();

                  final lowStockIngredients =
                      ingredients.where((i) => i.isLowStock).toList();

                  return Column(
                    children: [
                      // ─── Low Stock Alert ───
                      if (lowStockIngredients.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade700,
                                  Colors.red.shade900,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${lowStockIngredients.length} item(s) are running low on stock!',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ─── Inventory List ───
                      Expanded(
                        child: filteredIngredients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No items found',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                                itemCount: filteredIngredients.length,
                                itemBuilder: (context, index) {
                                  final item = filteredIngredients[index];
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Icon
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12),
                                            ),
                                            child: Icon(
                                              _classificationIcon(
                                                  item.classification),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: isDark
                                                        ? Colors
                                                            .grey.shade800
                                                        : Colors.grey
                                                            .shade200,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(6),
                                                  ),
                                                  child: Text(
                                                    item.classification,
                                                    style:
                                                        GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                if (item.lastUpdated != null) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Updated: ${item.lastUpdated!.month}/${item.lastUpdated!.day}/${item.lastUpdated!.year} ${item.lastUpdated!.hour}:${item.lastUpdated!.minute.toString().padLeft(2, '0')}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Quantity + Warning
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: item.isLowStock
                                                      ? Colors.redAccent
                                                      : null,
                                                ),
                                              ),
                                              Text(
                                                item
                                                    .quantityClassification,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              if (item.isLowStock)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets
                                                          .only(top: 4),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.red
                                                          .withAlpha(25),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  6),
                                                    ),
                                                    child: Text(
                                                      'LOW',
                                                      style: GoogleFonts
                                                          .inter(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight
                                                                .w700,
                                                        color: Colors
                                                            .redAccent,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
