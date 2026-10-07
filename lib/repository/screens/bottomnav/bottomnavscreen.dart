import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blinkit_series/repository/screens/cart/cartscreen.dart';
import 'package:blinkit_series/repository/screens/profile/bulk_custom_order_screen.dart';
import 'package:blinkit_series/repository/screens/category/categoryscreen.dart';
import 'package:blinkit_series/repository/screens/home/homescreen.dart';
import 'package:blinkit_series/repository/screens/profile/profilescreen.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/widgets/blinkit_nav_bar.dart';
import 'package:blinkit_series/repository/widgets/floating_cart_pill.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    ApiService.registerFcmToken();
  }

  void _navigateToHome() {
    if (currentIndex != 0) {
      setState(() {
        currentIndex = 0;
      });
    }
  }

  void _navigateToCategories() {
    if (currentIndex != 1) {
      setState(() {
        currentIndex = 1;
      });
    }
  }

  void _navigateToProfile() {
    if (currentIndex != 3) {
      setState(() {
        currentIndex = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nav Bar tab ordering: 0: Home, 1: Categories, 2: Easy Order (BulkCustomOrderScreen), 3: Profile
    final List<Widget> pages = [
      HomeScreen(
        onProfileTap: _navigateToProfile,
        onCategoriesTap: _navigateToCategories,
      ),
      CategoryScreen(onProfileTap: _navigateToProfile),
      BulkCustomOrderScreen(onBackTap: _navigateToHome),
      ProfileScreen(onBackTap: _navigateToHome),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If not on Home tab, navigate back to Home tab (0) instead of exiting app
        if (currentIndex != 0) {
          setState(() {
            currentIndex = 0;
          });
        } else {
          // System Pop on Home tab exits app cleanly
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: currentIndex,
              children: pages,
            ),
            if (currentIndex != 2)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
                child: FloatingCartPill(
                  onViewCartTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                          onBackTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              _navigateToHome();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        bottomNavigationBar: currentIndex == 2
            ? null
            : BlinkitNavBar(
                currentIndex: currentIndex,
                onTap: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
      ),
    );
  }
}
