import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/product_detail_dialog.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/widgets/skeleton_loader.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allProducts;
  final String initialQuery;
  final Color themeColor;

  const SearchScreen({
    super.key,
    required this.allProducts,
    this.initialQuery = '',
    this.themeColor = const Color(0XFF0C831F),
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _performSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _searchResults = List.from(widget.allProducts);
      });
      return;
    }

    final queryWords = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    List<Map<String, dynamic>> exactTitleMatches = [];
    List<Map<String, dynamic>> titleWordMatches = [];
    List<Map<String, dynamic>> descriptionMatches = [];

    for (var prod in widget.allProducts) {
      final title = (prod['name'] ?? prod['text'] ?? '').toString().toLowerCase();
      final description = (prod['description'] ?? '').toString().toLowerCase();
      final category = (prod['category_name'] ?? prod['category']?['name'] ?? '').toString().toLowerCase();

      final fullText = "$title $description $category";

      // 1. Exact Title Prefix / Contains Match
      if (title.contains(q)) {
        exactTitleMatches.add(prod);
      }
      // 2. All Query Words Match in Title
      else if (queryWords.every((word) => title.contains(word))) {
        titleWordMatches.add(prod);
      }
      // 3. Word-by-Word Match in Title + Description
      else if (queryWords.every((word) => fullText.contains(word)) || queryWords.any((word) => title.contains(word))) {
        descriptionMatches.add(prod);
      }
    }

    setState(() {
      _searchResults = [...exactTitleMatches, ...titleWordMatches, ...descriptionMatches];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: widget.themeColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _performSearch,
                        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Search products, milk, snacks...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.black54, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isSearching
          ? ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              itemBuilder: (context, index) => SkeletonLoader.searchTileSkeleton(),
            )
          : _searchResults.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No products found for "${_searchController.text}"',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try searching with different keywords',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                final String title = (item['name'] ?? item['text'] ?? '').toString();
                final double price = (item['price'] is num)
                    ? (item['price'] as num).toDouble()
                    : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                final double mrp = (item['mrp'] is num)
                    ? (item['mrp'] as num).toDouble()
                    : double.tryParse(item['mrp']?.toString() ?? price.toString()) ?? price;
                final String img = item['img']?.toString() ?? item['image']?.toString() ?? '';
                final String unit = item['unit']?.toString() ?? '1 pc';
                final String id = item['id'].toString();

                return InkWell(
                  onTap: () => ProductDetailDialog.show(context, item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0XFFF9F9F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: UiHelper.CustomImage(img: img, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 12, color: Color(0XFF0C831F)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '16 MINS',
                                    style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                unit,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "₹${price.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (mrp > price) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          "₹${mrp.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  AnimatedCartButton(
                                    id: "search_$id",
                                    name: title,
                                    img: img,
                                    price: price,
                                    unit: unit,
                                    maxStock: int.tryParse(item['available_stock']?.toString() ?? item['stock']?.toString() ?? '10'),
                                    width: 70,
                                    height: 28,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
