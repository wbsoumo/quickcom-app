import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/screens/cart/cartscreen.dart';
import 'package:blinkit_series/repository/screens/search/searchscreen.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/floating_cart_pill.dart';
import 'package:blinkit_series/repository/widgets/product_detail_dialog.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/services/api_service.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;
  final String categoryImg;
  final int? categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.categoryName,
    required this.categoryImg,
    this.categoryId,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final Set<String> _favoriteIds = {};

  // Active Filter / Sort state
  String _selectedSort = "Relevance";
  String _selectedType = "All";
  String _selectedOrigin = "All";

  List<Map<String, dynamic>> _sideCategories = [];
  // Each element in _categorySections is:
  // { 'category': Map, 'products': List<Map<String, dynamic>>, 'key': GlobalKey }
  List<Map<String, dynamic>> _categorySections = [];
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  bool _isProgrammaticScrolling = false;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onMainScrollListener);
    _loadAllCategoriesAndProducts();
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

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScrollListener);
    _mainScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCategoriesAndProducts() async {
    final allCats = await ApiService.fetchCategories();
    if (!mounted) return;

    List<Map<String, dynamic>> categoriesToUse = allCats;
    if (categoriesToUse.isEmpty) {
      // Fallback categories if API returns empty
      categoriesToUse = [
        {"id": 1, "name": "Vegetables & Fruits", "image": "image 41.png"},
        {"id": 2, "name": "Dairy, Bread & Eggs", "image": "image 41.png"},
        {"id": 3, "name": "Snacks & Beverages", "image": "image 41.png"},
        {"id": 4, "name": "Personal Care", "image": "image 41.png"},
        {"id": 5, "name": "Home Care & Cleaning", "image": "image 41.png"},
        {"id": 6, "name": "Atta, Dal & Rice", "image": "image 41.png"},
        {"id": 7, "name": "Oil, Ghee & Masala", "image": "image 41.png"},
        {"id": 8, "name": "Instant Food", "image": "image 41.png"},
      ];
    }

    int initialIdx = 0;
    if (widget.categoryId != null) {
      final targetIdStr = widget.categoryId.toString();
      final matchIdx = categoriesToUse.indexWhere((c) {
        final cIdStr = c['id']?.toString() ?? '';
        final cName = c['name']?.toString().toLowerCase() ?? '';
        return cIdStr == targetIdStr || (widget.categoryName.isNotEmpty && cName.contains(widget.categoryName.toLowerCase()));
      });
      if (matchIdx != -1) initialIdx = matchIdx;
    }

    // Fetch products for all categories in parallel simultaneously
    final List<Future<List<Map<String, dynamic>>>> prodFutures = categoriesToUse.map((cat) {
      final catId = cat['id'] is int ? cat['id'] : int.tryParse(cat['id']?.toString() ?? '');
      return ApiService.fetchProducts(categoryId: catId);
    }).toList();

    final List<List<Map<String, dynamic>>> allProdsRaw = await Future.wait(prodFutures);

    final List<Map<String, dynamic>> sections = [];
    for (int i = 0; i < categoriesToUse.length; i++) {
      final cat = categoriesToUse[i];
      final prodsRaw = allProdsRaw[i];

      List<Map<String, dynamic>> formattedProducts = [];
      if (prodsRaw.isNotEmpty) {
        formattedProducts = prodsRaw.map((p) {
          final double price = double.tryParse(p['effective_price']?.toString() ?? p['price']?.toString() ?? '0') ?? 0.0;
          final double mrp = double.tryParse(p['effective_mrp']?.toString() ?? p['mrp']?.toString() ?? '0') ?? (price > 0 ? price * 1.25 : 50.0);
          final String img = p['image']?.toString() ?? widget.categoryImg;
          final String origin = p['origin'] ?? (p['id'].hashCode % 2 == 0 ? "India" : "Imported");
          final String type = p['type'] ?? (price > 50 ? "Organic" : "Standard");
          final int rawStock = int.tryParse(p['available_stock']?.toString() ?? p['stock']?.toString() ?? '10') ?? 10;

          return {
            "id": p['id'].toString(),
            "name": p['name'].toString(),
            "unit": p['unit']?.toString() ?? "1 unit",
            "price": price,
            "mrp": mrp,
            "mins": "12 mins",
            "available_stock": rawStock,
            "stock": rawStock <= 0 ? "Out of stock" : "$rawStock left",
            "subCat": "All",
            "img": img,
            "type": type,
            "origin": origin,
          };
        }).toList();
      } else {
        // Fallback mock products if backend has no products for this specific category
        formattedProducts = _getMockProductsForCategory(cat['name']?.toString() ?? widget.categoryName);
      }

      sections.add({
        "category": cat,
        "products": formattedProducts,
        "key": GlobalKey(),
      });
    }

    if (mounted) {
      setState(() {
        _sideCategories = categoriesToUse;
        _categorySections = sections;
        _selectedCategoryIndex = initialIdx;
        _isLoading = false;
      });

      // Jump to selected initial category after layout build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            _scrollToCategorySection(initialIdx, animate: false);
          }
        });
      });
    }
  }

  List<Map<String, dynamic>> _getMockProductsForCategory(String catName) {
    return [
      {
        "id": "${catName}_1",
        "name": "Fresh Hybrid $catName Special",
        "unit": "500 g",
        "price": 28.0,
        "mrp": 35.0,
        "mins": "12 mins",
        "stock": "92 left",
        "img": "image 41.png",
        "type": "Organic",
        "origin": "India",
      },
      {
        "id": "${catName}_2",
        "name": "Farm Fresh Organic $catName",
        "unit": "1 kg",
        "price": 32.0,
        "mrp": 40.0,
        "mins": "12 mins",
        "stock": "91 left",
        "img": "image 41.png",
        "type": "Organic",
        "origin": "India",
      },
      {
        "id": "${catName}_3",
        "name": "Premium Quality $catName Pack",
        "unit": "250 g",
        "price": 24.0,
        "mrp": 30.0,
        "mins": "12 mins",
        "stock": "100 left",
        "img": "image 41.png",
        "type": "Standard",
        "origin": "India",
      },
      {
        "id": "${catName}_4",
        "name": "Fresh Selected $catName Item",
        "unit": "1 kg",
        "price": 48.0,
        "mrp": 60.0,
        "mins": "12 mins",
        "stock": "50 left",
        "img": "image 41.png",
        "type": "Hydroponic",
        "origin": "Imported",
      },
    ];
  }

  void _onMainScrollListener() {
    if (_isProgrammaticScrolling || _categorySections.isEmpty) return;

    int newIndex = _selectedCategoryIndex;
    double smallestOffset = double.infinity;

    for (int i = 0; i < _categorySections.length; i++) {
      final key = _categorySections[i]["key"] as GlobalKey;
      final keyContext = key.currentContext;
      if (keyContext != null) {
        final box = keyContext.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          final position = box.localToGlobal(Offset.zero);
          // Position relative to viewport upper area (approx below top bar & chips ~ 140px)
          final distance = (position.dy - 150).abs();
          if (position.dy <= 300 && distance < smallestOffset) {
            smallestOffset = distance;
            newIndex = i;
          }
        }
      }
    }

    if (newIndex != _selectedCategoryIndex) {
      setState(() {
        _selectedCategoryIndex = newIndex;
      });
      _ensureSidebarCategoryVisible(newIndex);
    }
  }

  void _ensureSidebarCategoryVisible(int index) {
    if (!_sidebarScrollController.hasClients) return;
    const double itemHeight = 84.0; // height + padding per sidebar item
    final double targetOffset = index * itemHeight;
    final double currentOffset = _sidebarScrollController.offset;
    final double maxScroll = _sidebarScrollController.position.maxScrollExtent;
    final double viewportHeight = _sidebarScrollController.position.viewportDimension;

    if (targetOffset < currentOffset || targetOffset > (currentOffset + viewportHeight - itemHeight)) {
      final double scrollPosition = (targetOffset - (viewportHeight / 2) + (itemHeight / 2)).clamp(0.0, maxScroll);
      _sidebarScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToCategorySection(int index, {bool animate = true}) async {
    if (index < 0 || index >= _categorySections.length) return;

    _isProgrammaticScrolling = true;
    setState(() {
      _selectedCategoryIndex = index;
    });
    _ensureSidebarCategoryVisible(index);

    final key = _categorySections[index]["key"] as GlobalKey;
    final keyContext = key.currentContext;

    if (keyContext != null) {
      if (animate) {
        await Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.0, // Align exactly at the top of the viewport
        );
      } else {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.0,
        );
      }
    } else if (_mainScrollController.hasClients) {
      // Direct offset estimation fallback to align top header precisely
      double targetOffset = 0.0;
      for (int i = 0; i < index; i++) {
        final prodsCount = (_categorySections[i]["products"] as List).length;
        final rowsCount = (prodsCount / 2).ceil();
        // 265px per grid row + 64px header banner + 24px bottom margin
        targetOffset += (rowsCount * 265.0) + 88.0;
      }
      _mainScrollController.jumpTo(targetOffset.clamp(0.0, _mainScrollController.position.maxScrollExtent));

      // Second-pass alignment once target section renders into view tree
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final secKeyContext = (_categorySections[index]["key"] as GlobalKey).currentContext;
        if (secKeyContext != null) {
          Scrollable.ensureVisible(secKeyContext, alignment: 0.0);
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        _isProgrammaticScrolling = false;
      }
    });
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          "Relevance",
          "Price: Low to High",
          "Price: High to Low",
          "Discount: High to Low",
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sort Products By",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final bool isSel = _selectedSort == opt;
                return ListTile(
                  title: Text(opt, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSel ? const Icon(Icons.check_circle, color: Color(0XFF0C831F)) : null,
                  onTap: () {
                    setState(() => _selectedSort = opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showTypeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = ["All", "Organic", "Hydroponic", "Standard"];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filter by Product Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final bool isSel = _selectedType == opt;
                return ListTile(
                  title: Text(opt, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSel ? const Icon(Icons.check_circle, color: Color(0XFF0C831F)) : null,
                  onTap: () {
                    setState(() => _selectedType = opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showOriginBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = ["All", "India", "Imported"];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filter by Country of Origin",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final bool isSel = _selectedOrigin == opt;
                return ListTile(
                  title: Text(opt, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSel ? const Icon(Icons.check_circle, color: Color(0XFF0C831F)) : null,
                  onTap: () {
                    setState(() => _selectedOrigin = opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAllFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("All Filters & Sort", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedSort = "Relevance";
                            _selectedType = "All";
                            _selectedOrigin = "All";
                          });
                          setModalState(() {});
                        },
                        child: const Text("Reset All", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Wrap(
                          spacing: 8,
                          children: ["Relevance", "Price: Low to High", "Price: High to Low"].map((s) {
                            final sel = _selectedSort == s;
                            return ChoiceChip(
                              label: Text(s),
                              selected: sel,
                              selectedColor: const Color(0XFFE8F5E9),
                              onSelected: (_) {
                                setState(() => _selectedSort = s);
                                setModalState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text("Product Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Wrap(
                          spacing: 8,
                          children: ["All", "Organic", "Hydroponic", "Standard"].map((t) {
                            final sel = _selectedType == t;
                            return ChoiceChip(
                              label: Text(t),
                              selected: sel,
                              selectedColor: const Color(0XFFE8F5E9),
                              onSelected: (_) {
                                setState(() => _selectedType = t);
                                setModalState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text("Country of Origin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Wrap(
                          spacing: 8,
                          children: ["All", "India", "Imported"].map((o) {
                            final sel = _selectedOrigin == o;
                            return ChoiceChip(
                              label: Text(o),
                              selected: sel,
                              selectedColor: const Color(0XFFE8F5E9),
                              onSelected: (_) {
                                setState(() => _selectedOrigin = o);
                                setModalState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0XFF0C831F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterAndSortProducts(List<Map<String, dynamic>> original) {
    var filtered = List<Map<String, dynamic>>.from(original);

    if (_selectedType != "All") {
      filtered = filtered.where((p) => (p["type"] ?? "Standard") == _selectedType).toList();
    }

    if (_selectedOrigin != "All") {
      filtered = filtered.where((p) => (p["origin"] ?? "India") == _selectedOrigin).toList();
    }

    if (_selectedSort == "Price: Low to High") {
      filtered.sort((a, b) => (a["price"] as num).compareTo(b["price"] as num));
    } else if (_selectedSort == "Price: High to Low") {
      filtered.sort((a, b) => (b["price"] as num).compareTo(a["price"] as num));
    } else if (_selectedSort == "Discount: High to Low") {
      filtered.sort((a, b) {
        final double discA = ((a["mrp"] as num) - (a["price"] as num)).toDouble();
        final double discB = ((b["mrp"] as num) - (b["price"] as num)).toDouble();
        return discB.compareTo(discA);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final activeCategoryName = (_sideCategories.isNotEmpty && _selectedCategoryIndex < _sideCategories.length)
        ? (_sideCategories[_selectedCategoryIndex]["name"] ?? widget.categoryName)
        : widget.categoryName;

    // Build all products list for search screen
    final List<Map<String, dynamic>> allSearchProducts = [];
    for (var sec in _categorySections) {
      allSearchProducts.addAll(sec["products"] as List<Map<String, dynamic>>);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0XFFF2F3F5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                activeCategoryName.toString().replaceAll('\n', ' '),
                key: ValueKey<String>(activeCategoryName.toString()),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: const [
                Text(
                  "Select Location",
                  style: TextStyle(
                    color: Color(0XFF0C831F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Color(0XFF0C831F), size: 16),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    allProducts: allSearchProducts,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.black, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0XFF0C831F)))
          : Stack(
              children: [
                Row(
                  children: [
                    // 1. Left Vertical Category Navigation Sidebar
                    Container(
                      width: 84,
                      color: Colors.white,
                      child: ListView.builder(
                        controller: _sidebarScrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _sideCategories.length,
                        itemBuilder: (context, index) {
                          final catItem = _sideCategories[index];
                          final bool isSelected = _selectedCategoryIndex == index;
                          final String label = (catItem["name"] ?? "").toString();
                          final String img = (catItem["image"] ?? catItem["img"] ?? "image 41.png").toString();

                          return InkWell(
                            onTap: () => _scrollToCategorySection(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0XFFFDF8E7) : Colors.white,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? const Color(0XFF0C831F) : Colors.transparent,
                                    width: 3.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 52,
                                    width: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0XFFF4F6F8),
                                      border: isSelected
                                          ? Border.all(color: const Color(0XFF0C831F), width: 1.5)
                                          : null,
                                    ),
                                    child: ClipOval(
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: UiHelper.CustomImage(img: img),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label.replaceAll('\n', ' '),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.black : const Color(0XFF757575),
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const VerticalDivider(width: 1, thickness: 1, color: Color(0XFFE0E0E0)),

                    // 2. Right Continuous Multi-Category Product Feed
                    Expanded(
                      child: Container(
                        color: const Color(0XFFFDF6E3), // Warm festive yellow background matching Blinkit design
                        child: Column(
                          children: [
                            // Top Interactive Filter Chips Bar
                            Container(
                              height: 46,
                              color: Colors.white,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  _buildFilterChip(
                                    "Filters",
                                    icon: Icons.tune,
                                    isActive: _selectedSort != "Relevance" || _selectedType != "All" || _selectedOrigin != "All",
                                    onTap: _showAllFiltersBottomSheet,
                                  ),
                                  _buildFilterChip(
                                    "Sort: $_selectedSort",
                                    icon: Icons.swap_vert,
                                    isActive: _selectedSort != "Relevance",
                                    onTap: _showSortBottomSheet,
                                  ),
                                  _buildFilterChip(
                                    "Type: $_selectedType",
                                    isActive: _selectedType != "All",
                                    onTap: _showTypeBottomSheet,
                                  ),
                                  _buildFilterChip(
                                    "Origin: $_selectedOrigin",
                                    isActive: _selectedOrigin != "All",
                                    onTap: _showOriginBottomSheet,
                                  ),
                                ],
                              ),
                            ),

                            // Continuous Products Feed Body
                            Expanded(
                              child: ListView.builder(
                                controller: _mainScrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(10),
                                itemCount: _categorySections.length,
                                itemBuilder: (context, secIndex) {
                                  final section = _categorySections[secIndex];
                                  final Map<String, dynamic> catData = section["category"];
                                  final List<Map<String, dynamic>> rawProds = section["products"];
                                  final GlobalKey secKey = section["key"];
                                  final String catTitle = (catData["name"] ?? "Category").toString().replaceAll('\n', ' ');
                                  final List<Map<String, dynamic>> filteredProds = _filterAndSortProducts(rawProds);

                                  return Container(
                                    key: secKey,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category Section Header Banner
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                catTitle,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.black,
                                                  fontFamily: "bold",
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                "Fresh items delivered in minutes",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0XFF616161),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Product Grid for this Category
                                        if (filteredProds.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "No items match selected filters",
                                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        else
                                          GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              childAspectRatio: 0.63,
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                            ),
                                            itemCount: filteredProds.length,
                                            itemBuilder: (context, pIndex) {
                                              final item = filteredProds[pIndex];
                                              final String id = item["id"];
                                              final String name = item["name"];
                                              final String unit = item["unit"];
                                              final double price = (item["price"] as num).toDouble();
                                              final double mrp = (item["mrp"] as num).toDouble();
                                              final String mins = item["mins"];
                                              final String? stock = item["stock"];
                                              final String? tag = item["tag"];
                                              final String img = item["img"];
                                              final bool isFav = _favoriteIds.contains(id);

                                               return InkWell(
                                                 onTap: () => ProductDetailDialog.show(context, item),
                                                 borderRadius: BorderRadius.circular(12),
                                                 child: Container(
                                                   decoration: BoxDecoration(
                                                     color: Colors.white,
                                                     borderRadius: BorderRadius.circular(12),
                                                     boxShadow: [
                                                       BoxShadow(
                                                         color: Colors.black.withValues(alpha: 0.04),
                                                         blurRadius: 6,
                                                         offset: const Offset(0, 2),
                                                       ),
                                                     ],
                                                   ),
                                                   child: Column(
                                                     crossAxisAlignment: CrossAxisAlignment.start,
                                                     children: [
                                                       // Top Image with Heart & ADD button overlay
                                                       Stack(
                                                         children: [
                                                           ClipRRect(
                                                             borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                             child: Container(
                                                               height: 98,
                                                               width: double.infinity,
                                                               color: const Color(0XFFF9F9F9),
                                                               child: UiHelper.CustomImage(
                                                                 img: img,
                                                                 fit: BoxFit.cover,
                                                               ),
                                                             ),
                                                           ),

                                                           // Heart Favorite & Share Icons
                                                           Positioned(
                                                             top: 6,
                                                             right: 6,
                                                             child: Row(
                                                               mainAxisSize: MainAxisSize.min,
                                                               children: [
                                                                 InkWell(
                                                                   onTap: () => ProductDetailDialog.show(context, item),
                                                                   child: CircleAvatar(
                                                                     radius: 12,
                                                                     backgroundColor: Colors.white.withValues(alpha: 0.85),
                                                                     child: const Icon(
                                                                       Icons.share_outlined,
                                                                       size: 13,
                                                                       color: Colors.black87,
                                                                     ),
                                                                   ),
                                                                 ),
                                                                 const SizedBox(width: 4),
                                                                 InkWell(
                                                                   onTap: () async {
                                                                     setState(() {
                                                                       if (isFav) {
                                                                         _favoriteIds.remove(id);
                                                                       } else {
                                                                         _favoriteIds.add(id);
                                                                       }
                                                                     });
                                                                     final isAdded = await ApiService.toggleWishlistProduct(productId: id);
                                                                     if (mounted) {
                                                                       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                                       ScaffoldMessenger.of(context).showSnackBar(
                                                                         SnackBar(
                                                                           content: Text(
                                                                             isAdded ? "❤️ Added to your wishlist!" : "Removed from wishlist",
                                                                             style: const TextStyle(fontWeight: FontWeight.bold),
                                                                           ),
                                                                           duration: const Duration(seconds: 2),
                                                                           behavior: SnackBarBehavior.floating,
                                                                         ),
                                                                       );
                                                                     }
                                                                   },
                                                                   child: CircleAvatar(
                                                                     radius: 12,
                                                                     backgroundColor: Colors.white.withValues(alpha: 0.85),
                                                                     child: Icon(
                                                                       isFav ? Icons.favorite : Icons.favorite_border,
                                                                       size: 14,
                                                                       color: isFav ? Colors.red : Colors.grey,
                                                                     ),
                                                                   ),
                                                                 ),
                                                               ],
                                                             ),
                                                           ),

                                                           // Bottom Bar over Image: Unit tag on left
                                                           Positioned(
                                                             bottom: 6,
                                                             left: 6,
                                                             child: Container(
                                                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                               decoration: BoxDecoration(
                                                                 color: Colors.white.withValues(alpha: 0.9),
                                                                 borderRadius: BorderRadius.circular(4),
                                                               ),
                                                               child: Text(
                                                                 unit,
                                                                 style: const TextStyle(
                                                                   fontSize: 10,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: Colors.black87,
                                                                 ),
                                                               ),
                                                             ),
                                                           ),
                                                         ],
                                                       ),

                                                       // Content Section Below Image
                                                       Padding(
                                                         padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                                         child: Column(
                                                           crossAxisAlignment: CrossAxisAlignment.start,
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             // 1. Price & Strikethrough
                                                             Row(
                                                               children: [
                                                                 Text(
                                                                   "₹${price.toStringAsFixed(0)}",
                                                                   style: const TextStyle(
                                                                     fontSize: 17,
                                                                     fontWeight: FontWeight.w900,
                                                                     color: Colors.black,
                                                                   ),
                                                                 ),
                                                                 if (mrp > price) ...[
                                                                   const SizedBox(width: 4),
                                                                   Text(
                                                                     "₹${mrp.toStringAsFixed(0)}",
                                                                     style: TextStyle(
                                                                       fontSize: 12,
                                                                       color: Colors.grey.shade500,
                                                                       decoration: TextDecoration.lineThrough,
                                                                     ),
                                                                   ),
                                                                 ],
                                                               ],
                                                             ),
                                                             const SizedBox(height: 3),

                                                             // 2. Product Name (Fixed height so 1-line & 2-line titles align ADD button perfectly)
                                                             SizedBox(
                                                               height: 28,
                                                               child: Text(
                                                                 name,
                                                                 maxLines: 2,
                                                                 overflow: TextOverflow.ellipsis,
                                                                 style: const TextStyle(
                                                                   fontSize: 12,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: Colors.black87,
                                                                   height: 1.15,
                                                                 ),
                                                               ),
                                                             ),
                                                             const SizedBox(height: 3),

                                                             // 3. Delivery Estimate & Stock Row
                                                             Row(
                                                               children: [
                                                                 const Icon(Icons.access_time_rounded, size: 12, color: Color(0XFF616161)),
                                                                 const SizedBox(width: 3),
                                                                 Text(
                                                                   mins,
                                                                   style: const TextStyle(
                                                                     fontSize: 11,
                                                                     color: Color(0XFF616161),
                                                                     fontWeight: FontWeight.w500,
                                                                   ),
                                                                 ),
                                                                 if (stock != null) ...[
                                                                   Padding(
                                                                     padding: const EdgeInsets.symmetric(horizontal: 5),
                                                                     child: Container(
                                                                       height: 9,
                                                                       width: 1,
                                                                       color: Colors.grey.shade300,
                                                                     ),
                                                                   ),
                                                                   const Icon(Icons.shopping_bag_outlined, size: 12, color: Color(0XFF616161)),
                                                                   const SizedBox(width: 3),
                                                                   Text(
                                                                     stock,
                                                                     style: const TextStyle(
                                                                       fontSize: 11,
                                                                       color: Color(0XFF616161),
                                                                       fontWeight: FontWeight.w500,
                                                                     ),
                                                                   ),
                                                                 ],
                                                               ],
                                                             ),
                                                             const SizedBox(height: 6),

                                                             // 4. Full-Width ADD Button sitting tightly under 12 mins & stock
                                                             SizedBox(
                                                               width: double.infinity,
                                                               height: 34,
                                                               child: AnimatedCartButton(
                                                                 id: id,
                                                                 name: name,
                                                                 img: img,
                                                                 price: price,
                                                                 unit: unit,
                                                                 maxStock: (item["available_stock"] is int) ? item["available_stock"] : int.tryParse(item["available_stock"]?.toString() ?? "10"),
                                                                 width: double.infinity,
                                                                 height: 34,
                                                                 themeColor: const Color(0XFF0C831F),
                                                               ),
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
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: FloatingCartPill(
                    onViewCartTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CartScreen(
                            onBackTap: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    IconData? icon,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0XFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0XFF0C831F) : const Color(0XFFE0E0E0),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? const Color(0XFF0C831F) : Colors.black87),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? const Color(0XFF0C831F) : Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: isActive ? const Color(0XFF0C831F) : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
