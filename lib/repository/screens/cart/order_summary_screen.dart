import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';
import 'package:blinkit_series/repository/screens/cart/cartscreen.dart';
import 'package:blinkit_series/repository/screens/profile/need_help_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const OrderSummaryScreen({
    super.key,
    required this.orderData,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  late bool _isRated;

  @override
  void initState() {
    super.initState();
    _isRated = widget.orderData['is_rated'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> orderData = widget.orderData;
    final String orderNumber = orderData['order_number']?.toString() ?? 'ORD';
    final String status = orderData['status']?.toString() ?? 'Delivered';
    final String createdAt = orderData['created_at']?.toString() ?? 'Recently';
    final String address = orderData['delivery_address']?.toString() ?? 'Default Address';
    final String paymentMethod = orderData['payment_method']?.toString() ?? 'Cash on Delivery';
    final double grandTotal = double.tryParse(orderData['grand_total']?.toString() ?? '0') ?? 0.0;
    final double subtotal = double.tryParse(orderData['subtotal']?.toString() ?? '0') ?? grandTotal;
    final double deliveryFee = double.tryParse(orderData['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final double handlingFee = double.tryParse(orderData['handling_fee']?.toString() ?? '2') ?? 2.0;
    final double walletPaid = double.tryParse(orderData['wallet_paid']?.toString() ?? '0') ?? 0.0;
    double payableAmount = double.tryParse(orderData['payable_amount']?.toString() ?? '') ?? 0.0;
    if (payableAmount <= 0) {
      payableAmount = grandTotal > 0 ? (grandTotal - walletPaid) : (subtotal + deliveryFee + handlingFee - walletPaid);
    }
    if (payableAmount < 0) payableAmount = 0.0;

    final List itemsList = orderData['items'] as List? ?? [];
    final int itemTotalCount = itemsList.fold(0, (sum, it) => sum + (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1));

    // Calculate MRP & Discount mock values if not explicitly provided
    final double calculatedMrp = itemsList.fold(0.0, (sum, it) {
      final double price = double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
      final double mrp = double.tryParse(it['mrp']?.toString() ?? '') ?? (price * 1.15);
      final int qty = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
      return sum + (mrp * qty);
    });
    final double discount = (calculatedMrp - subtotal) > 0 ? (calculatedMrp - subtotal) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NeedHelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline_rounded, color: Color(0XFF0C831F), size: 18),
            label: const Text(
              "Need Help",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0XFF0C831F),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Order Summary Header Block
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Order summary",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status == 'Delivered'
                              ? "Arrived at ${createdAt.contains(',') ? createdAt.split(',').last.trim() : createdAt}"
                              : "Order Status: $status",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Generating secure invoice link...")),
                            );
                            final String? signedUrl = await ApiService.fetchSignedInvoiceUrl(orderNumber);
                            if (signedUrl != null && signedUrl.isNotEmpty) {
                              final Uri uri = Uri.parse(signedUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                await launchUrl(uri, mode: LaunchMode.platformDefault);
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Failed to generate invoice link. Please try again."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                "Download Invoice",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0XFF0C831F),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.download_outlined, size: 16, color: Color(0XFF0C831F)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2. Items List Section
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$itemTotalCount ${itemTotalCount == 1 ? 'item' : 'items'} in this order",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (itemsList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("No items detail available", style: TextStyle(color: Colors.black54)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: itemsList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final item = itemsList[index];
                              final String name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Item';
                              final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                              final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                              final String unit = item['unit']?.toString() ?? '1 unit';
                              final String img = item['product_image']?.toString() ?? item['image']?.toString() ?? item['img']?.toString() ?? (item['product'] is Map ? item['product']['image']?.toString() ?? '' : '');
                              final double mrp = double.tryParse(item['mrp']?.toString() ?? '') ?? (price * 1.15);

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Product Thumbnail Container
                                  Container(
                                    width: 60,
                                    height: 60,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0XFFF8F9FA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: UiHelper.CustomImage(
                                        img: img,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Product Name & Quantity
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$unit x $qty",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // Prices: Struck-through MRP and Final Price
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (mrp > price)
                                        Text(
                                          "₹${(mrp * qty).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black38,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        "₹${(price * qty).toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Rate Your Order Section Box (Hidden if already rated)
                  if (!_isRated) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0XFFFFF8E1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.star_rounded, color: Color(0XFFF57F17), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "How were your ordered items?",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _showRatingBottomSheet(context, orderData['id'] ?? orderData['order_id'] ?? orderData['order_number'] ?? orderData['number']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0XFF0C831F),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text(
                                "Rate now",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Bill Details Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(height: 14),

                          if (calculatedMrp > 0) ...[
                            _buildBillRow("MRP", "₹${calculatedMrp.toStringAsFixed(0)}"),
                            const SizedBox(height: 8),
                          ],
                          if (discount > 0) ...[
                            _buildBillRow("Product discount", "-₹${discount.toStringAsFixed(0)}", valueColor: const Color(0XFF0C831F)),
                            const SizedBox(height: 8),
                          ],
                          _buildBillRow("Item total", "₹${subtotal.toStringAsFixed(0)}"),
                          const SizedBox(height: 8),
                          _buildBillRow("Handling charge", "+₹${handlingFee.toStringAsFixed(0)}"),
                          const SizedBox(height: 8),
                          _buildBillRow(
                            "Delivery charges",
                            deliveryFee == 0 ? "FREE" : "₹${deliveryFee.toStringAsFixed(0)}",
                            valueColor: deliveryFee == 0 ? const Color(0XFF0C831F) : Colors.black,
                          ),
                          if (walletPaid > 0) ...[
                            const SizedBox(height: 8),
                            _buildBillRow("Paid via SB Mart Wallet", "-₹${walletPaid.toStringAsFixed(0)}", valueColor: const Color(0XFF0C831F)),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                walletPaid > 0 ? "Collectable / Paid" : "Bill total",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                "₹${payableAmount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Order Details Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Order details",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text("Order ID: #$orderNumber", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text("Payment Method: $paymentMethod", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text("Delivery Address: $address", style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Need Help & Customer Support Card
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
                          "Chat live support or request callback",
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
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar for "Repeat Order"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Re-add items to CartController
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Items added to cart!")),
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFF0C831F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Repeat Order",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "VIEW CART ON NEXT STEP",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBillRow(String label, String value, {Color valueColor = Colors.black}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  void _showRatingBottomSheet(BuildContext context, dynamic orderId) {
    int productStars = 5;
    int deliveryStars = 5;
    final TextEditingController productRemarksController = TextEditingController();
    final TextEditingController deliveryRemarksController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),

                    const Text(
                      "Rate Your Order & Delivery",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Your feedback helps us maintain top grocery quality and speed.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Product Quality Rating
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.inventory_2_outlined, color: Color(0XFF0C831F), size: 20),
                              SizedBox(width: 8),
                              Text("Product Quality Rating", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starVal = index + 1;
                              return IconButton(
                                icon: Icon(
                                  starVal <= productStars ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: const Color(0XFFF57F17),
                                  size: 32,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    productStars = starVal;
                                  });
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: productRemarksController,
                            decoration: InputDecoration(
                              hintText: "Add product remarks (e.g. freshness, packaging)...",
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Delivery & Service Rating
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_shipping_outlined, color: Color(0XFF0C831F), size: 20),
                              SizedBox(width: 8),
                              Text("Delivery Service Rating", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starVal = index + 1;
                              return IconButton(
                                icon: Icon(
                                  starVal <= deliveryStars ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: const Color(0XFFF57F17),
                                  size: 32,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    deliveryStars = starVal;
                                  });
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: deliveryRemarksController,
                            decoration: InputDecoration(
                              hintText: "Add delivery remarks (e.g. rider behavior, speed)...",
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0XFF0C831F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() {
                                  isSubmitting = true;
                                });

                                final res = await ApiService.submitOrderRating(
                                  orderId: orderId,
                                  productRating: productStars,
                                  productRemarks: productRemarksController.text.trim(),
                                  deliveryRating: deliveryStars,
                                  deliveryRemarks: deliveryRemarksController.text.trim(),
                                );

                                if (ctx.mounted) {
                                  if (res['status'] == 'success') {
                                    setState(() {
                                      _isRated = true;
                                    });
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Thank you for your rating! ⭐'),
                                        backgroundColor: const Color(0XFF0C831F),
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Rating submission failed.'),
                                        backgroundColor: Colors.red.shade700,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Submit Feedback & Rating", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
