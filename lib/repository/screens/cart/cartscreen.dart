import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/address_selection_bottom_sheet.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/screens/cart/couponsscreen.dart';
import 'package:blinkit_series/repository/screens/cart/orderstatusscreen.dart';
import 'package:share_plus/share_plus.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const CartScreen({super.key, this.onBackTap});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartController _cart = CartController.instance;

  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoadingRecs = false;

  // Coupon State
  Map<String, dynamic>? _appliedCoupon;
  double _couponDiscountAmount = 0.0;

  // Delivery vs Store Pickup Mode State
  bool _isPickupSelected = false; // false = Delivery, true = Store Pickup
  DateTime _selectedPickupDate = DateTime.now();
  String _selectedPickupTimeSlot = "10:00 AM - 11:00 AM";

  // Operating Store Hours
  final String _storeOpeningTime = "06:00 AM";
  final String _storeClosingTime = "11:00 PM";

  final List<String> _allPickupSlots = [
    "07:00 AM - 08:00 AM",
    "08:00 AM - 09:00 AM",
    "09:00 AM - 10:00 AM",
    "10:00 AM - 11:00 AM",
    "11:00 AM - 12:00 PM",
    "12:00 PM - 01:00 PM",
    "02:00 PM - 03:00 PM",
    "04:00 PM - 05:00 PM",
    "06:00 PM - 07:00 PM",
    "08:00 PM - 09:00 PM",
    "09:00 PM - 10:00 PM",
  ];

  double get _freeDeliveryThreshold => _cart.freeDeliveryThreshold > 0 ? _cart.freeDeliveryThreshold : 299.0;

  final List<Map<String, dynamic>> _defaultRecommendations = [
    {
      "id": "yml_1",
      "name": "Tejas Pure Ghee Diya",
      "unit": "30 pcs",
      "price": 86.0,
      "mrp": 95.0,
      "discount": "9% OFF",
      "img": "image 50.png",
    },
    {
      "id": "yml_2",
      "name": "Long Cotton Wicks",
      "unit": "100 pcs",
      "price": 22.0,
      "mrp": 40.0,
      "discount": "45% OFF",
      "img": "image 50.png",
    },
    {
      "id": "yml_3",
      "name": "Fresh Mix Marigold Flowers",
      "unit": "100 g",
      "price": 35.0,
      "mrp": 44.0,
      "discount": "20% OFF",
      "img": "image 41.png",
    },
    {
      "id": "yml_4",
      "name": "Amul Taaza T-Special Milk",
      "unit": "500 ml",
      "price": 27.0,
      "mrp": 28.0,
      "discount": "4% OFF",
      "img": "image 44 (1).png",
    },
  ];

  List<Map<String, dynamic>> _savedAddresses = [];
  String _selectedDeliveryAddress = "";
  String _selectedDeliveryTag = "Location";
  double? _selectedLat;
  double? _selectedLng;
  bool _hasSavedAddressInArea = false;
  Map<String, dynamic>? _selectedSpecialDealItem;
  double _walletBalance = 0.0;
  bool _useWallet = false;

  Map<String, dynamic>? _activeStore;
  bool _isWithinCoverage = true;
  double _calculatedDistanceKm = 0.0;

  bool get _isStoreClosed {
    if (_activeStore != null) {
      final op = _activeStore!['is_operational'];
      if (op == false || op == 0 || op == '0' || op == 'false') {
        return true;
      }
      final reason = (_activeStore!['closure_reason'] ?? _activeStore!['operational_reason'])?.toString().toLowerCase() ?? '';
      if (reason.contains('closed')) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _cart.addListener(_update);
    _loadCategoryRecommendations();
    _autoSelectAvailablePickupSlot();
    _fetchUserAddresses();
    _fetchRandomSpecialDealItem();
    _fetchUserWalletBalance();
  }

  Future<void> _fetchUserWalletBalance() async {
    try {
      final bal = await ApiService.fetchUserWallet();
      if (mounted) {
        setState(() {
          _walletBalance = bal;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRandomSpecialDealItem() async {
    try {
      final products = await ApiService.fetchProducts(storeId: 1);
      if (products.isEmpty) return;

      final cartItemIds = _cart.items.keys.map((k) => k.toString()).toSet();

      var candidates = products.where((p) {
        final pid = (p['id'] ?? p['product_id'] ?? '').toString();
        final isDeal = (p['is_special_deal'] == true || p['is_special_deal'] == 1 || p['is_special_deal'] == '1');
        return isDeal && !cartItemIds.contains(pid);
      }).toList();

      if (candidates.isEmpty) {
        candidates = products.where((p) {
          final pid = (p['id'] ?? p['product_id'] ?? '').toString();
          return !cartItemIds.contains(pid);
        }).toList();
      }

      if (candidates.isNotEmpty && mounted) {
        candidates.shuffle();
        setState(() {
          _selectedSpecialDealItem = candidates.first;
        });
      }
    } catch (e) {
      debugPrint("Error fetching random special deal: $e");
    }
  }

  Future<void> _fetchUserAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone') ?? '';
    final homeLocation = await ApiService.getUserSelectedAddress();
    final addresses = await ApiService.getUserAddresses(phone: userPhone);

    double? userLat = prefs.getDouble('user_selected_lat') ?? double.tryParse(prefs.getString('user_selected_lat') ?? '');
    double? userLng = prefs.getDouble('user_selected_lng') ?? double.tryParse(prefs.getString('user_selected_lng') ?? '');

    String currentLoc = (homeLocation != null && homeLocation.isNotEmpty) ? homeLocation : "";
    bool hasSaved = false;
    String matchedAddress = currentLoc;
    String tag = 'Selected Location';

    if (addresses.isNotEmpty) {
      _savedAddresses = addresses;
      Map<String, dynamic>? matched;
      for (var addr in addresses) {
        final detail = (addr['address_details'] ?? '').toString().toLowerCase();
        final locLower = currentLoc.toLowerCase();
        if (locLower.isNotEmpty && (detail.contains(locLower) || locLower.contains(detail))) {
          matched = addr;
          break;
        }
      }
      if (matched != null) {
        matchedAddress = matched['address_details'] ?? currentLoc;
        tag = matched['address_type'] ?? matched['custom_type_name'] ?? 'Home';
        hasSaved = true;
        if (matched['latitude'] != null && matched['longitude'] != null) {
          userLat = double.tryParse(matched['latitude'].toString());
          userLng = double.tryParse(matched['longitude'].toString());
        }
      }
    }

    final storeDetails = await ApiService.fetchSelectedStoreDetails(lat: userLat, lng: userLng);
    final store = storeDetails['store'] as Map<String, dynamic>? ?? await ApiService.fetchSelectedStore(forceRefresh: true);
    final bool isCoverage = storeDetails['is_within_coverage'] ?? true;
    final double distKm = storeDetails['calculated_distance_km'] ?? 0.0;

    if (!mounted) return;

    if (store != null) {
      _cart.updateStoreSettings(
        deliveryFee: double.tryParse(store['delivery_fee']?.toString() ?? '15.0') ?? 15.0,
        freeThreshold: double.tryParse(store['free_delivery_threshold']?.toString() ?? '299.0') ?? 299.0,
        minOrder: double.tryParse(store['min_order_amount']?.toString() ?? '0.0') ?? 0.0,
      );
    }

    if (currentLoc.isEmpty && store != null) {
      currentLoc = "${store['address'] ?? ''}${store['city'] != null ? ', ${store['city']}' : ''}".trim();
    }

    setState(() {
      _activeStore = store;
      _isWithinCoverage = isCoverage;
      _calculatedDistanceKm = distKm;
      _selectedLat = userLat;
      _selectedLng = userLng;
      _selectedDeliveryAddress = matchedAddress.isNotEmpty ? matchedAddress : (currentLoc.isNotEmpty ? currentLoc : "Select Location");
      _selectedDeliveryTag = hasSaved ? tag : (store?['name'] ?? 'Selected Location');
      _hasSavedAddressInArea = _selectedDeliveryAddress.isNotEmpty && _selectedDeliveryAddress != "Select Location";
    });
  }

  // Verify stock availability of all items currently in cart when store changes
  Future<void> _checkStockAvailabilityForStore(int storeId) async {
    if (_cart.items.isEmpty) return;

    final storeProducts = await ApiService.fetchProducts(storeId: storeId, forceRefresh: true);
    final storeProdMap = {for (var p in storeProducts) p['id'].toString(): p};

    List<String> outOfStockItems = [];
    _cart.items.forEach((key, item) {
      final p = storeProdMap[key];
      if (p == null) {
        outOfStockItems.add(item.name);
      } else {
        final int availStock = int.tryParse(p['available_stock']?.toString() ?? '0') ?? 0;
        final bool isAvailable = p['is_available'] == true || p['is_available'] == 1 || p['is_available'] == '1';
        if (!isAvailable || availStock < item.quantity) {
          outOfStockItems.add(item.name);
        }
      }
    });

    if (outOfStockItems.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text("Stock Alert"),
            ],
          ),
          content: Text(
            "The following item(s) in your cart are out of stock or unavailable at the newly selected store location:\n\n• ${outOfStockItems.join('\n• ')}\n\nPlease review or remove these items before placing your order.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  // Dynamic Time-Slot Filtering Engine for Pickup Mode
  List<String> _getAvailablePickupSlots() {
    final now = DateTime.now();
    final bool isToday = _selectedPickupDate.year == now.year &&
        _selectedPickupDate.month == now.month &&
        _selectedPickupDate.day == now.day;

    if (!isToday) {
      return _allPickupSlots;
    }

    // Filter out past hours for today
    final currentHour = now.hour;
    final available = _allPickupSlots.where((slot) {
      final startHourStr = slot.split(" ")[0]; // "07:00"
      final parts = startHourStr.split(":");
      int hour = int.parse(parts[0]);
      final isPM = slot.contains("PM") && !slot.startsWith("12");
      if (isPM && hour < 12) hour += 12;
      if (slot.startsWith("12:00 PM")) hour = 12;
      if (slot.startsWith("12:00 AM")) hour = 0;

      return hour > currentHour;
    }).toList();

    return available.isNotEmpty ? available : _allPickupSlots;
  }

  void _autoSelectAvailablePickupSlot() {
    final available = _getAvailablePickupSlots();
    if (available.isNotEmpty) {
      _selectedPickupTimeSlot = available.first;
    } else {
      // No more slots today! Auto-switch to Tomorrow
      _selectedPickupDate = DateTime.now().add(const Duration(days: 1));
      _selectedPickupTimeSlot = _allPickupSlots.first;
    }
  }

  @override
  void dispose() {
    _cart.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) {
      setState(() {});
      _loadCategoryRecommendations();
    }
  }

  Future<void> _loadCategoryRecommendations() async {
    if (_isLoadingRecs) return;
    
    // Find unique category IDs in cart
    final cartCategoryIds = _cart.items.values
        .map((e) => e.categoryId)
        .where((id) => id != null)
        .cast<int>()
        .toSet();

    List<Map<String, dynamic>> fetched = [];
    if (cartCategoryIds.isNotEmpty) {
      for (final catId in cartCategoryIds) {
        final prods = await ApiService.fetchProducts(categoryId: catId);
        fetched.addAll(prods);
      }
    } else {
      // Fetch general top products
      fetched = await ApiService.fetchProducts();
    }

    if (mounted) {
      setState(() {
        _recommendations = fetched;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cart.items.values.toList();
    final int totalItemCount = _cart.totalItemCount;
    final double subtotal = _cart.totalAmount;
    final double amountNeededForFreeDelivery = (_freeDeliveryThreshold - subtotal).clamp(0.0, _freeDeliveryThreshold);
    final double progressRatio = (subtotal / _freeDeliveryThreshold).clamp(0.0, 1.0);

    // Filter recommendations: show products in categories in cart, EXCLUDE products already in cart
    final cartItemIds = _cart.items.keys.toSet();
    final List<Map<String, dynamic>> filteredRecs = _recommendations.where((item) {
      final String idStr = item['id'].toString();
      return !cartItemIds.contains(idStr);
    }).toList();

    final displayRecs = filteredRecs.isNotEmpty ? filteredRecs : _defaultRecommendations.where((item) => !cartItemIds.contains(item['id'].toString())).toList();

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () {
              widget.onBackTap?.call();
            },
          ),
          title: const Text(
            "Cart",
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.width * 0.75,
                  child: DotLottieView(
                    sourceType: 'url',
                    source: 'https://lottie.host/5efe4328-eeaa-4806-8188-3e804cfe962d/QBDkMPKbvz.lottie',
                    autoplay: true,
                    loop: true,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Your cart is empty",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Looks like you haven't added anything to your cart yet",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onBackTap != null) {
                        widget.onBackTap!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0XFF0C831F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded, size: 20),
                    label: const Text(
                      "Browse Categories",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (widget.onBackTap != null) {
              widget.onBackTap!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: () {
              const String shareMsg =
                  "🛒 Download SB Mart Quick App!\n\n"
                  "Get all your daily groceries, fresh produce, and home essentials delivered to your doorstep or ready for store pickup in minutes — all in one place!\n\n"
                  "Download the app now: https://sbmartquick.com/";
              Share.share(shareMsg, subject: "SB Mart Quick App - Everything in one place!");
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0XFFE0E0E0)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.share_outlined, size: 16, color: Colors.black87),
                  SizedBox(width: 4),
                  Text(
                    "Share",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. DELIVERY VS STORE PICKUP TOGGLE SELECTOR
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPickupSelected = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isPickupSelected ? const Color(0XFF0C831F) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.electric_moped,
                                    size: 18,
                                    color: !_isPickupSelected ? Colors.white : Colors.black87,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Home Delivery",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: !_isPickupSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPickupSelected = true;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isPickupSelected ? const Color(0XFF0C831F) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.storefront_outlined,
                                    size: 18,
                                    color: _isPickupSelected ? Colors.white : Colors.black87,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Store Pickup",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _isPickupSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // STORE PICKUP DATE & TIME SELECTOR BANNER
                  if (_isPickupSelected)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0XFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0XFFFFE082)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.store, color: Color(0XFFF57F17), size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Store Pickup Schedule & Hours",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Store Operating Hours: $_storeOpeningTime - $_storeClosingTime",
                            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                          ),
                          const Divider(height: 16),

                          // Pickup Date Picker Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Pickup Date:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedPickupDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 7)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedPickupDate = picked;
                                      final available = _getAvailablePickupSlots();
                                      if (available.isNotEmpty) {
                                        _selectedPickupTimeSlot = available.first;
                                      } else {
                                        // No slots left for selected date, push to next day
                                        _selectedPickupDate = picked.add(const Duration(days: 1));
                                        _selectedPickupTimeSlot = _allPickupSlots.first;
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0XFF0C831F)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${_selectedPickupDate.day}/${_selectedPickupDate.month}/${_selectedPickupDate.year}",
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Pickup Time Slot Selector Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Pickup Slot:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Builder(
                                builder: (context) {
                                  final availableSlots = _getAvailablePickupSlots();
                                  final currentSlotValid = availableSlots.contains(_selectedPickupTimeSlot)
                                      ? _selectedPickupTimeSlot
                                      : (availableSlots.isNotEmpty ? availableSlots.first : _allPickupSlots.first);

                                  return DropdownButton<String>(
                                    value: currentSlotValid,
                                    dropdownColor: Colors.white,
                                    underline: const SizedBox(),
                                    items: availableSlots.map((slot) {
                                      return DropdownMenuItem<String>(
                                        value: slot,
                                        child: Text(slot, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedPickupTimeSlot = val;
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // STORE CLOSED WARNING BANNER
                  if (_isStoreClosed)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0XFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0XFFEF5350)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: Color(0XFFE53935), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Store is Closed",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0XFFE53935),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _activeStore?['closure_reason']?.toString() ?? "This store is currently closed. Orders will be scheduled for tomorrow.",
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. ADVANCED FREE DELIVERY PROGRESS BAR BANNER (Only when Delivery Mode)
                  if (!_isPickupSelected)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: subtotal >= _freeDeliveryThreshold
                            ? const LinearGradient(
                                colors: [Color(0XFF0C831F), Color(0XFF1B5E20)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0XFFFFFDF0), Color(0XFFFFF8E1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: subtotal >= _freeDeliveryThreshold
                              ? const Color(0XFF2E7D32)
                              : const Color(0XFFFFE082),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: subtotal >= _freeDeliveryThreshold
                                ? const Color(0XFF0C831F).withOpacity(0.25)
                                : Colors.amber.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: subtotal >= _freeDeliveryThreshold
                                      ? Colors.white.withOpacity(0.2)
                                      : const Color(0XFFF57F17).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  subtotal >= _freeDeliveryThreshold
                                      ? Icons.verified_rounded
                                      : Icons.electric_moped_rounded,
                                  color: subtotal >= _freeDeliveryThreshold
                                      ? Colors.white
                                      : const Color(0XFFF57F17),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subtotal >= _freeDeliveryThreshold
                                                ? "FREE Delivery Unlocked!"
                                                : "Add ₹${amountNeededForFreeDelivery.toStringAsFixed(0)} more for FREE Delivery",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: subtotal >= _freeDeliveryThreshold
                                                  ? Colors.white
                                                  : Colors.black87,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        if (subtotal >= _freeDeliveryThreshold)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0XFFFFD54F),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "SAVED ₹30",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtotal >= _freeDeliveryThreshold
                                          ? "Congratulations! Delivery charge is waived on this order."
                                          : "Orders over ₹${_freeDeliveryThreshold.toStringAsFixed(0)} get instant free delivery",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtotal >= _freeDeliveryThreshold
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Custom Multi-Tone Glowing Progress Track
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 10,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: subtotal >= _freeDeliveryThreshold
                                      ? Colors.black.withOpacity(0.2)
                                      : const Color(0XFFE0E0E0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progressRatio.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: subtotal >= _freeDeliveryThreshold
                                          ? const LinearGradient(
                                              colors: [Color(0XFFFFD54F), Color(0XFFFFECB3)],
                                            )
                                          : const LinearGradient(
                                              colors: [Color(0XFFF57F17), Color(0XFFFFB74D)],
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // 2. SPECIAL DEAL FOR YOU SECTION (Vanish when added to cart or not available)
                  if (_selectedSpecialDealItem != null &&
                      !_cart.items.containsKey((_selectedSpecialDealItem!['id'] ?? _selectedSpecialDealItem!['product_id'] ?? '').toString())) ...[
                    const SizedBox(height: 14),
                    Builder(builder: (context) {
                      final dealItem = _selectedSpecialDealItem!;
                      final String dealId = (dealItem['id'] ?? dealItem['product_id'] ?? 'deal_1').toString();
                      final String dealName = dealItem['name'] ?? dealItem['title'] ?? 'Special Offer';
                      final String dealImg = dealItem['image'] ?? dealItem['img'] ?? 'image 35.png';
                      final double dealPrice = double.tryParse(dealItem['effective_price']?.toString() ?? dealItem['price']?.toString() ?? '45') ?? 45.0;
                      final double dealMrp = double.tryParse(dealItem['effective_mrp']?.toString() ?? dealItem['mrp']?.toString() ?? '79') ?? (dealPrice + 34);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_offer, color: Color(0XFF673AB7), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Special deal for you!",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0XFFF8F5FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0XFFE8E0FF)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: dealImg.startsWith('http')
                                              ? CachedNetworkImage(
                                                  imageUrl: dealImg,
                                                  fit: BoxFit.contain,
                                                  errorWidget: (_, __, ___) => const Icon(Icons.sanitizer_outlined, color: Color(0XFF5C6BC0), size: 36),
                                                )
                                              : (dealImg.endsWith('.png')
                                                  ? UiHelper.CustomImage(img: dealImg)
                                                  : const Icon(Icons.sanitizer_outlined, color: Color(0XFF5C6BC0), size: 36)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dealName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  "₹${dealPrice.toStringAsFixed(0)} ",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                if (dealMrp > dealPrice)
                                                  Text(
                                                    "₹${dealMrp.toStringAsFixed(0)}",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black38,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedCartButton(
                                        id: dealId,
                                        name: dealName,
                                        img: dealImg,
                                        price: dealPrice,
                                        width: 64,
                                        height: 32,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      _cart.addItem(
                                        id: dealId,
                                        name: dealName,
                                        img: dealImg,
                                        price: dealPrice,
                                      );
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0XFFF0EBFF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add_shopping_cart, size: 16, color: Color(0XFF673AB7)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Yay! Special deal unlocked. Click to add for ₹${dealPrice.toStringAsFixed(0)}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0XFF673AB7),
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
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 14),

                  // 3. CART ITEMS LIST (DELIVERY IN 11 MINS)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0XFFE8F5E9),
                              child: Icon(Icons.timer_outlined, color: Color(0XFF0C831F), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Delivery in 11 minutes",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "Shipment of ${totalItemCount == 0 ? 0 : totalItemCount} ${totalItemCount == 1 ? 'item' : 'items'}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (cartItems.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 240,
                                    height: 240,
                                    child: DotLottieView(
                                      sourceType: 'url',
                                      source: 'https://lottie.host/5efe4328-eeaa-4806-8188-3e804cfe962d/QBDkMPKbvz.lottie',
                                      autoplay: true,
                                      loop: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Your cart is empty",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Looks like you haven't added anything to your cart yet",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      widget.onBackTap?.call();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0XFF0C831F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                                    label: const Text(
                                      "Browse Categories",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Column(
                            children: cartItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0XFFF9F9F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: UiHelper.CustomImage(
                                          img: item.img,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.unit,
                                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        AnimatedCartButton(
                                          id: item.id,
                                          name: item.name,
                                          img: item.img,
                                          price: item.price,
                                          unit: item.unit,
                                          categoryId: item.categoryId,
                                          width: 72,
                                          height: 32,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${(item.price * item.quantity).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. "YOU MIGHT ALSO LIKE" SECTION (ON CART CATEGORIES, FILTER OUT CART ITEMS)
                  if (displayRecs.isNotEmpty) ...[
                    const Text(
                      "You might also like",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: displayRecs.length,
                        itemBuilder: (context, index) {
                          final item = displayRecs[index];
                          final String idStr = item['id'].toString();
                          final String name = (item['name'] ?? item['title'] ?? 'Product').toString();
                          final String unit = (item['unit'] ?? '1 unit').toString();
                          final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                          final double mrp = double.tryParse(item['mrp']?.toString() ?? (price * 1.2).toString()) ?? price;
                          final String img = (item['img'] ?? item['image'] ?? '').toString();
                          final int? catId = item['category_id'] is int ? item['category_id'] : int.tryParse(item['category_id']?.toString() ?? '');

                          return Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0XFFF9F9F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: UiHelper.CustomImage(
                                        img: img,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black38,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                      ],
                                    ),
                                    AnimatedCartButton(
                                      id: idStr,
                                      name: name,
                                      img: img,
                                      price: price,
                                      unit: unit,
                                      categoryId: catId,
                                      width: 56,
                                      height: 28,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. FREE DELIVERY UNLOCKING CARD (Only for Home Delivery)
                  if (!_isPickupSelected) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, color: Color(0XFF0C831F), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _cart.deliveryFee == 0
                                      ? "Free Delivery Unlocked!"
                                      : "Add items for FREE Delivery",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _cart.deliveryFee == 0 ? 1.0 : (subtotal / 199).clamp(0.0, 1.0),
                              backgroundColor: const Color(0XFFE0E0E0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0XFF0C831F)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1.5. APPLY COUPON / SEE ALL COUPONS WIDGET BOX (Just Above Billing Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_appliedCoupon != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0XFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.verified, color: Color(0XFF0C831F), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Coupon '${_appliedCoupon!['code']}' Applied!",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0XFF0C831F),
                                      ),
                                    ),
                                    Text(
                                      "You saved ₹${_couponDiscountAmount.toStringAsFixed(0)} on this order",
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _appliedCoupon = null;
                                    _couponDiscountAmount = 0.0;
                                  });
                                },
                                child: const Text("Remove", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                        ] else ...[
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CouponsScreen(
                                    currentSubtotal: subtotal,
                                    orderType: _isPickupSelected ? "pickup" : "delivery",
                                    onCouponApplied: (data) {
                                      setState(() {
                                        _appliedCoupon = data;
                                        _couponDiscountAmount = double.tryParse(data['discount_amount']?.toString() ?? '0') ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "See all coupons",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black87),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4b. USE SB MART WALLET BALANCE TILE
                  if (_walletBalance > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _useWallet ? const Color(0XFFF0F9F1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _useWallet ? const Color(0XFF0C831F) : const Color(0XFFE0E0E0),
                          width: _useWallet ? 1.5 : 1.0,
                        ),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0XFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0XFF0C831F), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Use SB Mart Wallet Balance",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _useWallet ? const Color(0XFF0C831F) : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final rawTotal = ((_isPickupSelected ? (subtotal + _cart.handlingFee) : _cart.grandTotal) - _couponDiscountAmount).clamp(0.0, 999999.0);
                                    final walletDeduct = min(_walletBalance, rawTotal);
                                    return Text(
                                      _useWallet
                                          ? "Deducting ₹${walletDeduct.toStringAsFixed(0)} from wallet (₹${_walletBalance.toStringAsFixed(0)} available)"
                                          : "Available balance: ₹${_walletBalance.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _useWallet ? const Color(0XFF0C831F) : const Color(0XFF757575),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _useWallet,
                            activeColor: const Color(0XFF0C831F),
                            onChanged: (val) {
                              setState(() {
                                _useWallet = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 5. TOTAL BILLING BREAKDOWN CARD
                  Builder(
                    builder: (context) {
                      final rawTotal = ((_isPickupSelected ? (subtotal + _cart.handlingFee) : _cart.grandTotal) - _couponDiscountAmount).clamp(0.0, 999999.0);
                      final walletDeduct = _useWallet ? min(_walletBalance, rawTotal) : 0.0;
                      final finalPayable = max(0.0, rawTotal - walletDeduct);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Bill details",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 16, color: Colors.black54),
                                    SizedBox(width: 6),
                                    Text("Items total", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                  ],
                                ),
                                Text(
                                  "₹${subtotal.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ],
                            ),
                            if (!_isPickupSelected) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.delivery_dining_outlined, size: 16, color: Colors.black54),
                                      SizedBox(width: 6),
                                      Text("Delivery charge", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    ],
                                  ),
                                  _cart.deliveryFee == 0
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0XFFE8F5E9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "FREE",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0XFF0C831F),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          "₹${_cart.deliveryFee.toStringAsFixed(0)}",
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.cleaning_services_outlined, size: 16, color: Colors.black54),
                                    SizedBox(width: 6),
                                    Text("Handling fee", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                  ],
                                ),
                                Text(
                                  "₹${_cart.handlingFee.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ],
                            ),
                            if (_couponDiscountAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_offer_outlined, size: 16, color: Color(0XFF0C831F)),
                                      const SizedBox(width: 6),
                                      Text("Coupon Discount (${_appliedCoupon?['code'] ?? ''})", style: const TextStyle(fontSize: 13, color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    "-₹${_couponDiscountAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0XFF0C831F)),
                                  ),
                                ],
                              ),
                            ],
                            if (_useWallet && walletDeduct > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0XFF0C831F)),
                                      SizedBox(width: 6),
                                      Text("SB Mart Wallet Deduction", style: TextStyle(fontSize: 13, color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    "-₹${walletDeduct.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0XFF0C831F)),
                                  ),
                                ],
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: Color(0XFFE0E0E0)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _useWallet && walletDeduct > 0 ? "To Pay" : "Grand Total",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "₹${finalPayable.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0XFF0C831F),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 6. STICKY BOTTOM ADDRESS BANNER & CASH ON DELIVERY PAYMENT BAR
          SafeArea(
            top: false,
            bottom: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delivery Address Pill (Only shown when Home Delivery Mode is active)
                  if (!_isPickupSelected)
                    InkWell(
                      onTap: () {
                        AddressSelectionBottomSheet.show(
                          context,
                          onAddressSelected: (newAddr) async {
                            await _fetchUserAddresses();
                            final store = await ApiService.fetchSelectedStore();
                            if (mounted) {
                              if (newAddr.isNotEmpty) {
                                setState(() {
                                  _selectedDeliveryAddress = newAddr;
                                  _hasSavedAddressInArea = true;
                                });
                              }
                              if (store != null) {
                                _checkStockAvailabilityForStore(store['id'] ?? 1);
                              }
                            }
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: _hasSavedAddressInArea ? const Color(0XFFFDFDFD) : const Color(0XFFFFF8E1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _hasSavedAddressInArea ? const Color(0XFFF7CB45) : Colors.orange,
                                  child: Icon(
                                    _hasSavedAddressInArea ? Icons.location_on : Icons.add_location_alt,
                                    color: Colors.black87,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _hasSavedAddressInArea ? "Delivering to $_selectedDeliveryTag" : "No saved address for $_selectedDeliveryTag",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: _hasSavedAddressInArea ? Colors.black : Colors.deepOrange,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _selectedDeliveryAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _hasSavedAddressInArea ? Colors.transparent : const Color(0XFF0C831F),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _hasSavedAddressInArea ? "Change" : "+ Add New Address",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _hasSavedAddressInArea ? const Color(0XFF0C831F) : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Divider(height: 1),

                  // Sticky Payment Bar - CASH ON DELIVERY ONLY FOR NOW
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0XFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.payments_outlined, color: Color(0XFF0C831F), size: 18),
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "PAY USING",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black45,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  "Cash on Delivery",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Green Place Order Button with Backend Sync
                        GestureDetector(
                          onTap: () async {
                            if (_cart.items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Your cart is empty! Add items first.")),
                              );
                              return;
                            }

                            if (!_isPickupSelected && !_hasSavedAddressInArea) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text("No delivery address saved for this location area. Please add an address to place your order."),
                                ),
                              );
                              AddressSelectionBottomSheet.show(
                                context,
                                onAddressSelected: (newAddr) async {
                                  await _fetchUserAddresses();
                                  if (newAddr.isNotEmpty && mounted) {
                                    setState(() {
                                      _selectedDeliveryAddress = newAddr;
                                      _hasSavedAddressInArea = true;
                                    });
                                  }
                                },
                              );
                              return;
                            }

                            final activeStore = ApiService.memoryCachedStore;
                            final int currentStoreId = activeStore?['id'] ?? 1;

                            // Show smooth order placement dialog with pre-loaded Lottie & typing animation
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) {
                                return _OrderPlacementProgressDialog(
                                  isPickup: _isPickupSelected,
                                  onPlaceOrderAction: () async {
                                    final itemsList = _cart.items.values.map((it) {
                                      final cleanIdStr = it.id.replaceAll(RegExp(r'^[a-zA-Z_]+'), '');
                                      int prodId = int.tryParse(cleanIdStr) ?? int.tryParse(it.id) ?? 1;

                                      return {
                                        "product_id": prodId,
                                        "name": it.name,
                                        "price": it.price,
                                        "quantity": it.quantity,
                                        "total": it.price * it.quantity,
                                      };
                                    }).toList();

                                    final formattedDate = "${_selectedPickupDate.year}-${_selectedPickupDate.month.toString().padLeft(2, '0')}-${_selectedPickupDate.day.toString().padLeft(2, '0')}";

                                    final prefs = await SharedPreferences.getInstance();
                                    final savedPhone = prefs.getString('user_phone') ?? '';
                                    final savedName = prefs.getString('user_name') ?? (savedPhone.isNotEmpty ? "Customer ($savedPhone)" : "Customer");

                                    double userOrderLat = 23.4126;
                                    double userOrderLng = 88.4292;
                                    if (_isPickupSelected) {
                                      userOrderLat = double.tryParse(activeStore?['latitude']?.toString() ?? '23.4013') ?? 23.4013;
                                      userOrderLng = double.tryParse(activeStore?['longitude']?.toString() ?? '88.5010') ?? 88.5010;
                                    } else {
                                      Map<String, dynamic>? matchedAddr;
                                      for (var a in _savedAddresses) {
                                        if ((a['address_details'] ?? '') == _selectedDeliveryAddress) {
                                          matchedAddr = a;
                                          break;
                                        }
                                      }
                                      if (matchedAddr != null && matchedAddr['latitude'] != null && matchedAddr['longitude'] != null) {
                                        userOrderLat = double.tryParse(matchedAddr['latitude'].toString()) ?? 23.4126;
                                        userOrderLng = double.tryParse(matchedAddr['longitude'].toString()) ?? 88.4292;
                                      } else {
                                        userOrderLat = _selectedLat ?? prefs.getDouble('user_selected_lat') ?? double.tryParse(prefs.getString('user_selected_lat') ?? '') ?? 23.4126;
                                        userOrderLng = _selectedLng ?? prefs.getDouble('user_selected_lng') ?? double.tryParse(prefs.getString('user_selected_lng') ?? '') ?? 88.4292;
                                      }
                                    }

                                    if (!_isPickupSelected && _selectedDeliveryAddress.isNotEmpty && savedPhone.isNotEmpty) {
                                      if (!_savedAddresses.any((a) => (a['address_details'] ?? '') == _selectedDeliveryAddress)) {
                                        await ApiService.saveUserAddress(
                                          userPhone: savedPhone,
                                          addressType: _selectedDeliveryTag.isNotEmpty ? _selectedDeliveryTag : "Home",
                                          addressDetails: _selectedDeliveryAddress,
                                          receiverName: savedName,
                                          receiverPhone: savedPhone,
                                          latitude: userOrderLat,
                                          longitude: userOrderLng,
                                        );
                                      }
                                    }

                                    return await ApiService.createOrder(
                                      userName: savedName,
                                      userPhone: savedPhone,
                                      deliveryAddress: _isPickupSelected ? "Self Pickup at Store" : _selectedDeliveryAddress,
                                      latitude: userOrderLat,
                                      longitude: userOrderLng,
                                      items: itemsList,
                                      storeId: currentStoreId,
                                      paymentMethod: "Cash on Delivery",
                                      orderType: _isPickupSelected ? "pickup" : "delivery",
                                      pickupDate: formattedDate,
                                      pickupTime: _selectedPickupTimeSlot,
                                      useWallet: _useWallet,
                                      isScheduledForTomorrow: _isStoreClosed,
                                      deliveryFee: _isPickupSelected ? 0.0 : _cart.deliveryFee,
                                      handlingFee: _cart.handlingFee,
                                      discountAmount: _couponDiscountAmount,
                                    );
                                  },
                                  onOrderSuccess: (ordNum, orderData) {
                                    _cart.clearCart();
                                    widget.onBackTap?.call();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OrderStatusScreen(
                                          orderNumber: ordNum,
                                          initialOrderData: orderData is Map<String, dynamic> ? orderData : null,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _isStoreClosed ? const Color(0XFFF57F17) : const Color(0XFF0C831F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final rawTotal = ((_isPickupSelected ? (subtotal + _cart.handlingFee) : _cart.grandTotal) - _couponDiscountAmount).clamp(0.0, 999999.0);
                                        final walletDeduct = _useWallet ? min(_walletBalance, rawTotal) : 0.0;
                                        final finalPayable = max(0.0, rawTotal - walletDeduct);

                                        return Text(
                                          "₹${finalPayable.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                    const Text(
                                      "TOTAL",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Text(
                                      _isStoreClosed ? "Schedule Order" : "Place Order",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_right_sharp, color: Colors.white, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderPlacementProgressDialog extends StatefulWidget {
  final bool isPickup;
  final Future<Map<String, dynamic>> Function() onPlaceOrderAction;
  final Function(String orderNumber, dynamic orderData) onOrderSuccess;

  const _OrderPlacementProgressDialog({
    required this.isPickup,
    required this.onPlaceOrderAction,
    required this.onOrderSuccess,
  });

  @override
  State<_OrderPlacementProgressDialog> createState() => _OrderPlacementProgressDialogState();
}

class _OrderPlacementProgressDialogState extends State<_OrderPlacementProgressDialog> {
  String _typedStatusText = "";
  bool _isSuccess = false;
  bool _isError = false;
  String _errorMessage = "";
  String _orderNumber = "";
  dynamic _orderData;

  @override
  void initState() {
    super.initState();
    _startPlacementFlow();
  }

  Future<void> _typeText(String targetText) async {
    for (int i = 0; i <= targetText.length; i++) {
      if (!mounted) return;
      setState(() {
        _typedStatusText = targetText.substring(0, i);
      });
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _startPlacementFlow() async {
    await _typeText("Connecting to store...");
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 200));
    _typeText(widget.isPickup ? "Scheduling Store Pickup order..." : "Placing Cash on Delivery order...");

    try {
      final response = await widget.onPlaceOrderAction();
      if (!mounted) return;

      if (response['status'] == 'success') {
        _orderNumber = response['order_number'] ?? 'SUCCESS';
        _orderData = response['order'] ?? response;

        await _typeText("Order Placed Successfully! 🎉");
        if (!mounted) return;

        setState(() {
          _isSuccess = true;
        });
      } else {
        _errorMessage = response['message'] ?? 'Failed to place order';
        await _typeText("Order Failed ❌");
        if (!mounted) return;

        setState(() {
          _isError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _errorMessage = e.toString();
      await _typeText("Connection error occurred ❌");
      setState(() {
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pre-loaded Lottie Animation View (Zero Latency)
            SizedBox(
              width: 180,
              height: 180,
              child: DotLottieView(
                sourceType: 'url',
                source: 'https://lottie.host/e8eba8f2-b526-4cac-b154-847000f58171/8XQZX2jiXF.json',
                autoplay: true,
                loop: true,
              ),
            ),
            const SizedBox(height: 16),

            // Typing Status Animation Text
            Container(
              height: 48,
              alignment: Alignment.center,
              child: Text(
                _typedStatusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isError ? Colors.redAccent : (_isSuccess ? const Color(0XFF0C831F) : Colors.black87),
                ),
              ),
            ),

            if (_isError && _errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],

            const SizedBox(height: 20),

            if (_isSuccess)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOrderSuccess(_orderNumber, _orderData);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFF0C831F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.location_searching_rounded, size: 20),
                  label: const Text(
                    "Track Order",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (_isError)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Close", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0XFF0C831F)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
