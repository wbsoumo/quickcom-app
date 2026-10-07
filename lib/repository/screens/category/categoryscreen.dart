import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/screens/category/category_products_screen.dart';
import 'package:blinkit_series/repository/screens/search/searchscreen.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/widgets/address_selection_bottom_sheet.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/widgets/voice_search_sheet.dart';

class CategoryScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const CategoryScreen({super.key, this.onProfileTap});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> _categoriesFromApi = [];
  List<Map<String, dynamic>> _allProducts = [];
  Map<String, dynamic>? _selectedStoreData = ApiService.memoryCachedStore;
  String _userAddress = "";

  final List<Map<String, dynamic>> _fallbackCategories = [
    {"id": 1, "name": "Vegetables & Fruits", "image": "assets/images/01_vegetables_fruits.png"},
    {"id": 2, "name": "Dairy, Bread & Eggs", "image": "assets/images/02_dairy_bread_eggs.png"},
    {"id": 3, "name": "Snacks & Beverages", "image": "assets/images/03_snacks_beverages.png"},
    {"id": 4, "name": "Personal Care", "image": "assets/images/04_personal_care.png"},
    {"id": 5, "name": "Home Care & Cleaning", "image": "assets/images/05_home_care_cleaning.png"},
    {"id": 6, "name": "Atta, Dal & Rice", "image": "assets/images/06_atta_dal_rice.png"},
    {"id": 7, "name": "Oil, Ghee & Masala", "image": "assets/images/07_oil_ghee_masala.png"},
    {"id": 8, "name": "Instant Food", "image": "assets/images/08_instant_food.png"},
    {"id": 9, "name": "Beverages", "image": "assets/images/09_beverages.png"},
    {"id": 10, "name": "Baby Care", "image": "assets/images/10_baby_care.png"},
    {"id": 11, "name": "Pet Care", "image": "assets/images/11_pet_care.png"},
    {"id": 12, "name": "Frozen Food", "image": "assets/images/12_frozen_food.png"},
    {"id": 13, "name": "Bakery & Sweets", "image": "assets/images/13_bakery_sweets.png"},
    {"id": 14, "name": "Fresh Fruits", "image": "assets/images/14_fresh_fruits.png"},
    {"id": 15, "name": "Kitchen & Household", "image": "assets/images/15_kitchen_household.png"},
    {"id": 16, "name": "Organic & Healthy Living", "image": "assets/images/16_organic_healthy_living.png"},
  ];

  @override
  void initState() {
    super.initState();
    _categoriesFromApi = _fallbackCategories;
    _loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final store = await ApiService.fetchSelectedStore();
    final cats = await ApiService.fetchCategories();
    final prods = await ApiService.fetchProducts();
    final savedAddr = await ApiService.getUserSelectedAddress();

    if (mounted) {
      setState(() {
        if (store != null) _selectedStoreData = store;
        if (cats.isNotEmpty) _categoriesFromApi = cats;
        _allProducts = prods;
        if (savedAddr != null && savedAddr.isNotEmpty) {
          _userAddress = savedAddr;
        }
      });
    }
  }

  void _openSearchScreen([String query = '']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          allProducts: _allProducts,
          initialQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Location & Search Header matching HomeScreen
            Container(
              decoration: BoxDecoration(
                color: () {
                  final hexStr = _selectedStoreData?['banner_color']?.toString().replaceAll('#', '');
                  if (hexStr != null && hexStr.length == 6) {
                    return Color(int.parse("0xFF$hexStr"));
                  }
                  return const Color(0XFF0C831F);
                }(),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 16, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Delivery info, location & Profile icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStoreData != null
                                      ? ((_selectedStoreData!['is_serviceable'] ?? true)
                                          ? "Delivery in ${_selectedStoreData!['delivery_time_mins'] ?? '15'} mins"
                                          : "🚫 Location Unserviceable")
                                      : "SB Mart in 16 minutes",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _selectedStoreData != null
                                      ? ((_selectedStoreData!['is_serviceable'] ?? true)
                                          ? "${_selectedStoreData!['name'] ?? 'Dark Store'}"
                                          : "No Store Delivers Here")
                                      : "16 minutes",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () {
                                    AddressSelectionBottomSheet.show(
                                      context,
                                      onAddressSelected: (selectedAddress) {
                                        if (mounted) {
                                          setState(() {
                                            _userAddress = selectedAddress;
                                          });
                                        }
                                        _loadData();
                                      },
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _userAddress.isNotEmpty
                                              ? _userAddress
                                              : (_selectedStoreData != null
                                                  ? "${_selectedStoreData!['address'] ?? 'Store Location'}, ${_selectedStoreData!['city'] ?? ''}"
                                                  : "Select Location"),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: widget.onProfileTap,
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Bar Navigation Trigger
                      InkWell(
                        onTap: () => _openSearchScreen(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0XFFC5C5C5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Color(0XFF9C9C9C), size: 22),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Search 'ice-cream' or categories",
                                  style: TextStyle(
                                    color: Color(0XFF9C9C9C),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 12),
              child: Text(
                "All Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            _categoriesFromApi.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text("No categories found in database"),
                    ),
                  )
                : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _categoriesFromApi.length,
                        itemBuilder: (context, index) {
                          final item = _categoriesFromApi[index];
                          final String catName = (item["name"] ?? "").toString();
                          final String img = (item["image"] ?? "").toString();
                          final int? catId = item["id"] is int ? item["id"] : int.tryParse(item["id"]?.toString() ?? "");

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CategoryProductsScreen(
                                    categoryName: catName,
                                    categoryImg: img,
                                    categoryId: catId,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 68,
                                  width: 68,
                                  child: UiHelper.CustomImage(img: img, fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  catName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
