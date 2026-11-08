import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';

class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFDDE4F7),
    highlightColor: Colors.white,
    child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 17, backgroundColor: AppPalette.outline),
              const SizedBox(width: 9),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _line(110, 11), const SizedBox(height: 5), _line(65, 9),
              ]),
            ]),
            const SizedBox(height: 10),
            _line(double.infinity, 17),
            const SizedBox(height: 8),
            _line(210, 17),
            const SizedBox(height: 10),
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const AspectRatio(aspectRatio: 16/9,
                child: ColoredBox(color: AppPalette.outline)),
            )),
            const SizedBox(height: 9),
            _line(double.infinity, 12),
            const SizedBox(height: 7),
            _line(184, 12),
            const SizedBox(height: 8),
            _line(112, 17),
          ]),
        ),
      ),
    ),
  );

  Widget _line(double width, double height) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: AppPalette.outline,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
