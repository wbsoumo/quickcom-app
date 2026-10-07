import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blinkit_series/repository/screens/profile/profile_detail_screen.dart';
import 'package:blinkit_series/repository/screens/profile/order_history_screen.dart';
import 'package:blinkit_series/repository/screens/profile/bulk_custom_order_screen.dart';
import 'package:blinkit_series/repository/screens/profile/need_help_screen.dart';
import 'package:blinkit_series/repository/screens/login/loginscreen.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:blinkit_series/repository/widgets/address_selection_bottom_sheet.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';
import 'package:blinkit_series/repository/widgets/product_detail_dialog.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const ProfileScreen({super.key, this.onBackTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  String _userPhone = "8016222991";
  String _userName = "Your account";
  String _userGst = "";
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      final name = prefs.getString('user_name');
      final savedGst = prefs.getString('user_gst') ?? "";
      final targetPhone = phone ?? _userPhone;
      
      final wallet = await ApiService.fetchUserWallet(phone: targetPhone);
      final userProfile = await ApiService.fetchUserProfile(targetPhone);

      if (mounted) {
        setState(() {
          if (phone != null && phone.isNotEmpty) _userPhone = phone;
          if (name != null && name.isNotEmpty) _userName = name;
          _userGst = savedGst;
          if (userProfile != null && userProfile['gst_number'] != null && userProfile['gst_number'].toString().isNotEmpty) {
            _userGst = userProfile['gst_number'].toString();
          }
          _walletBalance = wallet;
        });
      }
    } catch (_) {}
  }

  void _navigateToDetail(BuildContext context, String title, Widget content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(title: title, content: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF5F6F8),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. Warm Soft Gradient Header with Back Button & Profile Avatar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0XFFFDF1C2), Color(0XFFF5F6F8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Back arrow header row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                              onPressed: () {
                                widget.onBackTap?.call();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Profile Avatar Circle
                    const CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: Color(0XFF333333),
                        child: Icon(Icons.person, color: Colors.white, size: 48),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title & Phone Number
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userPhone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0XFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 2. Three Main Quick Action Cards (Your orders, Blinkit Money, Need help?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTopQuickCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0XFF0C831F),
                      label: "Your orders",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTopQuickCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: "SB Mart Money",
                      onTap: () => _navigateToDetail(context, "SB Mart Money", _buildBlinkitMoneyContent()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTopQuickCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: "Need help?",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NeedHelpScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. "Your information" Section Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text(
                        "Your information",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _buildOptionTile(
                      icon: Icons.menu_book_outlined,
                      title: "Address book",
                      onTap: () => _navigateToDetail(context, "Address book", _buildAddressBookContent()),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.favorite_border_rounded,
                      title: "Your wishlist",
                      onTap: () => _navigateToDetail(context, "Your wishlist", _buildWishlistContent()),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.inventory_2_outlined,
                      title: "Bulk & Custom Orders",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BulkCustomOrderScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. "Payment and coupons" Section Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text(
                        "Payment and coupons",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _buildOptionTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "SB Mart Money",
                      onTap: () => _navigateToDetail(context, "SB Mart Money", _buildBlinkitMoneyContent()),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.card_giftcard_outlined,
                      title: "E-gift cards",
                      onTap: () => _navigateToDetail(context, "E-gift cards", _buildEGiftCardsContent()),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.receipt_long_outlined,
                      title: "GST details",
                      onTap: () => _navigateToDetail(context, "GST details", _buildGstContent()),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 6. "Other Information" Section Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text(
                        "Other Information",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _buildOptionTile(
                      icon: Icons.info_outline_rounded,
                      title: "About Us",
                      onTap: () => _navigateToDetail(
                        context,
                        "About Us",
                        _buildLegalPageContent(
                          title: "About Us",
                          url: "https://sbmartquick.com/about-us",
                          paragraphs: [
                            "Welcome to SonarbanglaMart – your premier quick-commerce grocery delivery service bringing fresh groceries, daily essentials, fruits, vegetables, dairy, and household items straight to your doorstep in 10 to 16 minutes.",
                            "Our mission is to redefine grocery shopping for Bengal and India by operating hyper-local micro-fulfillment dark stores situated right in your neighborhood.",
                            "With SonarbanglaMart, you get 100% genuine products, verified local fresh produce, instant order tracking, and zero minimum order friction.",
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.gavel_outlined,
                      title: "Terms and Conditions",
                      onTap: () => _navigateToDetail(
                        context,
                        "Terms and Conditions",
                        _buildLegalPageContent(
                          title: "Terms and Conditions",
                          url: "https://sbmartquick.com/terms-and-conditions",
                          paragraphs: [
                            "Please read these Terms and Conditions carefully before using the SonarbanglaMart application or services.",
                            "1. Account Requirements: Users must provide accurate phone numbers and delivery locations. Orders placed via Cash on Delivery (COD) must be accepted at doorstep.",
                            "2. Delivery Timelines: Estimated delivery times of 10-16 minutes are subject to local traffic, weather, and store serviceability zones.",
                            "3. Pricing & Billing: All prices listed include applicable GST taxes. Promotional coupon discounts are subject to valid usage criteria.",
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy policy",
                      onTap: () => _navigateToDetail(
                        context,
                        "Privacy policy",
                        _buildLegalPageContent(
                          title: "Privacy Policy",
                          url: "https://sbmartquick.com/privacy-policy",
                          paragraphs: [
                            "Effective Date: October 5, 2026 | Last Updated: October 5, 2026",
                            "Welcome to SonarbanglaMart (accessible at https://sbmartquick.com and through our Android mobile application). SonarbanglaMart Quick Commerce Private Limited (\"SonarbanglaMart\", \"we\", \"us\", or \"our\") is dedicated to safeguarding your personal data, privacy, and security in full compliance with applicable Indian data protection laws and Google Play Developer Policies.",
                            "1. Information We Collect\nWe collect information directly provided by you, automatically gathered from your device, and generated during your use of our services:\n• Personal & Contact Information: Name, mobile phone number, email address, and delivery addresses (street address, city, pin code).\n• Precise Location Data: Device GPS coordinates (latitude and longitude) to calculate nearest dark store eligibility, serviceability, delivery distance, and rider routing.\n• Transactional & Order Information: Items added to cart, wishlist items, order status history, Cash on Delivery (COD) payment preferences, and SB Mart Wallet balance.\n• Device & Network Identifiers: IP address, device model, Android OS version, unique FCM Push Notification tokens, and app performance logs.",
                            "2. Android App Permissions & Justifications\nOur Android mobile application requests specific device permissions to function properly. Below is a detailed breakdown of every permission, why it is needed, and how it is used:\n\n• ACCESS_FINE_LOCATION & ACCESS_COARSE_LOCATION (GPS & Network Location):\nPurpose: Used to determine your exact delivery location, identify the nearest active SonarbanglaMart fulfillment store within a 15km delivery radius, and calculate dynamic delivery fees.\nData handling: Collected while using the app. Location coordinates are transmitted securely over SSL/HTTPS. We do NOT collect background location when the app is closed.\n\n• POST_NOTIFICATIONS (Push Notifications):\nPurpose: Used to send real-time order status updates (Packing, Out for Delivery, Delivered), rider assignment alerts, and promotional offer notifications via Firebase FCM.\nOpt-out: You can manage notification preferences in the app or disable them anytime via Android System Settings.\n\n• INTERNET & ACCESS_NETWORK_STATE (Network Access):\nPurpose: Required to communicate securely with our cloud REST APIs, fetch product catalogs, update real-time inventory, and verify sync versions.\n\n• VIBRATE (Haptic Feedback):\nPurpose: Provides tactile feedback when tapping interactive UI elements, adding items to cart, or toggling wishlist products.",
                            "3. How We Use Your Information\nWe process your personal data strictly for legitimate operational purposes:\n• To process, fulfill, and deliver your grocery and essential orders within 10-16 minutes.\n• To assign delivery riders and navigate them to your specified delivery address.\n• To calculate accurate delivery charges, apply promotional coupon discounts, and manage wallet credits.\n• To send critical transactional SMS and FCM push notifications regarding order status.\n• To prevent fraud, verify Cash on Delivery (COD) orders, and secure user accounts.",
                            "4. Data Sharing & Third-Party Services\nWe do NOT sell, rent, or trade your personal data to third parties. Data is shared only with trusted infrastructure providers necessary for app functionality:\n• Delivery Partners & Riders: Name, phone number, and delivery address shared with assigned delivery partners solely for order fulfillment.\n• Firebase Cloud Messaging (Google FCM): Device FCM token used to deliver push notifications.\n• Cloud Hosting & Infrastructure: SSL-encrypted web servers (admin.sbmartquick.com) hosted in secure data centers.",
                            "5. Data Security & Storage\nAll data transmitted between your device and our servers is encrypted using industry-standard 256-bit SSL/TLS (HTTPS) encryption. Database tables store passwords using strong bcrypt hashing. Local app state is stored securely in encrypted device storage.",
                            "6. Data Retention & Account Deletion Policy\nWe retain your personal information for as long as your account remains active. As mandated by Google Play User Data policies, users have full control over their account data:\n• In-App Account Deletion: You can delete your account anytime in the app under Profile → Account Privacy → Delete your account. Requiring current password confirmation, your account status will be set to deleted, personal data soft-deleted, FCM tokens purged, and local device storage cleared instantly.\n• Web Deletion Request: You may also request account and data deletion by emailing our Data Protection Officer at support@sbmartquick.com. Requests are processed within 24 hours.",
                            "7. Children's Privacy\nOur services are intended for users aged 18 and above. We do not knowingly collect personal information from children under 13.",
                            "8. Contact Us & Grievance Redressal\nIf you have any questions, concerns, or requests regarding this Privacy Policy or data protection, please contact us at:\nSonarbanglaMart Support & Grievance Officer\nEmail: support@sbmartquick.com\nWebsite: https://sbmartquick.com",
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.shopping_bag_outlined,
                      title: "Shopping policy",
                      onTap: () => _navigateToDetail(
                        context,
                        "Shopping policy",
                        _buildLegalPageContent(
                          title: "Shopping Policy",
                          url: "https://sbmartquick.com/shopping-policy",
                          paragraphs: [
                            "Our Shopping Policy outlines how items are reserved, picked, packed, and delivered.",
                            "1. Stock Availability: Real-time inventory ensures items added to cart are reserved during checkout.",
                            "2. Quality Guarantee: Perishable items like milk, dairy, fruits, and vegetables undergo temperature-controlled quality checks before dispatch.",
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.assignment_return_outlined,
                      title: "Refund Policy",
                      onTap: () => _navigateToDetail(
                        context,
                        "Refund Policy",
                        _buildLegalPageContent(
                          title: "Refund Policy",
                          url: "https://sbmartquick.com/refund-policy",
                          paragraphs: [
                            "At SonarbanglaMart, customer satisfaction is our top priority.",
                            "1. Damaged or Missing Items: If an item is missing or damaged, report it immediately to our support team for an instant wallet credit or cash refund.",
                            "2. Order Cancellation: Orders can be canceled free of charge before rider dispatch.",
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.notifications_none_rounded,
                      title: "Notification Preferences",
                      onTap: () => _navigateToDetail(context, "Notification Preferences", _buildNotificationPreferencesContent()),
                    ),
                    const Divider(height: 1, indent: 48),
                    _buildOptionTile(
                      icon: Icons.security_rounded,
                      title: "Account Privacy",
                      onTap: () => _navigateToDetail(context, "Account Privacy", _buildAccountPrivacyContent()),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 7. Logout Button Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFFFFEBEE),
                    foregroundColor: const Color(0XFFD32F2F),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0XFFFFCDD2), width: 1),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Color(0XFFD32F2F), size: 20),
                  label: const Text(
                    "Log out",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showLogoutConfirmationDialog(context),
                ),
              ),
            ),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Log out",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          "Are you sure you want to log out of SonarbanglaMart?",
          style: TextStyle(fontSize: 14, color: Color(0XFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0XFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Log out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Top 3 Quick Cards Builder
  Widget _buildTopQuickCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: iconColor ?? Colors.black87),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Row Option Tile Builder
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? Colors.black87, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  // ------------ MOCK DETAIL CONTENTS FOR EACH RELEVANT OPTION ------------

  Widget _buildOrdersContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService.getUserOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0XFF0C831F)),
            ),
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text("No orders placed yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Your past and active orders will appear here.", style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          );
        }

        return Column(
          children: orders.map((ord) {
            final String status = ord['status']?.toString() ?? 'Pending';
            final String orderType = ord['order_type']?.toString() ?? 'delivery';
            final bool isPickup = orderType == 'pickup';
            final itemsList = ord['items'] as List? ?? [];
            final String itemsSummary = itemsList.map((e) => "${e['product_name']} x${e['quantity']}").join(", ");

            Color statusColor = const Color(0XFF0C831F); // Green default
            if (status == 'Pending') statusColor = Colors.orange;
            if (status == 'Out for Delivery' || status == 'Packing') statusColor = Colors.blue;
            if (status == 'Ready for Pickup') statusColor = Colors.purple;
            if (status == 'Cancelled') statusColor = Colors.red;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPickup ? Icons.storefront : Icons.local_shipping,
                            size: 18,
                            color: isPickup ? Colors.purple : const Color(0XFF0C831F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "#${ord['order_number']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        "₹${ord['grand_total']}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0XFF0C831F)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Placed on: ${ord['created_at'] ?? 'Recently'}",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  
                  if (ord['receiver_name'] != null && ord['receiver_name'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0XFFFFF8E1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Receiver: ${ord['receiver_name']} (${ord['receiver_phone']})",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],

                  if (isPickup) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF3E5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Store Pickup: ${ord['pickup_date'] ?? ''} (${ord['pickup_time'] ?? ''})",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                    ),
                  ],

                  const Divider(height: 16),
                  Text(
                    itemsSummary.isNotEmpty ? itemsSummary : "Order items details",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        status == 'Delivered' ? Icons.check_circle : Icons.timeline,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Status: $status",
                        style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBlinkitMoneyContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.fetchUserWalletDetails(phone: _userPhone),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final double bal = double.tryParse(data['wallet_balance']?.toString() ?? '') ?? _walletBalance;
        final List txs = data['transactions'] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0XFF0C831F), Color(0XFF085D15)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0XFF0C831F).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Available Wallet Balance", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    "₹${bal.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  const Text("Use wallet balance for instant partial or full checkout discount", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Passbook Section Title
            const Text(
              "Wallet Passbook & Transactions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 10),

            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0XFF0C831F)),
                ),
              )
            else if (txs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.black26),
                    SizedBox(height: 8),
                    Text(
                      "No wallet transactions yet",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Your credits, debits, and refunds will appear here.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: txs.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = txs[index];
                  final isCredit = t['type'] == 'credit';
                  final double amt = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
                  final double runBal = double.tryParse(t['running_balance']?.toString() ?? '0') ?? 0.0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCredit ? const Color(0XFFE8F5E9) : const Color(0XFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isCredit ? const Color(0XFF0C831F) : const Color(0XFFD32F2F),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['description'] ?? (isCredit ? 'Wallet Credit' : 'Wallet Debit'),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t['created_at'] ?? '',
                                style: const TextStyle(fontSize: 11, color: Color(0XFF757575)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isCredit ? '+' : '-'}₹${amt.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isCredit ? const Color(0XFF0C831F) : const Color(0XFFD32F2F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Bal: ₹${runBal.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildNeedHelpContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Text("Got a question regarding your active order or refund?", style: TextStyle(fontSize: 13, color: Colors.black54)),
              SizedBox(height: 16),
              Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.chat_bubble_outline, color: Color(0XFF0C831F)),
                title: Text("Chat with Live Support"),
                trailing: Icon(Icons.chevron_right),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone_outlined, color: Color(0XFF0C831F)),
                title: Text("Request Callback"),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressBookContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService.getUserAddresses(phone: _userPhone),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0XFF0C831F)),
            ),
          );
        }

        final addresses = snapshot.data ?? [];
        if (addresses.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.location_off_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text("No saved addresses found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Add your home or office address for express 10-min delivery.", style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    AddressSelectionBottomSheet.show(context);
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add New Address", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFF0C831F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            ...addresses.map((addr) {
              final String type = addr['custom_type_name'] != null && addr['custom_type_name'].toString().isNotEmpty
                  ? addr['custom_type_name'].toString()
                  : (addr['address_type'] ?? 'Home');
              final String details = addr['address_details'] ?? 'Saved Address';
              final String name = addr['receiver_name'] ?? _userName;
              final String phone = addr['receiver_phone'] ?? _userPhone;

              IconData icon = Icons.home_outlined;
              if (type.toLowerCase().contains('work') || type.toLowerCase().contains('office')) {
                icon = Icons.work_outline;
              } else if (type.toLowerCase().contains('other')) {
                icon = Icons.location_on_outlined;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0XFFE8F5E9),
                      child: Icon(icon, color: const Color(0XFF0C831F), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(details, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text("Receiver: $name ($phone)", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_vert, color: Colors.black38),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                AddressSelectionBottomSheet.show(context);
              },
              icon: const Icon(Icons.add, color: Color(0XFF0C831F)),
              label: const Text("Add Another Address", style: TextStyle(color: Color(0XFF0C831F), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0XFF0C831F)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookmarkedRecipesContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: const [
            Icon(Icons.soup_kitchen_outlined, size: 60, color: Colors.black26),
            SizedBox(height: 12),
            Text("No Bookmarked Recipes Yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 6),
            Text("Save your favorite recipes while browsing items!", style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.fetchUserWishlist(phone: _userPhone),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: Color(0XFF0C831F)),
            ),
          );
        }

        final wishlistRes = snapshot.data ?? {};
        final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(wishlistRes['data'] ?? []);

        if (items.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: const [
                Icon(Icons.favorite_border_rounded, size: 54, color: Colors.black26),
                SizedBox(height: 12),
                Text("Your Wishlist is Empty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text("Explore products and tap the heart icon to save for later.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "${items.length} saved item${items.length > 1 ? 's' : ''}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final String id = item['id']?.toString() ?? 'prod_$index';
                final String name = item['name']?.toString() ?? 'Product';
                final String unit = item['unit']?.toString() ?? '1 unit';
                final double price = double.tryParse(item['effective_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
                final double mrp = double.tryParse(item['effective_mrp']?.toString() ?? item['mrp']?.toString() ?? '0') ?? (price > 0 ? price * 1.2 : price);
                final String img = item['image']?.toString() ?? item['img']?.toString() ?? '';
                final int rawStock = int.tryParse(item['available_stock']?.toString() ?? item['stock']?.toString() ?? '10') ?? 10;

                final mapItem = {
                  "id": id,
                  "name": name,
                  "text": name,
                  "unit": unit,
                  "price": price,
                  "mrp": mrp,
                  "img": img,
                  "available_stock": rawStock,
                };

                return InkWell(
                  onTap: () => ProductDetailDialog.show(context, mapItem),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Stack with Heart Remove Button
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Container(
                                height: 105,
                                width: double.infinity,
                                color: const Color(0XFFF9F9F9),
                                child: UiHelper.CustomImage(
                                  img: img,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () async {
                                  await ApiService.toggleWishlistProduct(productId: id, phone: _userPhone);
                                  if (mounted) setState(() {});
                                },
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Colors.white.withOpacity(0.9),
                                  child: const Icon(Icons.favorite, size: 15, color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.15),
                              ),
                              const SizedBox(height: 4),
                              Text(unit, style: const TextStyle(fontSize: 10, color: Colors.black45)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("₹${price.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
                                      if (mrp > price)
                                        Text("₹${mrp.toStringAsFixed(0)}", style: const TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                    ],
                                  ),
                                  AnimatedCartButton(
                                    id: id,
                                    name: name,
                                    img: img,
                                    price: price,
                                    unit: unit,
                                    maxStock: rawStock,
                                    width: 62,
                                    height: 28,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGstContent() {
    return GstDetailsCard(
      initialGst: _userGst,
      userPhone: _userPhone,
      onGstSaved: (newGst) {
        setState(() {
          _userGst = newGst;
        });
      },
    );
  }

  Widget _buildEGiftCardsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          Icon(Icons.card_giftcard_outlined, size: 50, color: Color(0XFF0C831F)),
          SizedBox(height: 12),
          Text("SB Mart E-Gift Cards", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 6),
          Text("Gift instant groceries & electronics to your loved ones.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          Icon(Icons.description_outlined, size: 50, color: Color(0XFF0C831F)),
          SizedBox(height: 12),
          Text("Saved Medical Prescriptions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 6),
          Text("Upload and view prescriptions for express medicine delivery.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  // Helper builder for Legal & Info Pages with Open in Browser Action
  Widget _buildLegalPageContent({
    required String title,
    required String url,
    required List<String> paragraphs,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0XFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.article_outlined, color: Color(0XFF0C831F), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const Text(
                      "SonarbanglaMart Official Policy",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  p,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              )),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0XFF0C831F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            label: const Text("Open on Browser", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferencesContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Notification Preferences", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text("Manage order updates, promotional offers, and delivery alerts.", style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text("Order Tracking Alerts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("Receive live updates for order dispatch & delivery", style: TextStyle(fontSize: 12)),
            value: true,
            activeColor: const Color(0XFF0C831F),
            onChanged: (val) {},
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Offers & Promotions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("Get updates on discounts & daily fresh sales", style: TextStyle(fontSize: 12)),
            value: true,
            activeColor: const Color(0XFF0C831F),
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  Widget _buildAccountPrivacyContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Account Privacy & Safety", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text("Manage your data security and account settings.", style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.security, color: Color(0XFF0C831F)),
            title: const Text("Data Encryption", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("Your phone number and address data are encrypted in transit.", style: TextStyle(fontSize: 12)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0XFF0C831F)),
            title: const Text("Privacy Policy", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("Read our full data collection and app permissions policy", style: TextStyle(fontSize: 12)),
            onTap: () {
              final Uri uri = Uri.parse("https://sbmartquick.com/privacy-policy");
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: const Text("Delete your account", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)),
            subtitle: const Text("Deactivate account and permanently remove personal data", style: TextStyle(fontSize: 12)),
            onTap: () => _showDeleteAccountWarningDialog(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Warning: Deleting your account will deactivate your account and permanently remove your saved addresses, cart items, wishlist products, and order history.\n\nThis action cannot be undone.",
          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showPasswordConfirmationModal(context);
            },
            child: const Text("Proceed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPasswordConfirmationModal(BuildContext parentContext) {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;
    String errorMessage = '';

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Confirm Account Deletion",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Please enter your current account password to authorize deletion.",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Current Account Password",
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0XFF0C831F)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            final String password = passwordController.text.trim();
                            if (password.isEmpty) {
                              setModalState(() {
                                errorMessage = "Please enter your password to proceed.";
                              });
                              return;
                            }

                            setModalState(() {
                              isLoading = true;
                              errorMessage = '';
                            });

                            final result = await ApiService.deleteAccount(password: password);

                            if (result['success'] == true) {
                              Navigator.pop(context); // Close bottom sheet

                              // Purge local storage & user data
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.clear();

                              if (mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message'] ?? "Account deleted successfully."),
                                    backgroundColor: Colors.black87,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );

                                // Navigate to LoginScreen & remove all previous routes
                                Navigator.pushAndRemoveUntil(
                                  parentContext,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            } else {
                              setModalState(() {
                                isLoading = false;
                                errorMessage = result['message'] ?? "Incorrect password. Account was not deleted.";
                              });
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "Confirm & Delete Account",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class GstDetailsCard extends StatefulWidget {
  final String initialGst;
  final String userPhone;
  final Function(String) onGstSaved;

  const GstDetailsCard({
    super.key,
    required this.initialGst,
    required this.userPhone,
    required this.onGstSaved,
  });

  @override
  State<GstDetailsCard> createState() => _GstDetailsCardState();
}

class _GstDetailsCardState extends State<GstDetailsCard> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGst);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveGst() async {
    final gstText = _controller.text.trim().toUpperCase();
    if (gstText.isNotEmpty && gstText.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 15-digit GSTIN number')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final result = await ApiService.updateUserProfile(
      phone: widget.userPhone,
      gstNumber: gstText,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (result['status'] == 'success') {
        widget.onGstSaved(gstText);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0XFF0C831F),
            content: Text(gstText.isNotEmpty ? 'GSTIN saved to profile & invoices!' : 'GSTIN removed from profile.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(result['message'] ?? 'Failed to save GST details.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "GST Identification Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add your company GSTIN to claim tax credit on business orders and display it on your tax invoices.",
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            decoration: const InputDecoration(
              labelText: "GSTIN Number",
              hintText: "e.g. 19ABCDE1234F1ZH",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.receipt_long, color: Color(0XFF0C831F)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveGst,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0XFF0C831F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Save GST Details",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
