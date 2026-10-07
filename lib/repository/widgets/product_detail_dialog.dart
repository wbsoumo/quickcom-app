import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blinkit_series/repository/widgets/uihelper.dart';
import 'package:blinkit_series/repository/widgets/animated_cart_button.dart';

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:blinkit_series/repository/services/api_service.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailDialog({super.key, required this.product});

  static void show(BuildContext context, Map<String, dynamic> product) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Product Details',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return ProductDetailDialog(product: product);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final springCurve = CurvedAnimation(
          parent: anim1,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInBack,
        );
        final fadeCurve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOut,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.2, end: 1.0).animate(springCurve),
          child: FadeTransition(
            opacity: fadeCurve,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  bool _isWishlisted = false;
  bool _isWishlistLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
    _checkInitialWishlistStatus();
  }

  Future<void> _checkInitialWishlistStatus() async {
    final String productId = (widget.product['id'] ?? '').toString();
    if (productId.isEmpty) return;
    try {
      final res = await ApiService.fetchUserWishlist();
      final List<String> ids = List<String>.from(res['product_ids'] ?? []);
      if (mounted) {
        setState(() {
          _isWishlisted = ids.contains(productId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleWishlist() async {
    final String productId = (widget.product['id'] ?? '').toString();
    if (productId.isEmpty || _isWishlistLoading) return;

    setState(() {
      _isWishlistLoading = true;
    });

    final bool newStatus = await ApiService.toggleWishlistProduct(productId: productId);

    if (mounted) {
      setState(() {
        _isWishlisted = newStatus;
        _isWishlistLoading = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Added to your wishlist' : 'Removed from wishlist',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newStatus ? const Color(0XFF0C831F) : Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareProduct() async {
    final String title = (widget.product['name'] ?? widget.product['text'] ?? 'Product Details').toString();
    final double price = (widget.product['price'] is num)
        ? (widget.product['price'] as num).toDouble()
        : double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0;
    final String mainImg = (widget.product['img'] ?? widget.product['image'] ?? '').toString();

    // Process image URL if present
    String fullImgUrl = mainImg;
    if (fullImgUrl.startsWith('http://sbmartquick.com/uploads/')) {
      fullImgUrl = fullImgUrl.replaceFirst('http://sbmartquick.com/uploads/', 'https://admin.sbmartquick.com/uploads/');
    } else if (fullImgUrl.startsWith('https://sbmartquick.com/uploads/')) {
      fullImgUrl = fullImgUrl.replaceFirst('https://sbmartquick.com/uploads/', 'https://admin.sbmartquick.com/uploads/');
    } else if (fullImgUrl.isNotEmpty && !fullImgUrl.startsWith('http')) {
      fullImgUrl = 'https://admin.sbmartquick.com/uploads/products/$fullImgUrl';
    }

    final String shareText = "$title\nPrice: ₹${price.toStringAsFixed(0)}\n\nDownload SonarbanglaMart App now:\nhttps://sbmartquick.com/";

    try {
      if (fullImgUrl.isNotEmpty && fullImgUrl.startsWith('http')) {
        final response = await http.get(Uri.parse(fullImgUrl)).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final String extension = fullImgUrl.contains('.png') ? 'png' : 'jpg';
          final file = File('${tempDir.path}/shared_product_$epochMs.$extension');
          await file.writeAsBytes(response.bodyBytes);

          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            subject: "Check out $title on SonarbanglaMart",
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Error sharing product photo media file: $e");
    }

    // Fallback to text share if image download fails
    await Share.share(
      shareText,
      subject: "Check out $title on SonarbanglaMart",
    );
  }

  int get epochMs => DateTime.now().millisecondsSinceEpoch;

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _pageController.hasClients) {
        final galleryList = _getGalleryImages();
        if (galleryList.length > 1) {
          final nextPage = (_currentPage + 1) % galleryList.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  List<String> _getGalleryImages() {
    final String mainImg = (widget.product['img'] ?? widget.product['image'] ?? '').toString();
    final List<String> gallery = [];
    if (mainImg.isNotEmpty) gallery.add(mainImg);

    if (widget.product['gallery'] is List) {
      for (var item in widget.product['gallery']) {
        final str = item.toString();
        if (str.isNotEmpty && !gallery.contains(str)) gallery.add(str);
      }
    }

    // Add high quality fallback gallery angles if single image
    if (gallery.length == 1) {
      gallery.add(mainImg);
      gallery.add(mainImg);
    }
    return gallery;
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title = (widget.product['name'] ?? widget.product['text'] ?? 'Product Details').toString();
    final double price = (widget.product['price'] is num)
        ? (widget.product['price'] as num).toDouble()
        : double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0;
    final double mrp = (widget.product['mrp'] is num)
        ? (widget.product['mrp'] as num).toDouble()
        : double.tryParse(widget.product['mrp']?.toString() ?? (price > 0 ? (price * 1.25).toString() : '0')) ?? (price > 0 ? price * 1.25 : 0.0);
    final String unit = (widget.product['unit'] ?? '1 pc').toString();
    final String id = (widget.product['id'] ?? 'detail_prod').toString();
    final String description = widget.product['description']?.toString() ?? 'Fresh quality product delivered right to your doorstep in 16 minutes.';

    final String mainImg = (widget.product['img'] ?? widget.product['image'] ?? '').toString();
    final List<String> images = _getGalleryImages();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Action Header with back arrow and bookmark/share
            Container(
              color: const Color(0XFFF9F9F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.black87, size: 24),
                    ),
                  ),
                  Row(
                    children: [
                      // Wishlist Heart Button directly on left of Share button
                      InkWell(
                        onTap: _toggleWishlist,
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isWishlisted ? const Color(0XFFFFEBEE) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: _isWishlisted ? const Color(0XFFE53935) : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _shareProduct,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.ios_share, color: Colors.black87, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Product Hero Image Auto-Sliding PageView Gallery Container
            Container(
              height: 230,
              width: double.infinity,
              color: const Color(0XFFF9F9F9),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Hero(
                            tag: index == 0 ? "product_img_$id" : "product_img_${id}_$index",
                            child: UiHelper.CustomImage(img: images[index], fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                  ),
                  // Animated Dot Page Indicator
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? const Color(0XFF0C831F) : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Body Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0XFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Color(0XFF0C831F), size: 14),
                            SizedBox(width: 2),
                            Text("16 MINS", style: TextStyle(color: Color(0XFF0C831F), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0XFFFFF8E1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Color(0XFFF7CB45), size: 14),
                            SizedBox(width: 2),
                            Text("4.8 (2.4k)", style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Unit Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade300),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.blue.shade50.withOpacity(0.4),
                    ),
                    child: Text(
                      unit,
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0XFFEEEEE)),

            // Bottom Price Bar with ADD Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          Text(
                            "₹${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (mrp > price) ...[
                            const SizedBox(width: 6),
                            Text(
                              "₹${mrp.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  AnimatedCartButton(
                    id: id,
                    name: title,
                    img: mainImg,
                    price: price,
                    unit: unit,
                    maxStock: int.tryParse(widget.product['available_stock']?.toString() ?? widget.product['stock']?.toString() ?? '10'),
                    width: 100,
                    height: 38,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
