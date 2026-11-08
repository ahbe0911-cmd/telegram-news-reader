import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';

class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFDDE4F7),
      highlightColor: Colors.white,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) => Card(
          elevation: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundColor: AppPalette.outline),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line(135, 13),
                        const SizedBox(height: 8),
                        _line(78, 10),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(double.infinity, 20),
                    const SizedBox(height: 8),
                    _line(206, 20),
                  ],
                ),
              ),
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(color: AppPalette.outline),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(double.infinity, 14),
                    const SizedBox(height: 10),
                    _line(192, 14),
                    const SizedBox(height: 16),
                    _line(105, 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppPalette.outline,
          borderRadius: BorderRadius.circular(9),
        ),
      );
}
