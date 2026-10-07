import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:blinkit_series/repository/widgets/skeleton_loader.dart';

class UiHelper {
  static Widget CustomImage({required String img, double? width, double? height, BoxFit fit = BoxFit.contain}) {
    String cleanUrl = img.trim();

    Widget buildFallback() {
      return Image.asset(
        'assets/images/no_product.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, st) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0XFFF2F4F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, color: Color(0XFF0C831F), size: 24),
          ),
        ),
      );
    }

    if (cleanUrl.isEmpty) {
      return buildFallback();
    }

    if (cleanUrl.contains('sbmartquick.com/uploads/')) {
      final String uploadPath = cleanUrl.substring(cleanUrl.indexOf('uploads/'));
      cleanUrl = 'https://admin.sbmartquick.com/$uploadPath';
    } else if (cleanUrl.contains('uploads/')) {
      final String uploadPath = cleanUrl.substring(cleanUrl.indexOf('uploads/'));
      cleanUrl = 'https://admin.sbmartquick.com/$uploadPath';
    } else if (cleanUrl.contains('storage/')) {
      final String storagePath = cleanUrl.substring(cleanUrl.indexOf('storage/'));
      cleanUrl = 'https://admin.sbmartquick.com/$storagePath';
    } else if (cleanUrl.startsWith('/')) {
      cleanUrl = 'https://admin.sbmartquick.com$cleanUrl';
    }

    // 2. Handle Network Images (HTTP / HTTPS) with Disk-Persistent Caching
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      final String encodedUrl = cleanUrl.contains(' ') ? Uri.encodeFull(cleanUrl) : cleanUrl;
      return CachedNetworkImage(
        imageUrl: encodedUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => SkeletonLoader(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          borderRadius: 8,
        ),
        errorWidget: (context, url, error) {
          debugPrint("UiHelper.CustomImage error loading $encodedUrl: $error");
          return buildFallback();
        },
      );
    }

    // 3. Fallback mapping for asset-only category references
    if (cleanUrl.contains('01_vegetables') || cleanUrl.contains('02_dairy') || cleanUrl.contains('03_snacks') || cleanUrl.contains('04_personal') || cleanUrl.contains('05_home') || cleanUrl.contains('06_atta') || cleanUrl.contains('07_oil') || cleanUrl.contains('08_instant') || cleanUrl.contains('09_beverages') || cleanUrl.contains('10_baby') || cleanUrl.contains('11_pet') || cleanUrl.contains('12_frozen') || cleanUrl.contains('13_bakery') || cleanUrl.contains('14_fresh') || cleanUrl.contains('15_kitchen') || cleanUrl.contains('16_organic')) {
      final String fileName = cleanUrl.replaceAll('https://admin.sbmartquick.com/uploads/categories/', '').replaceAll('https://sbmartquick.com/uploads/categories/', '').replaceAll('http://sbmartquick.com/uploads/categories/', '').replaceAll('/uploads/categories/', '').replaceAll('uploads/categories/', '').split('?').first.trim();
      final String cleanPath = fileName.startsWith('assets/images/') ? fileName : "assets/images/$fileName";
      return Image.asset(
        cleanPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, st) => buildFallback(),
      );
    }

    String cleanPath = cleanUrl.startsWith('assets/images/') ? cleanUrl : "assets/images/$cleanUrl";

    return Image.asset(
      cleanPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => buildFallback(),
    );
  }

  static CustomText(
      {required String text,
      required Color color,
      required FontWeight fontweight,
      String? fontfamily,
      required double fontsize}) {
    return Text(
      text,
      style: TextStyle(
          fontSize: fontsize,
          fontFamily: fontfamily ?? "regular",
          fontWeight: fontweight,
          color: color),
    );
  }
  static CustomTextField({required TextEditingController controller}){
    return Container(
      height: 40,
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(
          color: Color(0XFFC5C5C5)
        )
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: "Search 'ice-cream'",
          prefixIcon: const Icon(Icons.search, color: Color(0XFF9C9C9C)),
          border: InputBorder.none
        ),
      ),
    );
  }

  static CustomButton(VoidCallback callback){
    return Container(
      height: 18,
      width: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color(0XFF27AF34)
        ),
        borderRadius: BorderRadius.circular(4)
      ),
      child: Center(child: Text("Add",style: TextStyle(fontSize: 8,color: Color(0XFF27AF34)),),),
    );
  }
}
