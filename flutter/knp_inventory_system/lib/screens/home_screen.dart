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

  int _gridColumns(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
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
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
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

                          // ─── Inventory Grid ───
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
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final columns = _gridColumns(
                                          constraints.maxWidth);

                                      if (columns == 1) {
                                        // Mobile: use ListView for performance
                                        return ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 4),
                                          itemCount: filteredIngredients.length,
                                          itemBuilder: (context, index) {
                                            return _InventoryCard(
                                              item: filteredIngredients[index],
                                              isDark: isDark,
                                              classificationIcon:
                                                  _classificationIcon,
                                            );
                                          },
                                        );
                                      }

                                      // Desktop/Tablet: use GridView
                                      return GridView.builder(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 4),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 2.2,
                                        ),
                                        itemCount:
                                            filteredIngredients.length,
                                        itemBuilder: (context, index) {
                                          return _InventoryCard(
                                            item: filteredIngredients[index],
                                            isDark: isDark,
                                            classificationIcon:
                                                _classificationIcon,
                                          );
                                        },
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
        ),
      ),
    );
  }
}

// ─── Extracted Inventory Card Widget with Hover ───
class _InventoryCard extends StatefulWidget {
  final Ingredient item;
  final bool isDark;
  final IconData Function(String) classificationIcon;

  const _InventoryCard({
    required this.item,
    required this.isDark,
    required this.classificationIcon,
  });

  @override
  State<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<_InventoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? 6 : 0,
          shadowColor: Colors.black.withAlpha(30),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.classificationIcon(item.classification),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.classification,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: item.isLowStock ? Colors.redAccent : null,
                      ),
                    ),
                    Text(
                      item.quantityClassification,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (item.isLowStock)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LOW',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
