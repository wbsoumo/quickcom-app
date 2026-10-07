import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:blinkit_series/repository/screens/bottomnav/bottomnavscreen.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressSelectionBottomSheet extends StatefulWidget {
  final String currentAddress;
  final Function(String selectedAddress)? onAddressSelected;

  const AddressSelectionBottomSheet({
    super.key,
    this.currentAddress = "Select Location",
    this.onAddressSelected,
  });

  static void show(BuildContext context, {String? currentAddress, Function(String)? onAddressSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddressSelectionBottomSheet(
        currentAddress: currentAddress ?? "Select Location",
        onAddressSelected: onAddressSelected,
      ),
    );
  }

  @override
  State<AddressSelectionBottomSheet> createState() => _AddressSelectionBottomSheetState();
}

class _AddressSelectionBottomSheetState extends State<AddressSelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _savedAddresses = [];
  String? _currentGpsAreaName;
  bool _isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadCachedAddressesLocally();
    _fetchDbAddresses();
    _detectCurrentLocationArea();
  }

  Future<void> _loadCachedAddressesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_local_saved_addresses');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List parsed = jsonDecode(cachedStr);
        if (mounted) {
          setState(() {
            _savedAddresses.clear();
            for (var item in parsed) {
              _savedAddresses.add(Map<String, dynamic>.from(item));
            }
            if (_savedAddresses.isNotEmpty) {
              _isLoadingAddresses = false;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _detectCurrentLocationArea() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          );
          final area = await _reverseGeocodeArea(pos.latitude, pos.longitude);
          if (mounted && area != null && area.isNotEmpty) {
            setState(() {
              _currentGpsAreaName = area;
            });
          }
        }
      }
    } catch (_) {}
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

  Future<void> _fetchDbAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone') ?? '';
    final dbAddresses = await ApiService.getUserAddresses(phone: userPhone);
    final activeStore = ApiService.memoryCachedStore;
    final double? storeLat = activeStore != null ? double.tryParse(activeStore['latitude']?.toString() ?? '') : null;
    final double? storeLng = activeStore != null ? double.tryParse(activeStore['longitude']?.toString() ?? '') : null;

    Position? currentPos;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          currentPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          );
        }
      }
    } catch (_) {}

    final double refLat = currentPos?.latitude ?? storeLat ?? 23.4013;
    final double refLng = currentPos?.longitude ?? storeLng ?? 88.5010;

    if (mounted) {
      setState(() {
        _savedAddresses.clear();
        if (dbAddresses.isNotEmpty) {
          for (var addr in dbAddresses) {
            final String type = addr['custom_type_name'] != null && addr['custom_type_name'].toString().isNotEmpty
                ? addr['custom_type_name'].toString()
                : (addr['address_type'] ?? 'Home');
            final String phone = addr['receiver_phone'] != null && addr['receiver_phone'].toString().isNotEmpty
                ? "${addr['receiver_name']} (${addr['receiver_phone']})"
                : (addr['receiver_name'] ?? '');

            final Map<String, dynamic> converted = {
              "type": type,
              "distance": "Saved",
              "address": addr['address_details'] ?? '',
              "phone": phone,
              "lat": double.tryParse(addr['latitude']?.toString() ?? '23.4013') ?? 23.4013,
              "lng": double.tryParse(addr['longitude']?.toString() ?? '88.5010') ?? 88.5010,
              "is_nearest": false,
            };

            if (!_savedAddresses.any((a) => a['address'] == converted['address'])) {
              _savedAddresses.add(converted);
            }
          }
        }

        // Dynamically compute distances from current GPS position and sort saved addresses nearest-first
        for (int i = 0; i < _savedAddresses.length; i++) {
          final double aLat = (_savedAddresses[i]['lat'] as num).toDouble();
          final double aLng = (_savedAddresses[i]['lng'] as num).toDouble();
          final double distMeters = Geolocator.distanceBetween(refLat, refLng, aLat, aLng);
          _savedAddresses[i]['dist_meters'] = distMeters;
          final double distKm = distMeters / 1000.0;
          _savedAddresses[i]['distance'] = distKm < 1.0
              ? "${distMeters.toInt()} m"
              : "${distKm.toStringAsFixed(1)} km";
        }

        _savedAddresses.sort((a, b) => (a['dist_meters'] as double).compareTo(b['dist_meters'] as double));

        for (int i = 0; i < _savedAddresses.length; i++) {
          _savedAddresses[i]['is_nearest'] = (i == 0);
        }
        _isLoadingAddresses = false;
      });

      if (_savedAddresses.isNotEmpty) {
        try {
          prefs.setString('cached_local_saved_addresses', jsonEncode(_savedAddresses));
        } catch (_) {}
      }
    }
  }

  void _openAddAddressModal(BuildContext context) {
    Navigator.pop(context); // Close current sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddAddressBottomSheet(onAddressSelected: widget.onAddressSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0XFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Select a location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0XFFF0F1F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.search, color: Colors.black54, size: 20),
                      hintText: "Search for area, street name...",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.black45),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons card
                  Container(
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
                        // Use current location
                        InkWell(
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Locating nearest store for current GPS location..."),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            double? currentLat;
                            double? currentLng;
                            try {
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
                                const Duration(seconds: 2),
                                onTimeout: () => false,
                              );
                              if (serviceEnabled) {
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                                  Position pos = await Geolocator.getCurrentPosition(
                                    desiredAccuracy: LocationAccuracy.medium,
                                    timeLimit: const Duration(seconds: 3),
                                  );
                                  currentLat = pos.latitude;
                                  currentLng = pos.longitude;
                                }
                              }
                            } catch (_) {}

                            // Reset manual selection flag when user explicitly requests current GPS location
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_manual_location_selected', false);

                            final storeData = await ApiService.fetchSelectedStore(
                              lat: currentLat,
                              lng: currentLng,
                              forceRefresh: true,
                              isManual: false,
                            );
                            final bool isServiceable = storeData?['is_serviceable'] ?? true;
                            if (context.mounted) {
                              if (!isServiceable) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(storeData?['closure_reason'] ?? "Location out of delivery radius."),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Nearest dark store auto-selected: ${storeData?['name'] ?? 'Store'}"),
                                    backgroundColor: const Color(0XFF0C831F),
                                  ),
                                );
                              }
                              String dynAddress = _currentGpsAreaName ?? '';
                              if (dynAddress.isEmpty) {
                                if (currentLat != null && currentLng != null) {
                                  dynAddress = await _reverseGeocodeArea(currentLat, currentLng) ?? '';
                                }
                              }
                              if (dynAddress.isEmpty) {
                                dynAddress = "${storeData?['name'] ?? 'Nearest Dark Store'}, ${storeData?['address'] ?? ''}";
                              }
                              widget.onAddressSelected?.call(dynAddress);
                              Navigator.pop(context);
                            }
                          },
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, color: Color(0XFFD32F2F), size: 22),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Use current location",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0XFFD32F2F),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentGpsAreaName != null && _currentGpsAreaName!.isNotEmpty
                                            ? _currentGpsAreaName!
                                            : (ApiService.memoryCachedStore != null
                                                ? "${ApiService.memoryCachedStore!['name'] ?? 'Nearest Dark Store'}"
                                                : "Auto-detect location from GPS"),
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.black38),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 1, indent: 50),

                        // Add Address
                        InkWell(
                          onTap: () => _openAddAddressModal(context),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(Icons.add, color: Color(0XFFD32F2F), size: 22),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    "Add Address",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0XFFD32F2F),
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.black38),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Saved Addresses Header
                  const Text(
                    "SAVED ADDRESSES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black45,
                      letterSpacing: 0.8,
                    ),
                  ),

                  if (_savedAddresses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0XFFEBEBEB)),
                      ),
                      child: const Text(
                        "No saved addresses for your account yet.\nTap '+ Add Address' above to save a new address.",
                        style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      ),
                    )
                  else
                    Column(
                      children: _savedAddresses.map((addr) {
                      final bool isNearest = addr['is_nearest'] == true;
                      return InkWell(
                        onTap: () async {
                          final double lat = (addr['lat'] as num?)?.toDouble() ?? 23.4013;
                          final double lng = (addr['lng'] as num?)?.toDouble() ?? 88.5010;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Selecting location & finding nearest dark store..."),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          final storeData = await ApiService.fetchSelectedStore(
                            lat: lat,
                            lng: lng,
                            address: addr['address'],
                            forceRefresh: true,
                            isManual: true,
                          );
                          final bool isServiceable = storeData?['is_serviceable'] ?? true;

                          if (context.mounted) {
                            if (!isServiceable) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    storeData?['closure_reason'] ?? "Location is out of delivery radius. Service currently unavailable.",
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Auto-selected nearest store: ${storeData?['name'] ?? 'Dark Store'}"),
                                  backgroundColor: const Color(0XFF0C831F),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            final prefs = await SharedPreferences.getInstance();
                            if (lat != null && lng != null) {
                              await prefs.setDouble('user_selected_lat', lat);
                              await prefs.setDouble('user_selected_lng', lng);
                            }
                            await ApiService.saveUserSelectedAddress(addr['address'] ?? '');
                            widget.onAddressSelected?.call(addr['address'] ?? '');
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isNearest ? const Color(0XFF0C831F) : const Color(0XFFEBEBEB),
                              width: isNearest ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isNearest ? Icons.near_me : Icons.home_outlined,
                                    color: isNearest ? const Color(0XFF0C831F) : Colors.black87,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    addr['type'] ?? 'Home',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isNearest ? const Color(0XFF0C831F) : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isNearest ? const Color(0XFFE8F5E9) : const Color(0XFFF0F1F5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      addr['distance'] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isNearest ? const Color(0XFF0C831F) : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  if (isNearest) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0XFF0C831F),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Nearest",
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                addr['address'] ?? '',
                                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Phone number: ${addr['phone']}",
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0XFFF5F6F8),
                                    child: Icon(Icons.more_horiz, size: 16, color: Colors.black54),
                                  ),
                                  SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0XFFF5F6F8),
                                    child: Icon(Icons.share_outlined, size: 16, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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

class AddAddressBottomSheet extends StatefulWidget {
  final Function(String selectedAddress)? onAddressSelected;

  const AddAddressBottomSheet({super.key, this.onAddressSelected});

  @override
  State<AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends State<AddAddressBottomSheet> {
  final TextEditingController _addressDetailsController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();
  final MapController _mapController = MapController();

  String _selectedType = "Home"; // Home, Work, Other
  bool _isOrderingForSomeoneElse = false;

  LatLng _currentCenter = const LatLng(23.412600, 88.429200);
  String _locationName = "Fetching location...";
  bool _isGeocoding = false;
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchAndCenterLiveLocation();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    final phone = prefs.getString('user_phone') ?? '';
    if (mounted) {
      setState(() {
        _receiverNameController.text = name.isNotEmpty ? name : 'User';
        _receiverPhoneController.text = phone.isNotEmpty ? phone : '';
      });
    }
  }

  Future<void> _fetchAndCenterLiveLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          final LatLng currentGps = LatLng(pos.latitude, pos.longitude);
          if (mounted) {
            setState(() {
              _currentCenter = currentGps;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _mapController.move(currentGps, 16.0);
              } catch (_) {}
            });
            _reverseGeocode(currentGps);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching live map location: $e");
    }
    _reverseGeocode(_currentCenter);
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _addressDetailsController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latLng.latitude}&lon=${latLng.longitude}',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'SonarbanglaMartApp/1.0',
      }).timeout(const Duration(seconds: 4));

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
              "Selected Location";
          final district = address['state_district'] ?? address['state'] ?? "";
          final fullName = district.isNotEmpty && !place.toString().contains(district.toString())
              ? "$place, $district"
              : "$place";

          if (mounted) {
            setState(() {
              _locationName = fullName;
              _isGeocoding = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Reverse geocode error: $e");
    }

    if (mounted) {
      setState(() {
        _locationName = "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
        _isGeocoding = false;
      });
    }
  }

  void _onMapMoved(LatLng center) {
    _geocodeTimer?.cancel();
    _geocodeTimer = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(center);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardPadding > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header with Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Select delivery location",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Live OpenStreetMap Interactive Map view
            Expanded(
              flex: isKeyboardOpen ? 2 : 4,
              child: ClipRRect(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(23.412600, 88.429200),
                        initialZoom: 15.5,
                        onPositionChanged: (position, hasGesture) {
                          if (position.center != null) {
                            setState(() {
                              _currentCenter = position.center!;
                            });
                            _onMapMoved(position.center!);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sonarbanglamart.app',
                        ),
                      ],
                    ),

                    // Center Pin Marker with clean "Move pin to exact location" tooltip badge
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isKeyboardOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.touch_app, color: Color(0XFF29B6F6), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    "Move pin to exact location",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: isKeyboardOpen ? 36 : 60,
                                height: isKeyboardOpen ? 36 : 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0XFFE53935).withOpacity(0.2),
                                  border: Border.all(color: const Color(0XFFE53935).withOpacity(0.5), width: 1.5),
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                size: isKeyboardOpen ? 28 : 46,
                                color: const Color(0XFFE53935),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Current Location button
                    if (!isKeyboardOpen)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () async {
                            setState(() {
                              _isGeocoding = true;
                            });

                            double? targetLat;
                            double? targetLng;

                            try {
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (serviceEnabled) {
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                }

                                if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                                  Position position = await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(
                                      accuracy: LocationAccuracy.high,
                                      timeLimit: Duration(seconds: 7),
                                    ),
                                  );
                                  targetLat = position.latitude;
                                  targetLng = position.longitude;
                                }
                              }
                            } catch (_) {}

                            targetLat ??= 23.412600;
                            targetLng ??= 88.429200;

                            final LatLng newPos = LatLng(targetLat, targetLng);
                            _mapController.move(newPos, 16.5);
                            setState(() {
                              _currentCenter = newPos;
                            });
                            await _reverseGeocode(newPos);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.my_location, color: Color(0XFF0C831F), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Current Location",
                                  style: TextStyle(
                                    color: Color(0XFF0C831F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
            ),

            // Bottom form inputs
            Expanded(
              flex: isKeyboardOpen ? 8 : 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                physics: const BouncingScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Delivery details",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0XFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0XFFEBEBEB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0XFFD32F2F), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black45),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _addressDetailsController,
                    decoration: InputDecoration(
                      labelText: "Address details*",
                      hintText: "E.g. House no., Floor, Landmark",
                      labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0XFF0C831F), width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save address as tag selector (Home, Work, Other)
                  const Text(
                    "Save address as*",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTagChip("Home", Icons.home_outlined),
                      const SizedBox(width: 10),
                      _buildTagChip("Work", Icons.work_outline),
                      const SizedBox(width: 10),
                      _buildTagChip("Other", Icons.location_city_outlined),
                    ],
                  ),

                  if (_selectedType == "Other") ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customTypeController,
                      decoration: InputDecoration(
                        labelText: "Custom Tag Name*",
                        hintText: "E.g. Gym, Friend's House, Hostel",
                        labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0XFF0C831F), width: 1.5),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Receiver details header & "Order for someone else" toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Receiver details for this address",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isOrderingForSomeoneElse = !_isOrderingForSomeoneElse;
                            if (_isOrderingForSomeoneElse) {
                              _receiverNameController.clear();
                              _receiverPhoneController.clear();
                            } else {
                              _loadUserInfo();
                            }
                          });
                        },
                        icon: Icon(
                          _isOrderingForSomeoneElse ? Icons.check_circle : Icons.person_add_alt_1,
                          size: 16,
                          color: const Color(0XFFE53935),
                        ),
                        label: Text(
                          _isOrderingForSomeoneElse ? "Ordering for someone else" : "Order for someone else",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0XFFE53935)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_isOrderingForSomeoneElse) ...[
                    TextField(
                      controller: _receiverNameController,
                      decoration: InputDecoration(
                        labelText: "Receiver's Full Name*",
                        hintText: "Enter person's name",
                        labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0XFFE53935), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _receiverPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Receiver's Phone Number*",
                        hintText: "10-digit mobile number",
                        labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0XFFE53935), width: 1.5),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0XFFEBEBEB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, color: Colors.black87, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "${_receiverNameController.text}, ${_receiverPhoneController.text}",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black45),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final lat = _currentCenter.latitude;
                        final lng = _currentCenter.longitude;

                        final String tagType = _selectedType == "Other" && _customTypeController.text.trim().isNotEmpty
                            ? _customTypeController.text.trim()
                            : _selectedType;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Checking location coverage & saving address to database..."),
                            duration: Duration(seconds: 1),
                          ),
                        );

                        final prefs = await SharedPreferences.getInstance();
                        final userPhone = prefs.getString('user_phone') ?? _receiverPhoneController.text.trim();

                        // Save to backend database via API
                        await ApiService.saveUserAddress(
                          userPhone: userPhone,
                          addressType: _selectedType,
                          customTypeName: _selectedType == "Other" ? _customTypeController.text.trim() : null,
                          addressDetails: _addressDetailsController.text.isNotEmpty
                              ? "${_addressDetailsController.text.trim()}, $_locationName"
                              : _locationName,
                          receiverName: _receiverNameController.text.trim(),
                          receiverPhone: _receiverPhoneController.text.trim(),
                          isForSomeoneElse: _isOrderingForSomeoneElse,
                          latitude: lat,
                          longitude: lng,
                        );

                        final String finalAddrText = _addressDetailsController.text.isNotEmpty
                            ? "${_addressDetailsController.text.trim()}, $_locationName"
                            : _locationName;

                        final storeData = await ApiService.fetchSelectedStore(
                          lat: lat,
                          lng: lng,
                          address: finalAddrText,
                          forceRefresh: true,
                          isManual: true,
                        );
                        final bool isServiceable = storeData?['is_serviceable'] ?? true;

                        if (mounted) {
                          if (!isServiceable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  storeData?['closure_reason'] ?? "Location is out of delivery radius. Service currently unavailable.",
                                ),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Address saved as '$tagType'! Delivery available in your area."),
                                backgroundColor: const Color(0XFF0C831F),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                          await ApiService.saveUserSelectedAddress(finalAddrText);
                          widget.onAddressSelected?.call(finalAddrText);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0XFFE53935),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Save address",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
  );
}

  Widget _buildTagChip(String label, IconData icon) {
    final bool isSelected = _selectedType == label;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0XFF0C831F),
      backgroundColor: const Color(0XFFF8F9FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0XFF0C831F) : const Color(0XFFEBEBEB)),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedType = label;
          });
        }
      },
    );
  }
}
