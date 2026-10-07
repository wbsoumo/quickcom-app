import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/screens/cart/cartscreen.dart';
import 'package:blinkit_series/repository/screens/search/searchscreen.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/floating_cart_pill.dart';
import 'package:blinkit_series/repository/widgets/product_detail_dialog.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/services/api_service.dart';

class SectionProductsScreen extends StatefulWidget {
  final String title;
  final String icon;
  final List<Map<String, dynamic>> products;

  const SectionProductsScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.products,
  });

  @override
  State<SectionProductsScreen> createState() => _SectionProductsScreenState();
}

class _SectionProductsScreenState extends State<SectionProductsScreen> {
  final Set<String> _favoriteIds = {};
  String _selectedSort = "Relevance";
  List<Map<String, dynamic>> _displayProducts = [];

  @override
  void initState() {
    super.initState();
    _displayProducts = List.from(widget.products);
    _loadUserWishlistIds();
  }

  Future<void> _loadUserWishlistIds() async {
    try {
      final res = await ApiService.fetchUserWishlist();
      if (mounted && res['product_ids'] != null) {
        setState(() {
          _favoriteIds.clear();
          _favoriteIds.addAll(List<String>.from(res['product_ids']));
        });
      }
    } catch (_) {}
  }

  void _applySort(String sortType) {
    setState(() {
      _selectedSort = sortType;
      if (sortType == "Price: Low to High") {
        _displayProducts.sort((a, b) {
          final pA = double.tryParse((a['mrp'] ?? a['price'] ?? 0).toString().replaceAll('₹', '')) ?? 0;
          final pB = double.tryParse((b['mrp'] ?? b['price'] ?? 0).toString().replaceAll('₹', '')) ?? 0;
          return pA.compareTo(pB);
        });
      } else if (sortType == "Price: High to Low") {
        _displayProducts.sort((a, b) {
          final pA = double.tryParse((a['mrp'] ?? a['price'] ?? 0).toString().replaceAll('₹', '')) ?? 0;
          final pB = double.tryParse((b['mrp'] ?? b['price'] ?? 0).toString().replaceAll('₹', '')) ?? 0;
          return pB.compareTo(pA);
        });
      } else if (sortType == "Discount") {
        _displayProducts.sort((a, b) {
          final dA = int.tryParse((a['discount'] ?? '0').toString().replaceAll('% OFF', '').trim()) ?? 0;
          final dB = int.tryParse((b['discount'] ?? '0').toString().replaceAll('% OFF', '').trim()) ?? 0;
          return dB.compareTo(dA);
        });
      } else {
        _displayProducts = List.from(widget.products);
      }
    });
  }

  void _toggleWishlist(String productId) async {
    final isFav = _favoriteIds.contains(productId);
    setState(() {
      if (isFav) {
        _favoriteIds.remove(productId);
      } else {
        _favoriteIds.add(productId);
      }
    });

    try {
      await ApiService.toggleWishlistProduct(productId: productId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    allProducts: widget.products,
                    initialQuery: "",
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header Filter/Sort Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_displayProducts.length} Products Available",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: _applySort,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: "Relevance", child: Text("Relevance")),
                        const PopupMenuItem(value: "Price: Low to High", child: Text("Price: Low to High")),
                        const PopupMenuItem(value: "Price: High to Low", child: Text("Price: High to Low")),
                        const PopupMenuItem(value: "Discount", child: Text("Discount")),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sort, size: 16, color: Color(0XFF0C831F)),
                            const SizedBox(width: 4),
                            Text(
                              _selectedSort,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product Grid with Compact Card Aspect Ratio (0.78)
              Expanded(
                child: _displayProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "No products found in ${widget.title}",
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _displayProducts.length,
                        itemBuilder: (context, index) {
                          final item = _displayProducts[index];
                          return _buildProductCard(item);
                        },
                      ),
              ),
            ],
          ),

          // Floating Cart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingCartPill(
              onViewCartTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final String productId = (item['id'] ?? item['product_id'] ?? '').toString();
    final bool isFav = _favoriteIds.contains(productId);

    // Extract product name checking all fallback fields
    final String title = (item['name'] ?? item['text'] ?? item['product_name'] ?? item['title'] ?? 'Product').toString();
    final String imagePath = (item['image'] ?? item['image_url'] ?? item['img'] ?? '').toString();
    final String qty = (item['quantity'] ?? item['unit'] ?? '1 unit').toString();

    final double price = double.tryParse((item['price'] ?? item['mrp'] ?? '0').toString().replaceAll('₹', '')) ?? 0.0;
    final double mrp = double.tryParse((item['mrp'] ?? item['price'] ?? '0').toString().replaceAll('₹', '')) ?? (price > 0 ? price * 1.15 : 0.0);

    String discountStr = item['discount']?.toString() ?? '';
    if (discountStr.isEmpty && mrp > price && price > 0) {
      final discVal = (((mrp - price) / mrp) * 100).round();
      if (discVal > 0) {
        discountStr = "$discVal% OFF";
      }
    }

    return GestureDetector(
      onTap: () {
        ProductDetailDialog.show(context, item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0XFFE0E0E0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header with full cover background
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  Container(
                    height: 115,
                    width: double.infinity,
                    color: const Color(0XFFF9F9F9),
                    child: UiHelper.CustomImage(
                      img: imagePath,
                      width: double.infinity,
                      height: 115,
                      fit: BoxFit.cover,
                    ),
                  ),

                  if (discountStr.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0XFF0C831F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          discountStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _toggleWishlist(productId),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Body (Name, Qty, Price, Add Button)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      qty,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "₹${price.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              if (mrp > price)
                                Text(
                                  "₹${mrp.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AnimatedCartButton(
                          id: productId,
                          name: title,
                          img: imagePath,
                          price: price,
                          unit: qty,
                          height: 30,
                          width: 62,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
