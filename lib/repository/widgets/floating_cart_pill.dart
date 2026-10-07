import 'package:flutter/material.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';

class FloatingCartPill extends StatefulWidget {
  final VoidCallback onViewCartTap;

  const FloatingCartPill({super.key, required this.onViewCartTap});

  @override
  State<FloatingCartPill> createState() => _FloatingCartPillState();
}

class _FloatingCartPillState extends State<FloatingCartPill> {
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
    final cartItems = _cart.items.values.toList();

    if (totalCount == 0) return const SizedBox.shrink();

    // Get image of the most recently added item
    final String lastImg = cartItems.isNotEmpty ? cartItems.last.img : "image 41.png";

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: InkWell(
            onTap: widget.onViewCartTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0XFF097925),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Thumbnail inside White Circle
                  Container(
                    height: 38,
                    width: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: UiHelper.CustomImage(img: lastImg),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // View cart & item count text
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "View cart",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$totalCount ${totalCount == 1 ? 'item' : 'items'}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chevron Circle Button on Right
                  Container(
                    height: 36,
                    width: 36,
                    decoration: const BoxDecoration(
                      color: Color(0XFF055C1B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
