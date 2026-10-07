import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/services/api_service.dart';

class CouponsScreen extends StatefulWidget {
  final double currentSubtotal;
  final String orderType;
  final Function(Map<String, dynamic> couponData)? onCouponApplied;

  const CouponsScreen({
    super.key,
    required this.currentSubtotal,
    this.orderType = "delivery",
    this.onCouponApplied,
  });

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isApplying = false;
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    final list = await ApiService.getCoupons();
    if (mounted) {
      setState(() {
        _coupons = list.isNotEmpty
            ? list
            : [
                {
                  "code": "ONECARD30",
                  "title": "Flat ₹30 Off",
                  "description": "Applicable only on transactions using OneCard Credit Cards. Maximum Discount is ₹30.",
                  "discount_type": "flat",
                  "discount_value": 30.0,
                  "min_cart_amount": 149.0,
                  "allowed_order_type": "all",
                },
                {
                  "code": "DIGISMART",
                  "title": "Get 10% OFF upto ₹200",
                  "description": "Applicable only on transactions using Standard Chartered Digismart Card. Maximum Discount is ₹200.",
                  "discount_type": "percentage",
                  "discount_value": 10.0,
                  "max_discount_amount": 200.0,
                  "min_cart_amount": 199.0,
                  "allowed_order_type": "all",
                },
                {
                  "code": "AUCC30",
                  "title": "Get 5% off",
                  "description": "Applicable only on transactions using AU Bank Credit Cards.",
                  "discount_type": "flat",
                  "discount_value": 30.0,
                  "min_cart_amount": 350.0,
                  "allowed_order_type": "all",
                },
                {
                  "code": "PAYTMNEW",
                  "title": "Flat ₹100 Cashback",
                  "description": "Applicable for users who are new to the Paytm app and have not transacted previously.",
                  "discount_type": "flat",
                  "discount_value": 100.0,
                  "min_cart_amount": 299.0,
                  "allowed_order_type": "all",
                },
              ];
        _isLoading = false;
      });
    }
  }

  Future<void> _applyCouponCode(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _isApplying = true;
    });

    final result = await ApiService.validateCoupon(
      code: code.trim().toUpperCase(),
      subtotal: widget.currentSubtotal,
      orderType: widget.orderType,
    );

    if (mounted) {
      setState(() {
        _isApplying = false;
      });

      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 ${result['message'] ?? 'Coupon Applied!'}"),
            backgroundColor: const Color(0XFF0C831F),
          ),
        );
        widget.onCouponApplied?.call(result['data']);
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Cannot apply coupon"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Coupons",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0XFF0C831F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Manual Input Coupon Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: "Type coupon code here",
                              hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isApplying
                              ? null
                              : () => _applyCouponCode(_codeController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0XFF0C831F),
                            disabledBackgroundColor: Colors.grey.shade300,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: _isApplying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  "Apply",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Bank offers & Promotions",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Dynamic Coupons Cards List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _coupons.length,
                    itemBuilder: (context, index) {
                      final c = _coupons[index];
                      final String code = c['code'] ?? '';
                      final String title = c['title'] ?? 'Discount Coupon';
                      final String desc = c['description'] ?? '';
                      final double minCart = double.tryParse(c['min_cart_amount']?.toString() ?? '0') ?? 0.0;
                      final bool isEligible = widget.currentSubtotal >= minCart;
                      final double shortAmount = minCart - widget.currentSubtotal;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
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
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0XFFF5F5F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.confirmation_number_outlined, color: Color(0XFF0C831F)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Use code $code",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: isEligible
                                        ? () => _applyCouponCode(code)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isEligible ? const Color(0XFF0C831F) : Colors.grey.shade200,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    ),
                                    child: Text(
                                      "Apply",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isEligible ? Colors.white : Colors.black38,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0XFFEEEEEE)),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isEligible) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.circle, size: 6, color: Color(0XFF00897B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Add items worth ₹${shortAmount.toStringAsFixed(0)} more to apply this offer",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0XFF00897B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Row(
                                    children: [
                                      const Icon(Icons.circle, size: 6, color: Colors.black45),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          desc.isNotEmpty ? desc : "Applicable on qualifying orders",
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
