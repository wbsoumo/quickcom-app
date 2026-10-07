import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/screens/cart/orderstatusscreen.dart';
import 'package:blinkit_series/repository/screens/cart/order_summary_screen.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';
import 'package:blinkit_series/repository/screens/cart/cartscreen.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _userPhone = "8016222991";
  Future<List<Map<String, dynamic>>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _initOrders();
  }

  Future<void> _initOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      if (phone != null && phone.isNotEmpty) {
        _userPhone = phone;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _ordersFuture = _fetchOrders();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final list = await ApiService.getUserOrders(phone: _userPhone);
    if (list.isEmpty && _userPhone != "8016222991") {
      return await ApiService.getUserOrders(phone: "8016222991");
    }
    return list;
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
    await _ordersFuture;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleOrderTap(Map<String, dynamic> ord) {
    final String status = ord['status']?.toString() ?? 'Pending';
    if (status.toLowerCase() != 'delivered') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(
            orderNumber: ord['order_number']?.toString() ?? '',
            initialOrderData: ord,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSummaryScreen(
            orderData: ord,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Order History",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0XFF0C831F),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // 1. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: "Search your orders or e-gift cards",
                      hintStyle: TextStyle(fontSize: 14, color: Colors.black45),
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Fetch Orders List from Backend
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ordersFuture ??= _fetchOrders(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0XFF0C831F)),
                    );
                  }

                  var orders = snapshot.data ?? [];
                  if (_searchQuery.isNotEmpty) {
                    orders = orders.where((ord) {
                      final num = ord['order_number']?.toString().toLowerCase() ?? '';
                      final items = (ord['items'] as List? ?? []).map((e) => e['product_name']?.toString().toLowerCase() ?? '').join(' ');
                      return num.contains(_searchQuery) || items.contains(_searchQuery);
                    }).toList();
                  }

                  if (orders.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey),
                          SizedBox(height: 14),
                          Text(
                            "No orders found",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Your past and active orders will appear here.",
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ord = orders[index];
                      final String status = ord['status']?.toString() ?? 'Pending';
                      final bool isDelivered = status.toLowerCase() == 'delivered';
                      final double grandTotal = double.tryParse(ord['grand_total']?.toString() ?? '0') ?? 0.0;
                      final String createdAt = ord['created_at']?.toString() ?? 'Recently';
                      final List itemsList = ord['items'] as List? ?? [];

                      final String orderType = ord['order_type']?.toString().toLowerCase() ?? 'delivery';
                      final bool isPickup = orderType == 'pickup';

                      // Delivery Headline text matching design
                      String deliveryHeader = isPickup ? "Store Pickup Order" : "Arrived in 10 minutes";
                      if (isPickup) {
                        final String store = ord['store_name']?.toString() ?? ord['pickup_details']?['store_name']?.toString() ?? 'Sonarbangla Mart';
                        deliveryHeader = "Store Pickup • $store";
                      } else if (!isDelivered) {
                        if (status == 'Pending') deliveryHeader = "Order Placed • Driver assigning soon...";
                        else if (status == 'Out for Delivery') deliveryHeader = "On the way • Delivery soon";
                        else deliveryHeader = "Status: $status";
                      }

                      return GestureDetector(
                        onTap: () => _handleOrderTap(ord),
                        child: Container(
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
                              // Top Header Row
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Status Check Circle Icon
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isPickup
                                          ? const Color(0XFFF3E5F5)
                                          : (isDelivered ? const Color(0XFFE8F5E9) : const Color(0XFFFFF8E1)),
                                      child: Icon(
                                        isPickup
                                            ? Icons.storefront_rounded
                                            : (isDelivered ? Icons.check : Icons.access_time_filled_rounded),
                                        color: isPickup
                                            ? Colors.purple[800]
                                            : (isDelivered ? const Color(0XFF0C831F) : const Color(0XFFF57F17)),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Title and Subtitle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deliveryHeader,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "₹${grandTotal.toStringAsFixed(0)} • $createdAt",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Top Right Status Badge / More Icon
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPickup
                                            ? const Color(0XFFF3E5F5)
                                            : (isDelivered
                                                ? const Color(0XFFE8F5E9)
                                                : const Color(0XFFE3F2FD)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPickup ? "PICKUP" : status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPickup
                                              ? Colors.purple[800]
                                              : (isDelivered
                                                  ? const Color(0XFF0C831F)
                                                  : Colors.blue[800]),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Items Thumbnail Row: Show first 2 item images + "+ X" badge if more than 2 items
                              if (itemsList.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(
                                    children: [
                                      ...itemsList.take(2).map((it) {
                                        final String rawImg = (it['product_image'] ?? it['image'] ?? it['img'] ?? '').toString();
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Container(
                                            width: 58,
                                            height: 58,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0XFFF5F6F8),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: UiHelper.CustomImage(
                                                img: rawImg.isNotEmpty ? rawImg : 'image 41.png',
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (itemsList.length > 2)
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: const Color(0XFFF0F2F5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "+ ${itemsList.length - 2}",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),

                              // Bottom Action Row with Reorder & Rate order
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        // Add items to cart & navigate
                                        for (var item in itemsList) {
                                          final String id = item['product_id']?.toString() ?? item['id']?.toString() ?? '1';
                                          final String name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Item';
                                          final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                                          final String img = item['image']?.toString() ?? item['img']?.toString() ?? '';
                                          final String unit = item['unit']?.toString() ?? '1 unit';

                                          CartController.instance.addItem(
                                            id: id,
                                            name: name,
                                            img: img,
                                            price: price,
                                            unit: unit,
                                          );
                                        }

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const CartScreen()),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          "Reorder",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0XFF0C831F),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(width: 1, height: 28, color: Colors.grey[200]),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _handleOrderTap(ord),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          isDelivered ? "Rate order" : "Track Order",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0XFF0C831F),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
