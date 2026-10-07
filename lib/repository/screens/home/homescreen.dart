import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/product_detail_dialog.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/widgets/skeleton_loader.dart';
import 'package:blinkit_series/repository/widgets/address_selection_bottom_sheet.dart';
import 'package:blinkit_series/repository/widgets/voice_search_sheet.dart';
import 'package:blinkit_series/repository/screens/category/category_products_screen.dart';
import 'package:blinkit_series/repository/screens/category/section_products_screen.dart';
import 'package:blinkit_series/repository/screens/search/searchscreen.dart';
import 'package:blinkit_series/repository/screens/print/printscreen.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onCategoriesTap;

  const HomeScreen({super.key, this.onProfileTap, this.onCategoriesTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  int _selectedCategoryIndex = 0;

  Timer? _searchHintTimer;
  final ValueNotifier<int> _searchHintNotifier = ValueNotifier<int>(0);
  final List<String> _searchHints = [
    "milk",
    "atta, dal",
    "chips",
    "diwali lights",
    "chocolates",
    "headphones",
    "face wash",
    "gifts"
  ];

  Map<String, dynamic>? _selectedStoreData = ApiService.memoryCachedStore;
  String? _userSelectedAddress;
  List<Map<String, dynamic>> _liveProducts = [];
  List<Map<String, dynamic>> _liveCategories = [];
  bool _isLoadingLiveProducts = true;
  double _userWalletBalance = 0.0;

  final PageController _sliderPageController = PageController();
  Timer? _sliderAutoTimer;
  final ValueNotifier<int> _currentSliderNotifier = ValueNotifier<int>(0);
  List<Map<String, dynamic>> _sliders = [
    {
      "id": 1,
      "title": "Big Savings Every Day",
      "subtitle": "Fresh products, great quality at lowest prices.",
      "offer_text": "UP TO 50% OFF",
      "image": "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80",
      "category_id": 1,
    },
    {
      "id": 2,
      "title": "Fresh Farm Vegetables",
      "subtitle": "Organically grown, handpicked fresh daily.",
      "offer_text": "MIN 30% OFF",
      "image": "https://images.unsplash.com/photo-1610832958506-aa56368176cf?auto=format&fit=crop&w=1200&q=80",
      "category_id": 1,
    },
  ];
  final Map<String, Uint8List> _base64ImageCache = {};

  Color get _activeThemeColor {
    final hexStr = _selectedStoreData?['banner_color']?.toString().replaceAll('#', '');
    if (hexStr != null && hexStr.length == 6) {
      try {
        return Color(int.parse("0xFF$hexStr"));
      } catch (_) {}
    }
    return const Color(0XFF0C831F);
  }

  void _startSliderAutoTimer() {
    _sliderAutoTimer?.cancel();
    if (_sliders.length <= 1) return;
    _sliderAutoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _sliders.length > 1 && _sliderPageController.hasClients) {
        final nextIdx = (_currentSliderNotifier.value + 1) % _sliders.length;
        _sliderPageController.animateToPage(
          nextIdx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startSliderAutoTimer();
    _fetchLiveBackendData();
    _searchHintTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _searchHintNotifier.value = (_searchHintNotifier.value + 1) % _searchHints.length;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestLocationPermission();
    });
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = false;
    LocationPermission permission = LocationPermission.denied;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );

      if (serviceEnabled) {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      } else {
        // Prompt user to enable location services if disabled
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint("Location permission check error: $e");
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );

        // 1. Fetch user's saved addresses from backend
        String? nearestSavedAddress;
        try {
          final prefs = await SharedPreferences.getInstance();
          final userPhone = prefs.getString('user_phone') ?? '';
          if (userPhone.isNotEmpty) {
            final dbAddresses = await ApiService.getUserAddresses(phone: userPhone);
            double closestDistMeters = double.infinity;
            for (var addr in dbAddresses) {
              final double? aLat = double.tryParse(addr['latitude']?.toString() ?? '');
              final double? aLng = double.tryParse(addr['longitude']?.toString() ?? '');
              if (aLat != null && aLng != null) {
                final double distMeters = Geolocator.distanceBetween(pos.latitude, pos.longitude, aLat, aLng);
                if (distMeters < closestDistMeters) {
                  closestDistMeters = distMeters;
                  nearestSavedAddress = addr['address_details'] ?? addr['custom_type_name'] ?? addr['address_type'];
                }
              }
            }
          }
        } catch (_) {}

        // 2. Query backend for nearest store dynamically based on real GPS lat & lng
        final storeData = await ApiService.fetchSelectedStore(
          lat: pos.latitude,
          lng: pos.longitude,
          forceRefresh: true,
          isManual: false,
        );

        // 3. Reverse geocode to find real area name if no saved address
        final areaName = nearestSavedAddress == null ? await _reverseGeocodeArea(pos.latitude, pos.longitude) : null;
        String finalAddressDisplay = (nearestSavedAddress ?? areaName ?? 'Select Location');

        if (mounted) {
          setState(() {
            _selectedStoreData = storeData;
            _userSelectedAddress = finalAddressDisplay;
            ApiService.saveUserSelectedAddress(finalAddressDisplay);
          });
        }
      } catch (e) {
        debugPrint("Error fetching GPS location & nearest store: $e");
      }
    } else {
      // Permission DENIED:
      // 1. Fetch oldest store added for products (no lat/lng passed -> backend returns oldest store added id asc)
      final oldestStore = await ApiService.fetchSelectedStore(forceRefresh: true);

      if (mounted) {
        setState(() {
          if (oldestStore != null) {
            _selectedStoreData = oldestStore;
          }
          if (_userSelectedAddress == null || _userSelectedAddress!.isEmpty || _userSelectedAddress!.contains('RATANR')) {
            _userSelectedAddress = 'Select Location';
          }
        });

        // 2. Open navigation bottom sheet for user to choose location
        AddressSelectionBottomSheet.show(
          context,
          onAddressSelected: (selectedAddress) {
            if (mounted) {
              setState(() {
                _userSelectedAddress = selectedAddress;
              });
              _fetchLiveBackendData(forceRefresh: true);
            }
          },
        );
      }
    }
  }

  Future<String?> _reverseGeocodeArea(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'SonarbanglaMartApp/1.0',
      }).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final place = address['suburb'] ??
              address['neighbourhood'] ??
              address['village'] ??
              address['town'] ??
              address['city'] ??
              address['county'] ??
              data['name'] ??
              "";
          final district = address['state_district'] ?? address['state'] ?? "";
          if (place.toString().isNotEmpty) {
            return district.isNotEmpty && !place.toString().contains(district.toString())
                ? "$place, $district"
                : "$place";
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchLiveBackendData({bool forceRefresh = false}) async {
    // 1. Immediately fetch user wallet balance & promotional sliders from local storage
    ApiService.fetchUserWallet().then((wallet) {
      if (mounted) {
        setState(() {
          _userWalletBalance = wallet;
        });
      }
    });

    ApiService.fetchSliders(forceRefresh: forceRefresh).then((slidersData) {
      if (mounted && slidersData.isNotEmpty) {
        if (_sliders.length != slidersData.length || jsonEncode(_sliders) != jsonEncode(slidersData)) {
          setState(() {
            _sliders = slidersData;
          });
          _startSliderAutoTimer();
        }
      }
    });

    // 2. Read cached store, user address, categories, and products from local storage
    final cachedStore = await ApiService.fetchSelectedStore(forceRefresh: forceRefresh);
    final savedAddress = await ApiService.getUserSelectedAddress();
    final cachedCats = await ApiService.fetchCategories();
    final cachedProds = await ApiService.fetchProducts(storeId: cachedStore?['id'] ?? 1, forceRefresh: false);

    bool hasAnyData = false;
    if (savedAddress != null && savedAddress.isNotEmpty && mounted) {
      if (_userSelectedAddress == null || _userSelectedAddress!.isEmpty) {
        _userSelectedAddress = savedAddress;
      }
    }
    if (cachedStore != null && mounted) {
      _selectedStoreData = cachedStore;
      hasAnyData = true;
      if (cachedStore['search_hint'] != null && cachedStore['search_hint'].toString().isNotEmpty) {
        final List<String> customHints = cachedStore['search_hint'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (customHints.isNotEmpty) {
          _searchHints.clear();
          _searchHints.addAll(customHints);
        }
      }
    }

    if (cachedCats.isNotEmpty && mounted) {
      _populateCategoriesData(cachedCats);
      hasAnyData = true;
    }

    if (cachedProds.isNotEmpty && mounted) {
      _populateProductsData(cachedProds);
      hasAnyData = true;
    }

    // If local cached data exists, dismiss skeleton loader instantly (0s wait!)
    if (mounted) {
      setState(() {
        _isLoadingLiveProducts = !hasAnyData;
      });
    }

    // Precache all product network images in background so subsequent renders are instant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });

    // 3. Perform silent background version check via /api/v1/sync-check
    _performSmartVersionSync(cachedStore?['id'] ?? 1, forceRefresh);
  }

  Future<void> _performSmartVersionSync(int storeId, bool forceRefresh) async {
    final syncData = await ApiService.checkSyncStatus(storeId: storeId);
    if (syncData != null && syncData['versions'] != null) {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedProdVer = prefs.getString('cache_products_version_v1');
      final String? cachedSliderVer = prefs.getString('cache_sliders_version_v1');
      final String serverProdVer = syncData['versions']['products']?.toString() ?? '';
      final String serverSliderVer = syncData['versions']['sliders']?.toString() ?? '';

      if (forceRefresh || cachedSliderVer == null || cachedSliderVer != serverSliderVer) {
        final freshSliders = await ApiService.fetchSliders(forceRefresh: true);
        if (mounted && freshSliders.isNotEmpty) {
          setState(() {
            _sliders = freshSliders;
          });
          _startSliderAutoTimer();
          prefs.setString('cache_sliders_version_v1', serverSliderVer);
        }
      }

      // Only perform background fetch if version changed or force refresh is true
      if (forceRefresh || cachedProdVer == null || cachedProdVer != serverProdVer) {
        final freshStore = await ApiService.fetchSelectedStore(forceRefresh: true);
        final freshProds = await ApiService.fetchProducts(storeId: storeId, forceRefresh: true);
        if (mounted) {
          setState(() {
            if (freshStore != null) _selectedStoreData = freshStore;
            if (freshProds.isNotEmpty) _populateProductsData(freshProds);
            _isLoadingLiveProducts = false;
          });
          prefs.setString('cache_products_version_v1', serverProdVer);
        }
      }
    }
  }

  void _precacheImages() {
    if (!mounted) return;
    for (var p in _liveProducts) {
      final img = p['image']?.toString();
      if (img != null && (img.startsWith('http://') || img.startsWith('https://'))) {
        precacheImage(CachedNetworkImageProvider(img), context).catchError((_) {});
      }
    }
  }

  void _populateCategoriesData(List<Map<String, dynamic>> categories) {
    setState(() {
      _liveCategories = categories;
      final List<Map<String, dynamic>> updatedHeaderCats = [
        {"name": "All", "icon": Icons.shopping_bag_outlined}
      ];
      for (var c in categories) {
        final bool showHp = c['show_on_homepage'] == true || c['show_on_homepage'] == 1 || c['show_on_homepage'] == '1';
        if (showHp) {
          updatedHeaderCats.add({
            "name": c['name'].toString(),
            "icon": _getCategoryIconData(c['icon']?.toString()),
          });
        }
      }
      if (updatedHeaderCats.length > 1) {
        _headerCategories.clear();
        _headerCategories.addAll(updatedHeaderCats);
      }
    });
  }

  void _populateProductsData(List<Map<String, dynamic>> prods) {
    setState(() {
      _liveProducts = prods;
      featuredItems.clear();
      groceryKitchenItems.clear();
      for (var p in prods) {
        final double price = double.tryParse(p['effective_price']?.toString() ?? p['price']?.toString() ?? '0') ?? 0.0;
        final double mrp = double.tryParse(p['effective_mrp']?.toString() ?? p['mrp']?.toString() ?? '0') ?? price;
        final String img = p['image'] ?? 'http://images.unsplash.com/photo-1542838132-92c53300491e?w=500&q=80';
        final mapItem = {
          "id": p['id'].toString(),
          "img": img,
          "text": p['name'].toString(),
          "name": p['name'].toString(),
          "unit": p['unit'] ?? '1 pc',
          "price": price,
          "mrp": mrp,
        };
        final isFeatured = p['is_featured'] == 1 || p['is_featured'] == '1' || p['is_featured'] == true || p['is_featured'] == 'true';
        if (isFeatured) {
          featuredItems.add(mapItem);
        }
        groceryKitchenItems.add(mapItem);

        final catName = p['category']?['name']?.toString() ?? p['category_name']?.toString();
        if (catName != null && catName.isNotEmpty) {
          _categoryProducts.putIfAbsent(catName, () => []);
          if (!_categoryProducts[catName]!.any((item) => item['id'] == mapItem['id'])) {
            _categoryProducts[catName]!.add(mapItem);
          }
          for (var key in _categoryProducts.keys) {
            if (catName.toLowerCase().contains(key.toLowerCase()) || key.toLowerCase().contains(catName.toLowerCase())) {
              if (!_categoryProducts[key]!.any((item) => item['id'] == mapItem['id'])) {
                _categoryProducts[key]!.add(mapItem);
              }
            }
          }
        }
      }
      if (featuredItems.isEmpty && groceryKitchenItems.isNotEmpty) {
        featuredItems.addAll(groceryKitchenItems.take(5));
      }
    });
  }

  IconData _getCategoryIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'festival_outlined':
        return Icons.festival_outlined;
      case 'headphones_outlined':
        return Icons.headphones_outlined;
      case 'brush_outlined':
        return Icons.brush_outlined;
      case 'card_giftcard_outlined':
        return Icons.card_giftcard_outlined;
      case 'local_hospital_outlined':
        return Icons.local_hospital_outlined;
      case 'pets_outlined':
        return Icons.pets_outlined;
      case 'toys_outlined':
        return Icons.toys_outlined;
      case 'fastfood_outlined':
        return Icons.fastfood_outlined;
      case 'local_drink_outlined':
        return Icons.local_drink_outlined;
      case 'local_grocery_store_outlined':
        return Icons.local_grocery_store_outlined;
      case 'shopping_bag_outlined':
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  final List<Map<String, dynamic>> _headerCategories = [
    {"name": "All", "icon": Icons.shopping_bag_outlined},
    {"name": "Ganeshotsav", "icon": Icons.festival_outlined},
    {"name": "Electronics", "icon": Icons.headphones_outlined},
    {"name": "Beauty", "icon": Icons.brush_outlined},
    {"name": "Gifting", "icon": Icons.card_giftcard_outlined},
    {"name": "Pharmacy", "icon": Icons.local_hospital_outlined},
    {"name": "Pet Care", "icon": Icons.pets_outlined},
    {"name": "Toys", "icon": Icons.toys_outlined},
  ];

  final List<Map<String, String>> megaSaleData = [
    {"img": "image 50.png", "text": "Lights, Diyas \n & Candles"},
    {"img": "image 51.png", "text": "Diwali \n Gifts"},
    {"img": "image 52.png", "text": "Appliances  \n & Gadgets"},
    {"img": "image 53.png", "text": "Home \n & Living"}
  ];

  final List<Map<String, dynamic>> featuredItems = [
    {"id": "feat_1", "img": "image 54.png", "text": "Golden Glass\n Wooden Lid Candle (Oudh)", "price": 79.0},
    {"id": "feat_2", "img": "image 57.png", "text": "Royal Gulab Jamun\n By Bikano", "price": 149.0},
    {"id": "feat_3", "img": "image 63.png", "text": "Golden Glass\n Wooden Lid Candle (Oudh)", "price": 79.0},
  ];

  final List<Map<String, dynamic>> groceryKitchenItems = [
    {"id": "groc_1", "img": "image 41.png", "text": "Vegetables & \nFruits", "price": 49.0},
    {"id": "groc_2", "img": "image 42.png", "text": "Atta, Dal & \nRice", "price": 199.0},
    {"id": "groc_3", "img": "image 43.png", "text": "Oil, Ghee & \nMasala", "price": 165.0},
    {"id": "groc_4", "img": "image 44 (1).png", "text": "Dairy, Bread & \nMilk", "price": 33.0},
    {"id": "groc_5", "img": "image 45 (1).png", "text": "Biscuits & \nBakery", "price": 40.0}
  ];

  // Specific Category Products Database
  final Map<String, List<Map<String, dynamic>>> _categoryProducts = {
    "Ganeshotsav": [
      {"id": "gan_1", "name": "Assorted Panch Phal for Pooja", "unit": "1 pack", "price": 89.0, "mrp": 110.0, "img": "image 41.png"},
      {"id": "gan_2", "name": "Fresh Hibiscus Flowers (Gudhal)", "unit": "5 pcs", "price": 9.0, "mrp": 10.0, "img": "image 41.png"},
      {"id": "gan_3", "name": "Mix Marigold Garland 3.5ft", "unit": "1 pc", "price": 62.0, "mrp": 73.0, "img": "image 41.png"},
      {"id": "gan_4", "name": "Durva Grass / Doob Grass", "unit": "1 pack", "price": 15.0, "mrp": 18.0, "img": "image 41.png"},
    ],
    "Electronics": [
      {"id": "elec_1", "name": "Wireless Stereo Headphones", "unit": "1 unit", "price": 899.0, "mrp": 1499.0, "img": "image 52.png"},
      {"id": "elec_2", "name": "Fast Charging Powerbank 10000mAh", "unit": "1 unit", "price": 699.0, "mrp": 1199.0, "img": "image 52.png"},
      {"id": "elec_3", "name": "Type-C Braided Cable 1.5m", "unit": "1 pc", "price": 199.0, "mrp": 399.0, "img": "image 52.png"},
    ],
    "Beauty": [
      {"id": "bt_1", "name": "Matte Lipstick Velvet Red", "unit": "1 pc", "price": 249.0, "mrp": 350.0, "img": "image 35.png"},
      {"id": "bt_2", "name": "Nourishing Herbal Hair Oil", "unit": "200 ml", "price": 135.0, "mrp": 175.0, "img": "image 35.png"},
      {"id": "bt_3", "name": "Hydrating Face Moisturizer", "unit": "100 g", "price": 180.0, "mrp": 250.0, "img": "image 35.png"},
    ],
    "Gifting": [
      {"id": "gift_1", "name": "Diwali Royal Gift Hamper", "unit": "1 box", "price": 499.0, "mrp": 699.0, "img": "image 51.png"},
      {"id": "gift_2", "name": "Premium Assorted Chocolates", "unit": "300 g", "price": 299.0, "mrp": 399.0, "img": "image 51.png"},
      {"id": "gift_3", "name": "Decorative Brass Diya Set", "unit": "2 pcs", "price": 199.0, "mrp": 299.0, "img": "image 50.png"},
    ],
    "Pharmacy": [
      {"id": "pharm_1", "name": "First Aid Medical Kit", "unit": "1 kit", "price": 199.0, "mrp": 250.0, "img": "image 41.png"},
      {"id": "pharm_2", "name": "Vitamin C Immunity Tablets", "unit": "60 tabs", "price": 149.0, "mrp": 200.0, "img": "image 41.png"},
    ],
    "Pet Care": [
      {"id": "pet_1", "name": "Adult Dog Food Chicken & Rice", "unit": "1.2 kg", "price": 320.0, "mrp": 400.0, "img": "image 41.png"},
      {"id": "pet_2", "name": "Interactive Rubber Pet Toy", "unit": "1 pc", "price": 99.0, "mrp": 150.0, "img": "image 41.png"},
    ],
    "Toys": [
      {"id": "toy_1", "name": "Diecast Metal Toy Car", "unit": "1 pc", "price": 149.0, "mrp": 220.0, "img": "image 52.png"},
      {"id": "toy_2", "name": "3x3 Speed Puzzle Cube", "unit": "1 pc", "price": 89.0, "mrp": 149.0, "img": "image 52.png"},
    ],
  };

  @override
  void dispose() {
    _searchHintTimer?.cancel();
    _sliderAutoTimer?.cancel();
    _searchHintNotifier.dispose();
    _currentSliderNotifier.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCatName = _headerCategories[_selectedCategoryIndex]["name"] as String;
    final bool isAllSelected = _selectedCategoryIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      body: _isLoadingLiveProducts
          ? SkeletonLoader.homePageFullSkeleton()
          : RefreshIndicator(
              onRefresh: () => _fetchLiveBackendData(forceRefresh: true),
              color: _activeThemeColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // 1. Fresh Customizable Header Banner
            Container(
              decoration: BoxDecoration(
                color: _activeThemeColor,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Top Row: Delivery Time, Location & Wallet/Profile Icons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
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
                                      : "SB Mart in 18 minutes",
                                  style: TextStyle(
                                    color: (_selectedStoreData?['is_serviceable'] ?? true) ? Colors.white70 : const Color(0XFFFFEB3B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _selectedStoreData != null
                                      ? ((_selectedStoreData!['is_serviceable'] ?? true)
                                          ? "${_selectedStoreData!['name'] ?? 'Dark Store'}"
                                          : "No Store Delivers Here")
                                      : "18 minutes",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
                                            _userSelectedAddress = selectedAddress;
                                          });
                                        }
                                        _fetchLiveBackendData(forceRefresh: true);
                                      },
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _userSelectedAddress != null && _userSelectedAddress!.isNotEmpty
                                              ? _userSelectedAddress!
                                              : "Select Location",
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

                          // Wallet Pill & Profile Avatar
                          Row(
                            children: [
                              // Interactive Clickable Wallet Pill with Ripple Effect
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.account_balance_wallet, color: Color(0XFFF7CB45)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Wallet Balance: ₹${_userWalletBalance % 1 == 0 ? _userWalletBalance.toInt() : _userWalletBalance.toStringAsFixed(1)} (Cashback Ready)",
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(0XFF212121),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            color: Color(0XFFF7CB45),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.account_balance_wallet, color: _activeThemeColor, size: 16),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0XFF212121),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            "₹${_userWalletBalance % 1 == 0 ? _userWalletBalance.toInt() : _userWalletBalance.toStringAsFixed(1)}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Interactive Clickable Profile Avatar Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onProfileTap != null) {
                                      widget.onProfileTap!();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Opening Profile & Account Details..."),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0XFF3E1B00),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Search Bar with right vertical divider & mic icon & animated sliding hint text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SearchScreen(
                                allProducts: _liveProducts.isNotEmpty ? _liveProducts : groceryKitchenItems,
                                initialQuery: searchController.text,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search, color: Colors.black87, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    if (searchController.text.isEmpty)
                                      IgnorePointer(
                                        child: Row(
                                          children: [
                                            const Text(
                                              'Search ',
                                              style: TextStyle(
                                                color: Color(0XFF5C6BC0),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            ClipRect(
                                              child: ValueListenableBuilder<int>(
                                                valueListenable: _searchHintNotifier,
                                                builder: (context, hintIndex, _) {
                                                  return AnimatedSwitcher(
                                                    duration: const Duration(milliseconds: 400),
                                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                                      final inAnimation = Tween<Offset>(
                                                        begin: const Offset(0, 1.0),
                                                        end: Offset.zero,
                                                      ).animate(animation);
                                                      final outAnimation = Tween<Offset>(
                                                        begin: const Offset(0, -1.0),
                                                        end: Offset.zero,
                                                      ).animate(animation);

                                                      if (child.key == ValueKey<int>(hintIndex)) {
                                                        return SlideTransition(
                                                          position: inAnimation,
                                                          child: FadeTransition(opacity: animation, child: child),
                                                        );
                                                      } else {
                                                        return SlideTransition(
                                                          position: outAnimation,
                                                          child: FadeTransition(opacity: animation, child: child),
                                                        );
                                                      }
                                                    },
                                                    child: Text(
                                                      '"${_searchHints[hintIndex]}"',
                                                      key: ValueKey<int>(hintIndex),
                                                      style: const TextStyle(
                                                        color: Color(0XFF5C6BC0),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    TextField(
                                      controller: searchController,
                                      readOnly: false,
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          final typedValue = value;
                                          searchController.clear();
                                          final hexStr = _selectedStoreData?['banner_color']?.toString().replaceAll('#', '');
                                          final Color activeTheme = (hexStr != null && hexStr.length == 6)
                                              ? Color(int.parse("0xFF$hexStr"))
                                              : const Color(0XFF0C831F);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => SearchScreen(
                                                allProducts: _liveProducts.isNotEmpty ? _liveProducts : groceryKitchenItems,
                                                initialQuery: typedValue,
                                                themeColor: _activeThemeColor,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onTap: () {
                                        final hexStr = _selectedStoreData?['banner_color']?.toString().replaceAll('#', '');
                                        final Color activeTheme = (hexStr != null && hexStr.length == 6)
                                            ? Color(int.parse("0xFF$hexStr"))
                                            : const Color(0XFF0C831F);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => SearchScreen(
                                              allProducts: _liveProducts.isNotEmpty ? _liveProducts : groceryKitchenItems,
                                              initialQuery: searchController.text,
                                              themeColor: activeTheme,
                                            ),
                                          ),
                                        );
                                      },
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_selectedStoreData != null && _selectedStoreData!['is_serviceable'] == false) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0XFFE53935), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off, color: Color(0XFFE53935), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedStoreData!['closure_reason'] ?? "We currently do not deliver to this location.",
                                  style: const TextStyle(
                                    color: Color(0XFFD32F2F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Scrollable Header Categories Row
                    SizedBox(
                      height: 62,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _headerCategories.length,
                        itemBuilder: (context, index) {
                          final cat = _headerCategories[index];
                          final bool isSelected = _selectedCategoryIndex == index;

                          return InkWell(
                            onTap: () {
                              if (index == 0) {
                                setState(() {
                                  _selectedCategoryIndex = 0;
                                });
                              } else {
                                final String catName = cat["name"]?.toString() ?? "Category";
                                final matchedCat = _liveCategories.firstWhere(
                                  (c) => (c['name']?.toString() ?? '').toLowerCase().trim() == catName.toLowerCase().trim(),
                                  orElse: () => <String, dynamic>{},
                                );
                                final int? catId = matchedCat.isNotEmpty
                                    ? (matchedCat['id'] is int ? matchedCat['id'] : int.tryParse(matchedCat['id']?.toString() ?? ''))
                                    : null;
                                final String catImg = matchedCat['image']?.toString() ?? matchedCat['asset']?.toString() ?? "";

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CategoryProductsScreen(
                                      categoryName: catName,
                                      categoryImg: catImg,
                                      categoryId: catId,
                                    ),
                                  ),
                                );
                              }
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    cat["icon"] as IconData,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  Text(
                                    cat["name"] as String,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    height: 3,
                                    width: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            if (isAllSelected) ...[
              // ---------------- REDESIGNED CONTENT AREA ACCORDING TO REFERENCE DESIGN ----------------

              const SizedBox(height: 12),

              // 1. Promotional Slider Banner (Dynamic from Admin Panel)
              _buildPromotionalSlider(),

              const SizedBox(height: 16),

              // 2. Categories Section
              _buildCategoriesSection(),

              const SizedBox(height: 18),

              // 3. Our Bestsellers Section
              _buildProductSection(
                icon: "🔥",
                title: "Our Bestsellers",
                products: _liveProducts.where((p) => p['is_bestseller'] == true || p['is_bestseller'] == 1 || p['is_bestseller'] == '1').isNotEmpty
                    ? _liveProducts.where((p) => p['is_bestseller'] == true || p['is_bestseller'] == 1 || p['is_bestseller'] == '1').toList()
                    : (_liveProducts.isNotEmpty ? _liveProducts.take(10).toList() : _bestsellersList),
              ),

              const SizedBox(height: 18),

              // 4. Super Savings Section
              _buildProductSection(
                icon: "⚡",
                title: "Super Savings",
                products: _liveProducts.where((p) => p['is_featured'] == true || p['is_featured'] == 1 || p['is_featured'] == '1').isNotEmpty
                    ? _liveProducts.where((p) => p['is_featured'] == true || p['is_featured'] == 1 || p['is_featured'] == '1').toList()
                    : (_liveProducts.length > 5 ? _liveProducts.skip(5).take(10).toList() : _superSavingsList),
              ),

              const SizedBox(height: 30),
            ] else ...[
              // ---------------- SPECIFIC CATEGORY VIEW WHEN SPECIFIC CATEGORY IS SELECTED ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedCatName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "${(_categoryProducts[selectedCatName] ?? []).length} items",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0XFF757575),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.76,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: (_categoryProducts[selectedCatName] ?? []).length,
                itemBuilder: (context, index) {
                  final item = _categoryProducts[selectedCatName]![index];
                  final String id = item["id"];
                  final String name = item["name"];
                  final String unit = item["unit"];
                  final double price = (item["price"] as num).toDouble();
                  final double mrp = (item["mrp"] as num).toDouble();
                  final String img = item["img"];

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0XFFF9F9F9),
                              child: UiHelper.CustomImage(
                                img: img,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0XFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "₹${price.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "₹${mrp.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0XFF9E9E9E),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedCartButton(
                              id: id,
                              name: name,
                              img: img,
                              price: price,
                              unit: unit,
                              maxStock: int.tryParse(item["available_stock"]?.toString() ?? item["stock"]?.toString() ?? '10'),
                              width: 62,
                              height: 28,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],

            // 5. Unserviceable location bottom red warning banner (matching exact user screenshot)
            if (_selectedStoreData != null && (_selectedStoreData!['is_serviceable'] == false || _selectedStoreData!['is_operational'] == false)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: const Color(0XFFE53935),
                child: Text(
                  _selectedStoreData!['closure_reason']?.toString() ??
                      "We are currently not available at your location. Distance to nearest store is 44.7 km (Coverage limit: 5.00 km).",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  // ---------------- REFERENCE DESIGN HOMESCREEN HELPER COMPONENTS ----------------

  final List<Map<String, dynamic>> _bestsellersList = [
    {
      "id": "best_1",
      "name": "Banana (1 Kg)",
      "price": 36.0,
      "mrp": 40.0,
      "discount": "10% OFF",
      "img": "image 50.png",
    },
    {
      "id": "best_2",
      "name": "Amul Taaza Toned Milk (1 L)",
      "price": 58.0,
      "mrp": 61.0,
      "discount": "5% OFF",
      "img": "image 51.png",
    },
    {
      "id": "best_3",
      "name": "Lay's Classic Chips (52g)",
      "price": 20.0,
      "mrp": 23.0,
      "discount": "12% OFF",
      "img": "image 52.png",
    },
    {
      "id": "best_4",
      "name": "Eggs (6 Pcs)",
      "price": 36.0,
      "mrp": 39.0,
      "discount": "8% OFF",
      "img": "image 53.png",
    },
  ];

  final List<Map<String, dynamic>> _superSavingsList = [
    {
      "id": "sav_1",
      "name": "India Gate Basmati Rice (5 Kg)",
      "price": 449.0,
      "mrp": 529.0,
      "discount": "15% OFF",
      "img": "image 50.png",
    },
    {
      "id": "sav_2",
      "name": "Fortune Sunlite Oil (1 L)",
      "price": 132.0,
      "mrp": 149.0,
      "discount": "12% OFF",
      "img": "image 51.png",
    },
    {
      "id": "sav_3",
      "name": "Surf Excel Detergent (1 Kg)",
      "price": 159.0,
      "mrp": 199.0,
      "discount": "20% OFF",
      "img": "image 52.png",
    },
    {
      "id": "sav_4",
      "name": "Maggi Noodles (70g)",
      "price": 14.0,
      "mrp": 17.0,
      "discount": "18% OFF",
      "img": "image 53.png",
    },
  ];

  Widget _buildPromotionalSlider() {
    final List<Map<String, dynamic>> activeSliders = _sliders;

    if (activeSliders.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildSingleBannerItem(Map<String, dynamic> slider) {
      String rawImg = slider['image']?.toString() ?? '';
      String imgUrl = rawImg.trim();
      if (!imgUrl.startsWith('data:') && !imgUrl.startsWith('http') && !imgUrl.startsWith('assets/') && imgUrl.isNotEmpty) {
        if (imgUrl.contains('localhost')) {
          imgUrl = imgUrl.replaceAll(RegExp(r'^https?://[^/]+/'), '');
        }
        final String cleanPath = imgUrl.startsWith('/') ? imgUrl.substring(1) : imgUrl;
        imgUrl = "https://admin.sbmartquick.com/$cleanPath";
      } else if (imgUrl.contains('sbmartquick.com/uploads/')) {
        final String uploadPath = imgUrl.substring(imgUrl.indexOf('uploads/'));
        imgUrl = "https://admin.sbmartquick.com/$uploadPath";
      }

      final dynamic catIdRaw = slider['category_id'];
      final int? catId = catIdRaw != null ? int.tryParse(catIdRaw.toString()) : null;
      final String? redirectUrl = slider['redirect_url']?.toString();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0XFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (catId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CategoryProductsScreen(
                      categoryName: slider['title']?.toString() ?? "Vegetables & Fruits",
                      categoryImg: imgUrl,
                      categoryId: catId,
                    ),
                  ),
                );
              } else if (redirectUrl != null && redirectUrl.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      allProducts: _liveProducts,
                      initialQuery: redirectUrl,
                    ),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CategoryProductsScreen(
                      categoryName: "Vegetables & Fruits",
                      categoryImg: "https://admin.sbmartquick.com/uploads/categories/01_vegetables_fruits.png",
                      categoryId: 1,
                    ),
                  ),
                );
              }
            },
            child: imgUrl.startsWith('data:image/')
                ? Image.memory(
                    _base64ImageCache.putIfAbsent(imgUrl, () => base64Decode(imgUrl.split(',').last)),
                    key: ValueKey(imgUrl),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  )
                : UiHelper.CustomImage(
                    img: imgUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.fill,
                  ),
          ),
        ),
      );
    }

    if (activeSliders.length == 1) {
      return Column(
        children: [
          SizedBox(
            height: 180,
            child: buildSingleBannerItem(activeSliders[0]),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _sliderPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: activeSliders.length,
            onPageChanged: (index) {
              _currentSliderNotifier.value = index;
            },
            itemBuilder: (context, index) {
              return buildSingleBannerItem(activeSliders[index]);
            },
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: _currentSliderNotifier,
          builder: (context, currentIndex, _) {
            final hexStr = _selectedStoreData?['banner_color']?.toString().replaceAll('#', '');
            final Color activeTheme = (hexStr != null && hexStr.length == 6)
                ? Color(int.parse("0xFF$hexStr"))
                : const Color(0XFF0C831F);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                activeSliders.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 5,
                  width: currentIndex == index ? 18 : 5,
                  decoration: BoxDecoration(
                    color: currentIndex == index ? activeTheme : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    List<Map<String, dynamic>> categoryCards = [];

    if (_liveCategories.isNotEmpty) {
      final sortedCats = List<Map<String, dynamic>>.from(_liveCategories);
      sortedCats.sort((a, b) {
        int orderA = int.tryParse(a['display_order']?.toString() ?? '999') ?? 999;
        int orderB = int.tryParse(b['display_order']?.toString() ?? '999') ?? 999;
        return orderA.compareTo(orderB);
      });
      categoryCards = sortedCats.take(4).toList();
    }

    if (categoryCards.isEmpty) {
      categoryCards = [
        {
          "id": 1,
          "name": "Vegetables & Fruits",
          "image": "https://sbmartquick.com/uploads/categories/01_vegetables_fruits.png",
          "asset": "assets/images/01_vegetables_fruits.png",
        },
        {
          "id": 2,
          "name": "Dairy, Bread & Eggs",
          "image": "https://sbmartquick.com/uploads/categories/02_dairy_bread_eggs.png",
          "asset": "assets/images/02_dairy_bread_eggs.png",
        },
        {
          "id": 3,
          "name": "Snacks & Beverages",
          "image": "https://sbmartquick.com/uploads/categories/03_snacks_beverages.png",
          "asset": "assets/images/03_snacks_beverages.png",
        },
        {
          "id": 4,
          "name": "Personal Care",
          "image": "https://sbmartquick.com/uploads/categories/04_personal_care.png",
          "asset": "assets/images/04_personal_care.png",
        },
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              InkWell(
                onTap: () {
                  if (widget.onCategoriesTap != null) {
                    widget.onCategoriesTap!();
                  } else {
                    final firstCat = categoryCards.first;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          categoryName: firstCat['name']?.toString() ?? "Vegetables & Fruits",
                          categoryImg: firstCat['image']?.toString() ?? firstCat['asset'] ?? "",
                          categoryId: int.tryParse(firstCat['id']?.toString() ?? '1') ?? 1,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeThemeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View All",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _activeThemeColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 12, color: _activeThemeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(categoryCards.length, (index) {
              final cat = categoryCards[index];
              final int catId = int.tryParse(cat["id"]?.toString() ?? '${index + 1}') ?? (index + 1);
              final String catName = cat["name"]?.toString() ?? "Category";
              final String imgUrl = cat["image"]?.toString() ?? cat["asset"]?.toString() ?? "";

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            categoryName: catName,
                            categoryImg: imgUrl,
                            categoryId: catId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 65,
                              width: double.infinity,
                              child: UiHelper.CustomImage(
                                img: imgUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            catName,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProductSection({
    required String icon,
    required String title,
    required List<Map<String, dynamic>> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SectionProductsScreen(
                        title: title,
                        icon: icon,
                        products: products,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeThemeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View All",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _activeThemeColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 12, color: _activeThemeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              final String name = (item["name"] ?? item["text"] ?? "").toString();
              final double price = double.tryParse(item["price"]?.toString() ?? '0') ?? 0.0;
              final double mrp = double.tryParse(item["mrp"]?.toString() ?? '') ?? (price * 1.15);
              final String img = (item["image"] != null && item["image"].toString().isNotEmpty) ? item["image"].toString() : (item["img"]?.toString() ?? "image 50.png");
              final String discount = item["discount"]?.toString() ?? "${(((mrp - price) / (mrp > 0 ? mrp : 1)) * 100).round()}% OFF";
              final String id = item["id"]?.toString() ?? "prod_$index";

              return Container(
                width: 148,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0XFFE0E0E0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => ProductDetailDialog.show(context, item),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: Stack(
                          children: [
                            Container(
                              height: 115,
                              width: double.infinity,
                              color: const Color(0XFFF9F9F9),
                              child: UiHelper.CustomImage(
                                img: img,
                                width: double.infinity,
                                height: 115,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (discount.isNotEmpty)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _activeThemeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    discount,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  height: 1.15,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "₹${price.toInt()}",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (mrp > price)
                                        Text(
                                          "₹${mrp.toInt()}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                    ],
                                  ),
                                  AnimatedCartButton(
                                    id: id,
                                    name: name.replaceAll('\n', ' '),
                                    img: img,
                                    price: price,
                                    maxStock: int.tryParse(item["available_stock"]?.toString() ?? item["stock"]?.toString() ?? '10'),
                                    width: 58,
                                    height: 28,
                                    themeColor: _activeThemeColor,
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBulkOrderCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0XFFF7CB45), Color(0XFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_rounded, size: 26, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Bulk & Custom Orders",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                SizedBox(height: 2),
                Text(
                  "Custom items, printouts & bulk orders delivered to you!",
                  style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrintScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Order", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
