import 'package:flutter/material.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';

class AnimatedBottomCartBar extends StatefulWidget {
  final VoidCallback onViewCartTap;

  const AnimatedBottomCartBar({super.key, required this.onViewCartTap});

  @override
  State<AnimatedBottomCartBar> createState() => _AnimatedBottomCartBarState();
}

class _AnimatedBottomCartBarState extends State<AnimatedBottomCartBar> {
  final CartController _cart = CartController.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_update);
  }

  @override
  void dispose() {
    _cart.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = _cart.totalItemCount;
    final double totalAmount = _cart.totalAmount;

    if (totalCount == 0) return const SizedBox.shrink();

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      offset: totalCount > 0 ? Offset.zero : const Offset(0, 1),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0XFF0C831F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$totalCount ${totalCount == 1 ? 'ITEM' : 'ITEMS'}  |  ₹${totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Extra discounts applied",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: widget.onViewCartTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        "View Cart",
                        style: TextStyle(
                          color: Color(0XFF0C831F),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0XFF0C831F),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
