import 'package:flutter/material.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';

class BlinkitNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BlinkitNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<BlinkitNavBar> createState() => _BlinkitNavBarState();
}

class _BlinkitNavBarState extends State<BlinkitNavBar> {
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
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0XFFE0E0E0),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          _buildNavItem(
            index: 0,
            label: "Home",
            customIcon: _buildHomeIcon(widget.currentIndex == 0),
          ),
          _buildNavItem(
            index: 1,
            label: "Categories",
            customIcon: _buildCategoriesIcon(widget.currentIndex == 1),
          ),
          _buildNavItem(
            index: 2,
            label: "Easy Order",
            customIcon: Icon(
              widget.currentIndex == 2 ? Icons.assignment : Icons.assignment_outlined,
              size: 24,
              color: widget.currentIndex == 2 ? Colors.black : const Color(0XFF616161),
            ),
          ),
          _buildNavItem(
            index: 3,
            label: "Profile",
            customIcon: Icon(
              widget.currentIndex == 3 ? Icons.person : Icons.person_outline_rounded,
              size: 26,
              color: widget.currentIndex == 3 ? Colors.black : const Color(0XFF616161),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required Widget customIcon,
  }) {
    final bool isSelected = widget.currentIndex == index;

    return InkWell(
      onTap: () => widget.onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Active Indicator Black Bar
          Container(
            height: 3,
            width: 36,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ),

          customIcon,

          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? Colors.black : const Color(0XFF616161),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Yellow House Icon matching screenshot
  Widget _buildHomeIcon(bool isSelected) {
    return Container(
      height: 26,
      width: 26,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0XFFFFD54F) : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Container(
          height: 8,
          width: 7,
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }

  // Custom 4 Circles Categories Icon matching screenshot
  Widget _buildCategoriesIcon(bool isSelected) {
    final Color color = isSelected ? Colors.black : const Color(0XFF616161);
    return SizedBox(
      height: 24,
      width: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
              const SizedBox(width: 3),
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cart Icon with Live Small Cart Count Badge
  Widget _buildCartIcon(bool isSelected, int count) {
    final Color iconColor = isSelected ? Colors.black : const Color(0XFF616161);

    return SizedBox(
      width: 32,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            isSelected ? Icons.shopping_cart : Icons.shopping_cart_outlined,
            size: 26,
            color: iconColor,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0XFF097925),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? "99+" : "$count",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
