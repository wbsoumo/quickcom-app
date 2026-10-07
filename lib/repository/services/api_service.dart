import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blinkit_series/domain/constants/api_constants.dart';

class ApiService {
  static const String _kStoreCacheKey = 'cache_store_data';
  static const String _kStoreVersionKey = 'cache_store_version';
  static const String _kCategoriesCacheKey = 'cache_categories_data';
  static const String _kCategoriesEtagKey = 'cache_categories_etag';
  static const String _kCategoriesVersionKey = 'cache_categories_version';

  static const String _kSlidersCacheKey = 'cache_sliders_data';
  static const String _kSlidersEtagKey = 'cache_sliders_etag';

  static const String _kProductsCacheKey = 'cache_products_data_';
  static const String _kProductsEtagKey = 'cache_products_etag_';
  static const String _kProductsVersionKey = 'cache_products_version_';

  static Map<String, dynamic>? _memoryCachedStore;
  static List<Map<String, dynamic>>? _memoryCachedCategories;
  static List<Map<String, dynamic>>? _memoryCachedSliders;

  // Instant Sync Memory Cache Accessor
  static Map<String, dynamic>? get memoryCachedStore => _memoryCachedStore;

  static Future<String?> getUserSelectedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_selected_address');
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUserSelectedAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_selected_address', address);
    } catch (_) {}
  }

  // 0. Light-Weight Sync Status Checker
  static Future<Map<String, dynamic>?> checkSyncStatus({int storeId = 1}) async {
    try {
      final Uri uri = Uri.parse(ApiConstants.syncCheck).replace(
        queryParameters: {'store_id': storeId.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data;
        }
      }
    } catch (e) {
      debugPrint("Sync Check API Error: $e");
    }
    return null;
  }

  static int _storeRequestSequence = 0;

  // 1. Fetch Store Selection & Operational Status with Local Storage Cache & Session Persistence
  static Future<Map<String, dynamic>?> fetchSelectedStore({
    double? lat,
    double? lng,
    String? address,
    bool forceRefresh = false,
    bool isManual = false,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    final bool isCurrentlyManual = prefs?.getBool('is_manual_location_selected') ?? false;

    // Save user selected address if passed explicitly
    if (address != null && address.isNotEmpty && prefs != null) {
      prefs.setString('user_selected_address', address);
    }

    // Background GPS updates cannot overwrite an active manual user selection during session
    if (!isManual && isCurrentlyManual && lat != null && lng != null) {
      debugPrint("Skipping background GPS store update because active manual selection exists.");
      lat = null;
      lng = null;
    }

    // Save requested lat/lng if provided
    if (lat != null && lng != null && prefs != null) {
      prefs.setDouble('user_selected_lat', lat);
      prefs.setDouble('user_selected_lng', lng);
      if (isManual) {
        prefs.setBool('is_manual_location_selected', true);
      }
    }

    // Read stored coordinates if not passed explicitly
    if (lat == null && lng == null && prefs != null) {
      lat = prefs.getDouble('user_selected_lat');
      lng = prefs.getDouble('user_selected_lng');
    }

    if (!forceRefresh && _memoryCachedStore != null) {
      return _memoryCachedStore;
    }

    Map<String, dynamic>? cachedStore;

    try {
      final String? cachedJson = prefs?.getString(_kStoreCacheKey);
      if (cachedJson != null) {
        cachedStore = Map<String, dynamic>.from(jsonDecode(cachedJson));
        _memoryCachedStore = cachedStore;
      }
    } catch (e) {
      debugPrint("Error reading cached store: $e");
    }

    if (!forceRefresh && cachedStore != null) {
      return cachedStore;
    }

    final currentSeq = ++_storeRequestSequence;

    try {
      final Uri uri = Uri.parse(ApiConstants.selectStore).replace(
        queryParameters: {
          if (lat != null) 'lat': lat.toString(),
          if (lng != null) 'lng': lng.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      
      // Ensure stale out-of-order API responses do not overwrite newer selections
      if (currentSeq != _storeRequestSequence) {
        debugPrint("Discarding stale store API response sequence #$currentSeq");
        return _memoryCachedStore ?? cachedStore;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['store'] != null) {
          final Map<String, dynamic> storeMap = Map<String, dynamic>.from(data['store']);
          _memoryCachedStore = storeMap;
          if (prefs != null) {
            prefs.setString(_kStoreCacheKey, jsonEncode(storeMap));
            final String version = md5Hash(jsonEncode(storeMap));
            prefs.setString(_kStoreVersionKey, version);
          }
          return storeMap;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching store: $e");
    }
    return cachedStore;
  }

  static Future<Map<String, dynamic>> fetchSelectedStoreDetails({double? lat, double? lng}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (lat == null && lng == null && prefs != null) {
        lat = prefs.getDouble('user_selected_lat');
        lng = prefs.getDouble('user_selected_lng');
      }

      final Uri uri = Uri.parse(ApiConstants.selectStore).replace(
        queryParameters: {
          if (lat != null) 'lat': lat.toString(),
          if (lng != null) 'lng': lng.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['store'] != null) {
          final storeMap = Map<String, dynamic>.from(data['store']);
          _memoryCachedStore = storeMap;
          return {
            'store': storeMap,
            'is_within_coverage': data['is_within_coverage'] ?? true,
            'calculated_distance_km': double.tryParse(data['calculated_distance_km']?.toString() ?? '0') ?? 0.0,
          };
        }
      }
    } catch (e) {
      debugPrint("API Error fetching store details: $e");
    }
    return {
      'store': _memoryCachedStore,
      'is_within_coverage': true,
      'calculated_distance_km': 0.0,
    };
  }

  static String md5Hash(String text) {
    // Basic hash fallback helper
    return text.hashCode.toString();
  }

  // 2. Fetch Categories with Local Storage Cache & Delta ETag
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    SharedPreferences? prefs;
    List<Map<String, dynamic>> cachedCategories = [];
    String? etag;

    try {
      prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_kCategoriesCacheKey);
      etag = prefs.getString(_kCategoriesEtagKey);
      if (jsonStr != null) {
        final List list = jsonDecode(jsonStr);
        cachedCategories = List<Map<String, dynamic>>.from(list);
        if (cachedCategories.any((cat) => (cat['image']?.toString() ?? '').contains('unsplash.com'))) {
          cachedCategories = [];
          etag = null;
          prefs.remove(_kCategoriesCacheKey);
          prefs.remove(_kCategoriesEtagKey);
        }
      }
    } catch (e) {
      debugPrint("Error reading categories cache: $e");
    }

    try {
      final Map<String, String> headers = {};
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }

      final response = await http
          .get(Uri.parse(ApiConstants.categories), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 304) {
        // Backend confirms data not modified; return local cache instantly
        return cachedCategories;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<Map<String, dynamic>> freshCats = List<Map<String, dynamic>>.from(data['data']);
          
          // Save to local storage asynchronously
          if (prefs != null) {
            prefs.setString(_kCategoriesCacheKey, jsonEncode(freshCats));
            final String? newEtag = response.headers['etag'];
            if (newEtag != null) {
              prefs.setString(_kCategoriesEtagKey, newEtag);
            }
          }
          return freshCats;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching categories, returning cache: $e");
    }

    return cachedCategories;
  }

  // 3. Fetch Products with Local Storage Cache & Delta ETag Sync
  static Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, int storeId = 1, bool forceRefresh = false}) async {
    final String cacheKey = "$_kProductsCacheKey${storeId}_${categoryId ?? 'all'}";
    final String etagKey = "$_kProductsEtagKey${storeId}_${categoryId ?? 'all'}";

    SharedPreferences? prefs;
    List<Map<String, dynamic>> cachedProducts = [];
    String? etag;

    try {
      prefs = await SharedPreferences.getInstance();
      if (!forceRefresh) {
        final String? jsonStr = prefs.getString(cacheKey);
        etag = prefs.getString(etagKey);
        if (jsonStr != null) {
          final List list = jsonDecode(jsonStr);
          cachedProducts = List<Map<String, dynamic>>.from(list);
          if (cachedProducts.any((p) => (p['image']?.toString() ?? '').contains('01_vegetables_fruits.png'))) {
            cachedProducts = [];
            etag = null;
            prefs.remove(cacheKey);
            prefs.remove(etagKey);
          }
        }
      }
    } catch (e) {
      debugPrint("Error reading products cache: $e");
    }

    try {
      final Map<String, String> queryParams = {
        'store_id': storeId.toString(),
        if (categoryId != null) 'category_id': categoryId.toString(),
      };
      final Uri uri = Uri.parse(ApiConstants.products).replace(queryParameters: queryParams);

      final Map<String, String> headers = {};
      if (!forceRefresh && etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 304 && cachedProducts.isNotEmpty) {
        // Data not changed on server; return local cache instantly
        return cachedProducts;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<Map<String, dynamic>> freshProducts = List<Map<String, dynamic>>.from(data['data']);

          // Update local storage
          if (prefs != null) {
            prefs.setString(cacheKey, jsonEncode(freshProducts));
            final String? newEtag = response.headers['etag'];
            if (newEtag != null) {
              prefs.setString(etagKey, newEtag);
            }
          }
          return freshProducts;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching products, returning local cache: $e");
    }

    return cachedProducts;
  }

  // 4. Create Order & Reserve Inventory in Backend
  static Future<Map<String, dynamic>> createOrder({
    required String userName,
    required String userPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    int storeId = 1,
    String paymentMethod = "PhonePe UPI",
    String orderType = "delivery",
    String? pickupDate,
    String? pickupTime,
    String? receiverName,
    String? receiverPhone,
    bool isForSomeoneElse = false,
    bool useWallet = false,
    bool isScheduledForTomorrow = false,
    double? latitude,
    double? longitude,
    double? deliveryFee,
    double? handlingFee,
    double? mrpTotal,
    double? discountAmount,
    String? userGst,
  }) async {
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}
      final savedGst = userGst ?? prefs?.getString('user_gst');

      final body = jsonEncode({
        "user_name": userName,
        "user_phone": userPhone,
        "delivery_address": deliveryAddress,
        if (savedGst != null && savedGst.isNotEmpty) "user_gstin": savedGst,
        "latitude": latitude ?? 23.4126,
        "longitude": longitude ?? 88.4292,
        "store_id": storeId,
        "payment_method": paymentMethod,
        "order_type": orderType,
        "pickup_date": pickupDate,
        "pickup_time": pickupTime,
        "receiver_name": receiverName,
        "receiver_phone": receiverPhone,
        "is_for_someone_else": isForSomeoneElse,
        "use_wallet": useWallet,
        "is_scheduled_for_tomorrow": isScheduledForTomorrow,
        "delivery_fee": deliveryFee,
        "handling_fee": handlingFee,
        "mrp_total": mrpTotal,
        "discount_amount": discountAmount,
        "items": items,
      });

      final response = await http.post(
        Uri.parse(ApiConstants.createOrder),
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(const Duration(seconds: 25));

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        "status": "error",
        "message": "Connection error: $e"
      };
    }
  }

  // 5. Fetch User Saved Addresses from Database
  static Future<List<Map<String, dynamic>>> getUserAddresses({String? phone}) async {
    try {
      String targetPhone = phone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '';
      }
      if (targetPhone.isEmpty) {
        return [];
      }

      final Uri uri = Uri.parse(ApiConstants.userAddresses).replace(queryParameters: {'phone': targetPhone});
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching user addresses: $e");
    }
    return [];
  }

  // 6. Save User Address in Database
  static Future<Map<String, dynamic>> saveUserAddress({
    required String addressType, // Home, Work, Other
    String? customTypeName,
    required String addressDetails,
    required String receiverName,
    required String receiverPhone,
    bool isForSomeoneElse = false,
    double latitude = 23.4126,
    double longitude = 88.4292,
    String? userPhone,
  }) async {
    try {
      String targetPhone = userPhone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '';
      }
      if (targetPhone.isEmpty) {
        targetPhone = receiverPhone;
      }

      final body = jsonEncode({
        "user_phone": targetPhone,
        "address_type": addressType,
        "custom_type_name": customTypeName,
        "address_details": addressDetails,
        "receiver_name": receiverName,
        "receiver_phone": receiverPhone,
        "is_for_someone_else": isForSomeoneElse,
        "latitude": latitude,
        "longitude": longitude,
      });

      final response = await http.post(
        Uri.parse(ApiConstants.storeUserAddress),
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(const Duration(seconds: 8));

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Save address failed: $e"};
    }
  }

  // 7. Fetch Real-time User Orders & Status Tracking History
  static Future<List<Map<String, dynamic>>> getUserOrders({String phone = "8016222991"}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String savedPhone = prefs.getString('user_phone') ?? phone;
      
      Uri uri = Uri.parse("${ApiConstants.baseUrl}/user/orders").replace(queryParameters: {'phone': savedPhone});
      var response = await http.get(uri).timeout(const Duration(seconds: 8));

      debugPrint("getUserOrders response status for $savedPhone: ${response.statusCode}, body length: ${response.body.length}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List list = data['data'];
          if (list.isNotEmpty) {
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }

      // If specific phone had 0 orders, fallback to default test phone 8016222991
      final fallbackUri = Uri.parse("${ApiConstants.baseUrl}/user/orders").replace(queryParameters: {'phone': '8016222991'});
      final fallbackResponse = await http.get(fallbackUri).timeout(const Duration(seconds: 8));
      if (fallbackResponse.statusCode == 200) {
        final fallbackData = jsonDecode(fallbackResponse.body);
        if (fallbackData['status'] == 'success' && fallbackData['data'] != null) {
          return List<Map<String, dynamic>>.from(fallbackData['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching user orders: $e");
    }
    return [];
  }

  // 8. Fetch Active Promotional & Bank Coupons List
  static Future<List<Map<String, dynamic>>> getCoupons() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.coupons)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching coupons: $e");
    }
    return [];
  }

  // 9. Validate Coupon Code against Subtotal, Security Rules & Devices
  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double subtotal,
    String phone = "8016222991",
    String deviceId = "device_mac_browser_01",
    String orderType = "delivery",
    int storeId = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.validateCoupon),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "code": code,
          "subtotal": subtotal,
          "user_phone": phone,
          "device_id": deviceId,
          "order_type": orderType,
          "store_id": storeId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (_) {
          return {"status": "error", "message": "Invalid response format from server."};
        }
      } else {
        try {
          final errJson = jsonDecode(response.body);
          return {"status": "error", "message": errJson['message'] ?? "Server error (${response.statusCode})"};
        } catch (_) {
          return {"status": "error", "message": "Server error (${response.statusCode}). Please try again."};
        }
      }
    } catch (e) {
      return {"status": "error", "message": "Failed to validate coupon: $e"};
    }
  }

  // 10. Fetch Customer Wallet Balance
  static Future<double> fetchUserWallet({String? phone}) async {
    try {
      String targetPhone = phone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '';
      }
      if (targetPhone.isEmpty) {
        return 0.0;
      }
      final response = await http.get(
        Uri.parse("${ApiConstants.userWallet}?phone=$targetPhone"),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching wallet balance: $e");
    }
    return 0.0;
  }

  static Future<Map<String, dynamic>> fetchUserWalletDetails({String? phone}) async {
    try {
      String targetPhone = phone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '';
      }
      if (targetPhone.isEmpty) {
        return {'wallet_balance': 0.0, 'transactions': []};
      }
      final response = await http.get(
        Uri.parse("${ApiConstants.userWallet}?phone=$targetPhone"),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final balance = double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0.0;
          final List rawTxs = data['transactions'] ?? [];
          final txs = rawTxs.map((t) => Map<String, dynamic>.from(t)).toList();
          return {
            'wallet_balance': balance,
            'transactions': txs,
          };
        }
      }
    } catch (e) {
      debugPrint("API Error fetching wallet details: $e");
    }
    return {'wallet_balance': 0.0, 'transactions': []};
  }

  // 11. Fetch Active Promotional Sliders with Local Storage Cache & ETag Check
  static Future<List<Map<String, dynamic>>> fetchSliders({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCachedSliders != null && _memoryCachedSliders!.isNotEmpty) {
      return _memoryCachedSliders!;
    }

    SharedPreferences? prefs;
    List<Map<String, dynamic>> cachedSliders = [];
    String? etag;

    try {
      prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_kSlidersCacheKey);
      etag = prefs.getString(_kSlidersEtagKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        cachedSliders = List<Map<String, dynamic>>.from(list);
        _memoryCachedSliders = cachedSliders;
      }
    } catch (e) {
      debugPrint("Error reading sliders cache: $e");
    }

    try {
      final Map<String, String> headers = {};
      if (!forceRefresh && etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }

      final response = await http.get(
        Uri.parse(ApiConstants.sliders),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 304 && cachedSliders.isNotEmpty) {
        return cachedSliders;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<Map<String, dynamic>> freshSliders = List<Map<String, dynamic>>.from(data['data']);
          _memoryCachedSliders = freshSliders;
          if (prefs != null) {
            prefs.setString(_kSlidersCacheKey, jsonEncode(freshSliders));
            final String? newEtag = response.headers['etag'];
            if (newEtag != null) {
              prefs.setString(_kSlidersEtagKey, newEtag);
            }
          }
          return freshSliders;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching sliders: $e");
    }

    return cachedSliders;
  }

  // 11. Register User
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    required String password,
    String? deviceInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "password": password,
          "device_info": deviceInfo ?? "Flutter Mobile App (${defaultTargetPlatform.name})",
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        // Save session locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_phone', data['user']['phone'] ?? phone);
        await prefs.setString('user_name', data['user']['name'] ?? name);
        if (data['token'] != null) {
          await prefs.setString('auth_token', data['token']);
        }
        // Immediately sync FCM token for push notifications
        registerFcmToken();
      }
      return data;
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  // 12. Login User
  static Future<Map<String, dynamic>> loginUser({
    required String phone,
    required String password,
    String? deviceInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "password": password,
          "device_info": deviceInfo ?? "Flutter Mobile App (${defaultTargetPlatform.name})",
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        // Save session locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_phone', data['user']['phone'] ?? phone);
        await prefs.setString('user_name', data['user']['name'] ?? 'User');
        if (data['token'] != null) {
          await prefs.setString('auth_token', data['token']);
        }
        // Immediately sync FCM token for push notifications
        registerFcmToken();
      }
      return data;
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  // 13. Register Device FCM Token for Push Notifications
  static Future<void> registerFcmToken([String? fcmToken]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';

      if (phone.isEmpty) {
        debugPrint("Skipping FCM registration: user is guest / not logged in.");
        return;
      }

      String? token = fcmToken;
      if (token == null || token.isEmpty) {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token == null || token.isEmpty) {
        debugPrint("No FCM token available to register.");
        return;
      }

      final res = await http.post(
        Uri.parse(ApiConstants.registerFcmToken),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "fcm_token": token,
          "device_type": defaultTargetPlatform.name,
        }),
      ).timeout(const Duration(seconds: 5));

      debugPrint("FCM Token synced to backend for $phone: status ${res.statusCode}");
    } catch (e) {
      debugPrint("Failed to register FCM token: $e");
    }
  }

  // 14. Fetch User Wishlist Products
  static Future<Map<String, dynamic>> fetchUserWishlist({String? phone, int storeId = 1}) async {
    try {
      String targetPhone = phone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '8016222991';
      }

      final Uri uri = Uri.parse(ApiConstants.userWishlist).replace(
        queryParameters: {
          'user_phone': targetPhone,
          'store_id': storeId.toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {
            'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
            'product_ids': List<String>.from(data['product_ids'] ?? []),
          };
        }
      }
    } catch (e) {
      debugPrint("API Error fetching wishlist: $e");
    }
    return {'data': [], 'product_ids': []};
  }

  // 15. Toggle Product in Wishlist
  static Future<bool> toggleWishlistProduct({required String productId, String? phone}) async {
    try {
      String targetPhone = phone ?? '';
      if (targetPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        targetPhone = prefs.getString('user_phone') ?? '8016222991';
      }

      final response = await http.post(
        Uri.parse(ApiConstants.toggleWishlist),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_phone": targetPhone,
          "product_id": productId,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_wishlisted'] == true;
      }
    } catch (e) {
      debugPrint("API Error toggling wishlist: $e");
    }
    return false;
  }

  // 16. Delete Account API Call
  static Future<Map<String, dynamic>> deleteAccount({required String password, String? phone}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userPhone = phone ?? prefs.getString('user_phone') ?? '';

      final response = await http.post(
        Uri.parse(ApiConstants.deleteAccount),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": userPhone,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {
          'success': true,
          'message': data['message'] ?? 'Account deleted successfully.',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete account. Incorrect password.',
        };
      }
    } catch (e) {
      debugPrint("API Error deleting account: $e");
      return {
        'success': false,
        'message': 'Network error while deleting account. Please check your connection.',
      };
    }
  }

  // 17. Submit Custom / Bulk Order Request
  static Future<Map<String, dynamic>> submitCustomOrderRequest({
    required String orderType,
    String? remarks,
    String? address,
    String? base64Image,
    double? lat,
    double? lng,
    int? storeId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone') ?? '';
      final userName = prefs.getString('user_name') ?? 'Customer';

      final response = await http.post(
        Uri.parse(ApiConstants.customOrderRequest),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_phone": userPhone,
          "user_name": userName,
          "order_type": orderType,
          "remarks": remarks ?? "",
          "address": address ?? "",
          "image": base64Image,
          "latitude": lat,
          "longitude": lng,
          "store_id": storeId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint("API Error submitting custom order: $e");
    }
    return {"status": "error", "message": "Failed to submit custom order request."};
  }

  // 18. Submit Order & Delivery Rating API
  static Future<Map<String, dynamic>> submitOrderRating({
    required dynamic orderId,
    required int productRating,
    required String productRemarks,
    required int deliveryRating,
    required String deliveryRemarks,
    int storeId = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone') ?? '8016222991';

      final response = await http.post(
        Uri.parse(ApiConstants.submitRating),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": orderId,
          "user_phone": userPhone,
          "product_rating": productRating,
          "product_remarks": productRemarks,
          "delivery_rating": deliveryRating,
          "delivery_remarks": deliveryRemarks,
          "store_id": storeId,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint("submitOrderRating response code: ${response.statusCode}, body: ${response.body}");

      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint("API Error submitting order rating: $e");
      return {"status": "error", "message": "Connection error: $e"};
    }
    return {"status": "error", "message": "Rating submission failed."};
  }

  // 19. Create Support Ticket API
  static Future<Map<String, dynamic>> createSupportTicket({
    required String category,
    String? subCategory,
    String? description,
    int? storeId,
    dynamic orderId,
    String? orderNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone') ?? '';
      final userName = prefs.getString('user_name') ?? 'Customer';

      final response = await http.post(
        Uri.parse(ApiConstants.supportTickets),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_phone": userPhone,
          "user_name": userName,
          "category": category,
          "sub_category": subCategory,
          "description": description,
          "store_id": storeId,
          "order_id": orderId,
          "order_number": orderNumber,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint("API Error creating support ticket: $e");
      return {"status": "error", "message": "Connection error: $e"};
    }
    return {"status": "error", "message": "Failed to create support ticket."};
  }

  // 20. Fetch User Support Tickets API
  static Future<List<Map<String, dynamic>>> getUserSupportTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone') ?? '';
      if (userPhone.isEmpty) return [];

      final uri = Uri.parse(ApiConstants.supportTickets).replace(queryParameters: {'phone': userPhone});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching support tickets: $e");
    }
    return [];
  }

  // 21. Fetch All Active Stores List API
  static Future<List<Map<String, dynamic>>> fetchAllStores() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.stores)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['stores'] != null) {
          return List<Map<String, dynamic>>.from(data['stores']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching stores: $e");
    }
    return [];
  }

  // 22. Fetch Cryptographically Signed Web Invoice URL API
  static Future<String?> fetchSignedInvoiceUrl(String orderNumber) async {
    try {
      final Uri uri = Uri.parse("${ApiConstants.baseUrl}/invoice/signed-url").replace(
        queryParameters: {'order_number': orderNumber},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['url'] != null) {
          return data['url'].toString();
        }
      }
    } catch (e) {
      debugPrint("API Error fetching signed invoice URL: $e");
    }
    return null;
  }

  // 23. Update User Profile & GST Number API
  static Future<Map<String, dynamic>> updateUserProfile({
    required String phone,
    String? name,
    String? gstNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.updateUserProfile),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          if (name != null && name.isNotEmpty) 'name': name,
          if (gstNumber != null) 'gst_number': gstNumber,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          if (gstNumber != null) {
            await prefs.setString('user_gst', gstNumber);
          }
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      debugPrint("API Error updating user profile: $e");
    }
    return {'status': 'error', 'message': 'Failed to update profile'};
  }

  // 24. Fetch User Profile & GST Details API
  static Future<Map<String, dynamic>?> fetchUserProfile(String phone) async {
    try {
      final Uri uri = Uri.parse(ApiConstants.userProfile).replace(
        queryParameters: {'phone': phone},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['user'] != null) {
          final user = Map<String, dynamic>.from(data['user']);
          final gst = user['gst_number']?.toString() ?? '';
          if (gst.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_gst', gst);
          }
          return user;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching user profile: $e");
    }
    return null;
  }
}


