import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  static Widget productCardSkeleton() {
    return Container(
      width: 125,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLoader(width: double.infinity, height: 85, borderRadius: 8),
          SizedBox(height: 8),
          SkeletonLoader(width: 90, height: 12, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonLoader(width: 60, height: 10, borderRadius: 4),
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader(width: 40, height: 14, borderRadius: 4),
              SkeletonLoader(width: 50, height: 24, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }

  static Widget searchTileSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 80, height: 80, borderRadius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(width: 60, height: 10, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonLoader(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                SkeletonLoader(width: 80, height: 10, borderRadius: 4),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader(width: 50, height: 16, borderRadius: 4),
                    SkeletonLoader(width: 65, height: 26, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget homePageFullSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner skeleton
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0XFF0C831F).withOpacity(0.85),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const SkeletonLoader(width: 140, height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 220, height: 22, borderRadius: 6),
                const SizedBox(height: 16),
                const SkeletonLoader(width: double.infinity, height: 46, borderRadius: 12),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Category tabs skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: const SkeletonLoader(width: double.infinity, height: 36, borderRadius: 18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Promo Grid Cards Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: List.generate(
                4,
                (index) => const SkeletonLoader(width: double.infinity, height: 110, borderRadius: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Featured Section Header Skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonLoader(width: 180, height: 20, borderRadius: 6),
          ),
          const SizedBox(height: 12),
          // Horizontal product cards skeleton
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) => productCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
