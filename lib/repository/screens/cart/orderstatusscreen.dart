import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/screens/profile/need_help_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderNumber;
  final Map<String, dynamic>? initialOrderData;

  const OrderStatusScreen({
    super.key,
    required this.orderNumber,
    this.initialOrderData,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  late AnimationController _bikeAnimController;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _bikeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.initialOrderData != null) {
      _order = widget.initialOrderData;
      _isLoading = false;
    }
    _fetchLiveOrderStatus();

    // Poll the API every 20 seconds while screen is open
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _fetchLiveOrderStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _bikeAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveOrderStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? "8016222991";
    List<Map<String, dynamic>> userOrders = await ApiService.getUserOrders(phone: phone);
    
    Map<String, dynamic>? match;
    for (var o in userOrders) {
      if (o['order_number'] == widget.orderNumber) {
        match = o;
        break;
      }
    }

    if (match == null && phone != "8016222991") {
      final fallbackOrders = await ApiService.getUserOrders(phone: "8016222991");
      for (var o in fallbackOrders) {
        if (o['order_number'] == widget.orderNumber) {
          match = o;
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        if (match != null) {
          _order = match;
        }
        _isLoading = false;
      });
    }
  }

  void _makePhoneCall(String phoneNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Calling Delivery Partner: $phoneNumber...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status = _order?['status']?.toString() ?? 'Pending';
    final String statusLower = status.toLowerCase();
    final String orderType = _order?['order_type']?.toString() ?? 'delivery';
    final Map<String, dynamic>? billSnap = _order?['bill_details'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(_order!['bill_details'])
        : null;

    double subtotal = double.tryParse(billSnap?['subtotal']?.toString() ?? _order?['subtotal']?.toString() ?? '0') ?? 0.0;
    double grandTotal = double.tryParse(billSnap?['grand_total']?.toString() ?? _order?['grand_total']?.toString() ?? _order?['total']?.toString() ?? '0') ?? 0.0;
    final double deliveryFee = double.tryParse(billSnap?['delivery_fee']?.toString() ?? _order?['delivery_fee']?.toString() ?? _order?['delivery_charge']?.toString() ?? '0') ?? 0.0;
    final double handlingFee = double.tryParse(billSnap?['handling_fee']?.toString() ?? _order?['handling_fee']?.toString() ?? _order?['tax']?.toString() ?? '0') ?? 0.0;
    final double discount = double.tryParse(billSnap?['discount_amount']?.toString() ?? billSnap?['discount']?.toString() ?? _order?['discount_amount']?.toString() ?? _order?['discount']?.toString() ?? '0') ?? 0.0;
    final List items = _order?['items'] as List? ?? [];

    if (subtotal == 0.0 && items.isNotEmpty) {
      for (var it in items) {
        final double p = double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
        final int q = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
        subtotal += (double.tryParse(it['total']?.toString() ?? '0') ?? (p * q));
      }
    }
    if (grandTotal == 0.0 && subtotal > 0.0) {
      grandTotal = subtotal + deliveryFee + handlingFee - discount;
    }

    final String paymentMethod = _order?['payment_method']?.toString().toUpperCase() ?? 'CASH ON DELIVERY (COD)';

    final String createdAt = _order?['created_at']?.toString() ?? '';
    final String timeFormatted = createdAt.contains(',')
        ? createdAt.split(',').last.trim()
        : (createdAt.length > 10 ? createdAt.substring(11, 16) : 'Recently');

    // Calculate item total sum if subtotal column is 0
    double computedItemTotal = 0.0;
    for (var item in items) {
      final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      computedItemTotal += (price * qty);
    }
    final double itemTotalDisplay = subtotal > 0 ? subtotal : (computedItemTotal > 0 ? computedItemTotal : grandTotal);
    final Map<String, dynamic>? delDetails = _order?['delivery_details'] as Map<String, dynamic>?;

    final String riderName = delDetails?['rider_name']?.toString() ?? '';
    final String riderPhone = delDetails?['rider_phone']?.toString() ?? '';
    final bool isRiderAssigned = riderName.isNotEmpty;
    final bool isOutForDelivery = statusLower == 'out for delivery' || statusLower == 'delivered';
    final bool showAssignedRider = isRiderAssigned && isOutForDelivery;

    return Scaffold(
      backgroundColor: const Color(0XFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Order Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
            ),
            Text(
              "#${widget.orderNumber}",
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0XFF0C831F)),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchLiveOrderStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0XFF0C831F)))
          : RefreshIndicator(
              onRefresh: _fetchLiveOrderStatus,
              color: const Color(0XFF0C831F),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Order Status & Stepper Card (Green light border)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0XFFE0F2F1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live Estimated Arrival Timer Banner - ONLY when Out for Delivery
                          if (statusLower == 'out for delivery') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0XFFE8F5E9), Color(0XFFF3F9F5)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0XFFC8E6C9)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: Color(0XFF0C831F), size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "ESTIMATED ARRIVAL (5 KM DISTANCE)",
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0XFF0C831F), letterSpacing: 0.5),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          "Arriving in 10–15 mins",
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0XFF0C831F),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "ON TIME",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          orderType == 'pickup' ? Icons.storefront : Icons.two_wheeler,
                                          size: 16,
                                          color: orderType == 'pickup' ? Colors.purple : const Color(0XFF0C831F),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          orderType == 'pickup' ? "Store Pickup" : "Home Delivery",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _getStatusHeadline(status, orderType),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0XFF0C831F),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Your order is being prepared with care.",
                                      style: TextStyle(fontSize: 12, color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Right Status Badge Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusBadgeColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _getStatusBadgeColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 4-Step Tracker Row
                          Row(
                            children: [
                              _buildStepDot(
                                isDone: true,
                                icon: Icons.check,
                                label: "Placed",
                                sublabel: timeFormatted.isNotEmpty ? timeFormatted : "Done",
                              ),
                              _buildStepLine(isDone: _isStepDone(status, 2)),
                              _buildStepDot(
                                isDone: _isStepDone(status, 2),
                                icon: Icons.inventory_2_outlined,
                                label: "Preparing",
                                sublabel: _isStepDone(status, 2) ? "In progress" : "Waiting",
                              ),
                              _buildStepLine(isDone: _isStepDone(status, 3)),
                              _buildStepDot(
                                isDone: _isStepDone(status, 3),
                                icon: Icons.two_wheeler,
                                label: orderType == 'pickup' ? "Ready" : "On the way",
                                sublabel: _isStepDone(status, 3) ? "On the way" : "Waiting",
                              ),
                              _buildStepLine(isDone: _isStepDone(status, 4)),
                              _buildStepDot(
                                isDone: _isStepDone(status, 4),
                                icon: Icons.home_outlined,
                                label: "Delivered",
                                sublabel: _isStepDone(status, 4) ? "Completed" : "Pending",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Delivery Partner Section Card (Delivery Mode Only)
                    if (orderType.toLowerCase() != 'pickup') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0XFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.two_wheeler, color: Color(0XFF0C831F), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Delivery Partner",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                                    ),
                                    Text(
                                      showAssignedRider ? "Delivery executive assigned." : "Your delivery partner will be assigned soon.",
                                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0XFFF3F9F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0XFFE0F2F1)),
                              ),
                              child: showAssignedRider
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildLottieAnimation(
                                              'assets/animations/bike_delivery.json',
                                              width: 58,
                                              height: 58,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    riderName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    riderPhone,
                                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _makePhoneCall(riderPhone),
                                              icon: const Icon(Icons.call, size: 16, color: Colors.white),
                                              label: const Text(
                                                "Call",
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0XFF0C831F),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (statusLower == 'out for delivery') ...[
                                          const SizedBox(height: 12),
                                          const Divider(height: 1, color: Color(0XFFE0F2F1)),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _openLiveMapTrackingBottomSheet(context, riderName, riderPhone),
                                              icon: const Icon(Icons.map, size: 18, color: Colors.white),
                                              label: const Text(
                                                "Track Order on Map >",
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0XFF0C831F),
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        _buildLottieAnimation(
                                          'assets/animations/delivery_search.json',
                                          width: 58,
                                          height: 58,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                "Looking for the best delivery partner...",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                "Our store executive is accepting your order and will assign a partner shortly.",
                                                style: TextStyle(fontSize: 11, color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 3. Location / Store Pickup Address Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
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
                              Icon(
                                orderType.toLowerCase() == 'pickup' ? Icons.storefront_rounded : Icons.location_on,
                                color: const Color(0XFF0C831F),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                orderType.toLowerCase() == 'pickup' ? "Store Pickup Location" : "Delivery Address",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0XFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  orderType.toLowerCase() == 'pickup' ? 'PICKUP' : (_order?['address_type']?.toString().toUpperCase() ?? 'HOME'),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0XFF0C831F)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderType.toLowerCase() == 'pickup'
                                          ? (_order?['store_name']?.toString() ?? _order?['pickup_details']?['store_name']?.toString() ?? "Store Pickup")
                                          : (_order?['delivery_address']?.toString() ?? "Sonarbangla Mart"),
                                      style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      orderType.toLowerCase() == 'pickup'
                                          ? (_order?['store_address']?.toString() ?? _order?['pickup_details']?['store_address']?.toString() ?? "Selected Store Location")
                                          : (_order?['delivery_address']?.toString() ?? "Krishnanagar"),
                                      style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // 3 Options for Store Pickup Mode: Call Store, Directions, Store Hours
                          if (orderType.toLowerCase() == 'pickup') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final String storePhone = _order?['store_phone']?.toString() ?? _order?['pickup_details']?['store_phone']?.toString() ?? "8016222991";
                                      final Uri uri = Uri.parse("tel:$storePhone");
                                      try {
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        } else {
                                          _makePhoneCall(storePhone);
                                        }
                                      } catch (_) {
                                        _makePhoneCall(storePhone);
                                      }
                                    },
                                    icon: const Icon(Icons.call, size: 16, color: Color(0XFF0C831F)),
                                    label: const Text("Call Store", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0XFF0C831F))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0XFF0C831F)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final String lat = (_order?['store_lat'] ?? _order?['pickup_details']?['store_lat'] ?? "23.4013").toString();
                                      final String lng = (_order?['store_lng'] ?? _order?['pickup_details']?['store_lng'] ?? "88.5010").toString();
                                      final String googleMapUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
                                      final Uri uri = Uri.parse(googleMapUrl);
                                      try {
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } else {
                                          await launchUrl(uri);
                                        }
                                      } catch (_) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Location: Lat $lat, Lng $lng")),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.near_me, size: 16, color: Color(0XFF0C831F)),
                                    label: const Text("Directions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0XFF0C831F))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0XFF0C831F)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Store Operating Hours"),
                                          content: const Text("Open Daily: 06:00 AM - 11:00 PM\n\nPlease arrive during slot time for instant pickup."),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text("OK", style: TextStyle(color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.access_time, size: 16, color: Color(0XFF0C831F)),
                                    label: const Text("Hours", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0XFF0C831F))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0XFF0C831F)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0XFFF8F9FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active_outlined, size: 16, color: Colors.black54),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    orderType.toLowerCase() == 'pickup'
                                        ? "Instructions: Show Order #${widget.orderNumber} at pickup counter."
                                        : "Instructions: Ring the doorbell & leave package at door.",
                                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Order Items & Detailed Bill Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shopping_bag, color: Color(0XFF0C831F), size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Order Items",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (items.isEmpty)
                            const Text("No item details", style: TextStyle(color: Colors.black54))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (c, i) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final String name = item['product_name']?.toString() ?? item['name']?.toString() ?? item['title']?.toString() ?? item['item_name']?.toString() ?? 'Item';
                                final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                                final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                                final String img = item['product_image']?.toString() ?? item['image']?.toString() ?? item['img']?.toString() ?? item['product_img']?.toString() ?? '';

                                return Row(
                                  children: [
                                    // Product Thumbnail Image
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0XFFF5F6F8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: UiHelper.CustomImage(
                                          img: img,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Green Quantity Tag (e.g. 1x / 3x)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0XFFE8F5E9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${qty}x",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0XFF0C831F),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Product Name
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Total Price
                                    Text(
                                      "₹${(price * qty).toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Detailed Bill Breakdown
                          const Text(
                            "Bill Details",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Item Total", style: TextStyle(fontSize: 12, color: Colors.black54)),
                              Text("₹${itemTotalDisplay.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Delivery Fee", style: TextStyle(fontSize: 12, color: Colors.black54)),
                              Text(
                                deliveryFee > 0 ? "₹${deliveryFee.toStringAsFixed(0)}" : "FREE",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: deliveryFee > 0 ? Colors.black87 : const Color(0XFF0C831F),
                                  fontWeight: deliveryFee > 0 ? FontWeight.w600 : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (handlingFee > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Handling & Taxes", style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text("₹${handlingFee.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                          if (discount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Discount / Coupon", style: TextStyle(fontSize: 12, color: Color(0XFF0C831F))),
                                Text("-₹${discount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Grand Total Row with Payment Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.credit_card, color: Color(0XFF0C831F), size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        "Grand Total",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0XFFFFF3E0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      paymentMethod.contains('COD') || paymentMethod.contains('CASH') ? "CASH ON DELIVERY (COD)" : paymentMethod,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "₹${grandTotal.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0XFF0C831F),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 5. Need Help & Customer Support Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0XFFE8F5E9),
                            child: Icon(Icons.headset_mic_outlined, color: Color(0XFF0C831F), size: 20),
                          ),
                          title: const Text(
                            "Need help with your order?",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                          subtitle: const Text(
                            "Chat with support or report an issue",
                            style: TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NeedHelpScreen()),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Bottom Footer Note
                    Center(
                      child: Column(
                        children: const [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("🌱 ", style: TextStyle(fontSize: 14)),
                              Text(
                                "Good things take a little time",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0XFF0C831F),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Thanks for shopping with us!",
                            style: TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getStatusBadgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'preparing':
      case 'processing':
      case 'packing':
        return const Color(0XFF1976D2);
      case 'out for delivery':
      case 'ready for pickup':
        return Colors.purple;
      case 'delivered':
        return const Color(0XFF0C831F);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getStatusHeadline(String status, String orderType) {
    switch (status.toLowerCase()) {
      case 'pending':
        return "Order Received";
      case 'confirmed':
      case 'preparing':
      case 'processing':
      case 'packing':
        return "Order Accepted & Packing";
      case 'out for delivery':
        return "Order is on the way!";
      case 'ready for pickup':
        return "Ready for Store Pickup";
      case 'delivered':
        return orderType == 'pickup' ? "Picked Up Successfully" : "Delivered Successfully!";
      case 'cancelled':
        return "Order Cancelled";
      default:
        return status;
    }
  }

  bool _isStepDone(String status, int step) {
    final s = status.toLowerCase();
    if (step == 1) return true;
    if (step == 2) return s == 'confirmed' || s == 'preparing' || s == 'processing' || s == 'packing' || s == 'out for delivery' || s == 'ready for pickup' || s == 'delivered';
    if (step == 3) return s == 'out for delivery' || s == 'ready for pickup' || s == 'delivered';
    if (step == 4) return s == 'delivered';
    return false;
  }

  Widget _buildStepDot({
    required bool isDone,
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isDone ? const Color(0XFF0C831F) : Colors.grey.shade300,
          child: Icon(
            icon,
            size: 14,
            color: isDone ? Colors.white : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isDone ? FontWeight.w900 : FontWeight.bold,
            color: isDone ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 9,
            color: isDone ? const Color(0XFF0C831F) : Colors.grey.shade500,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2.5,
        color: isDone ? const Color(0XFF0C831F) : Colors.grey.shade300,
        margin: const EdgeInsets.only(bottom: 18),
      ),
    );
  }

  Widget _buildLottieAnimation(String assetPath, {double width = 58, double height = 58}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0XFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Lottie.asset(
          assetPath,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.two_wheeler, color: Color(0XFF0C831F), size: 30),
            );
          },
        ),
      ),
    );
  }

  void _openLiveMapTrackingBottomSheet(BuildContext context, String riderName, String riderPhone) {
    // 1. Dynamic User Delivery Location (from order / address record or fallback)
    final double userLat = double.tryParse(_order?['latitude']?.toString() ??
        _order?['delivery_latitude']?.toString() ??
        _order?['user_address']?['latitude']?.toString() ??
        '22.5850') ?? 22.5850;

    final double userLng = double.tryParse(_order?['longitude']?.toString() ??
        _order?['delivery_longitude']?.toString() ??
        _order?['user_address']?['longitude']?.toString() ??
        '88.3780') ?? 88.3780;

    // 2. Store Location (from order store payload or default store coordinate)
    final double storeLat = double.tryParse(_order?['store_latitude']?.toString() ??
        _order?['store']?['latitude']?.toString() ??
        '22.5726') ?? 22.5726;

    final double storeLng = double.tryParse(_order?['store_longitude']?.toString() ??
        _order?['store']?['longitude']?.toString() ??
        '88.3639') ?? 88.3639;

    final LatLng storeLocation = LatLng(storeLat, storeLng);
    final LatLng deliveryLocation = LatLng(userLat, userLng);

    // 3. Current Bike Rider Position (midway point on the arc)
    final LatLng riderLocation = LatLng(
      (storeLat + userLat) / 2 + 0.0030,
      (storeLng + userLng) / 2 - 0.0020,
    );

    final LatLng centerLocation = LatLng(
      (storeLat + userLat) / 2,
      (storeLng + userLng) / 2,
    );

    final List<LatLng> arcPoints = _generateArcPoints(storeLocation, deliveryLocation, numPoints: 40);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Header handle & Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.directions_bike, color: Color(0XFF0C831F)),
                            SizedBox(width: 8),
                            Text(
                              "Live Delivery Tracking",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Interactive Map View
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: centerLocation,
                        initialZoom: 14.0,
                      ),
                      children: [
                        // OpenStreetMap Tile Layer
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.blinkit.series',
                        ),

                        // Half-Oval Curved Line from Store to Customer Location
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: arcPoints,
                              strokeWidth: 4.5,
                              color: const Color(0XFF0C831F),
                            ),
                          ],
                        ),

                        // 3 Pointers/Markers: Store, Customer Delivery Location, & Bike Rider
                        MarkerLayer(
                          markers: [
                            // Store Marker (Purple Store Pin)
                            Marker(
                              point: storeLocation,
                              width: 60,
                              height: 60,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("Store", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                                  ),
                                ],
                              ),
                            ),

                            // Customer Delivery Location Marker (Red Pin)
                            Marker(
                              point: deliveryLocation,
                              width: 60,
                              height: 60,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("Home", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),

                            // Bike Rider Icon Marker (Green Bike Pin)
                            Marker(
                              point: riderLocation,
                              width: 65,
                              height: 65,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0XFF0C831F),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0XFF0C831F).withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.two_wheeler, color: Colors.white, size: 22),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("Partner", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Floating Bottom Delivery Info Banner Card
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0XFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.two_wheeler, color: Color(0XFF0C831F), size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    riderName.isNotEmpty ? riderName : "Delivery Executive",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Arriving in ~8 mins • Out for delivery",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0XFF0C831F)),
                                  ),
                                ],
                              ),
                            ),
                            if (riderPhone.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () => _makePhoneCall(riderPhone),
                                icon: const Icon(Icons.call, size: 16, color: Colors.white),
                                label: const Text("Call", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0XFF0C831F),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      },
    );
  }

  // Generates smooth half-oval curved arc points between start and end coordinates
  List<LatLng> _generateArcPoints(LatLng start, LatLng end, {int numPoints = 40}) {
    final List<LatLng> points = [];
    final double midLat = (start.latitude + end.latitude) / 2;
    final double midLng = (start.longitude + end.longitude) / 2;

    // Offset control point to create half-oval curve arc
    final double controlLat = midLat + 0.0080;
    final double controlLng = midLng - 0.0080;

    for (int i = 0; i <= numPoints; i++) {
      final double t = i / numPoints;
      final double lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * controlLat + t * t * end.latitude;
      final double lng = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * controlLng + t * t * end.longitude;
      points.add(LatLng(lat, lng));
    }
    return points;
  }
}
