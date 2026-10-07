import 'package:flutter/material.dart';
import 'package:blinkit_series/domain/cart/cart_controller.dart';

class AdvancedAnimatedNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdvancedAnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AdvancedAnimatedNavBar> createState() => _AdvancedAnimatedNavBarState();
}

class _AdvancedAnimatedNavBarState extends State<AdvancedAnimatedNavBar> {
  final CartController _cart = CartController.instance;

  final List<NavItemData> _items = [
    NavItemData(
      label: "Home",
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    NavItemData(
      label: "Easy Order",
      activeIcon: Icons.assignment,
      inactiveIcon: Icons.assignment_outlined,
    ),
    NavItemData(
      label: "Categories",
      activeIcon: Icons.grid_view_rounded,
      inactiveIcon: Icons.grid_view_outlined,
    ),
    NavItemData(
      label: "Print",
      activeIcon: Icons.print_rounded,
      inactiveIcon: Icons.print_outlined,
    ),
  ];

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final bool isSelected = widget.currentIndex == index;
            final int cartCount = _cart.totalItemCount;

            return InkWell(
              onTap: () => widget.onTap(index),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0XFF0C831F).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.inactiveIcon,
                          color: isSelected
                              ? const Color(0XFF0C831F)
                              : const Color(0XFF757575),
                          size: 24,
                        ),
                        if (item.isCart && cartCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0XFFE23744),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                "$cartCount",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      firstCurve: Curves.easeInOut,
                      secondCurve: Curves.easeInOut,
                      crossFadeState: isSelected
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: Color(0XFF0C831F),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class NavItemData {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isCart;

  NavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    this.isCart = false,
  });
}
