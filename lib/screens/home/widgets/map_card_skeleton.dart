import 'package:material_ui/material_ui.dart';
import '../../../utils/theme.dart';
import '../../../widgets/shimmer.dart';
import '../../../widgets/surface_card.dart';

class MapCardSkeleton extends StatelessWidget {
  const MapCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SurfaceCard(
        radius: AppTheme.radiusLg,
        clip: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(
              height: AppTheme.mapCardImageHeight,
              borderRadius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(width: 60, height: 14),
                  const SizedBox(height: AppTheme.xs),
                  const ShimmerBox(width: 180, height: 29),
                  const SizedBox(height: AppTheme.sm),
                  Row(
                    children: [
                      const ShimmerBox(width: 140, height: 17),
                      const Spacer(),
                      ShimmerBox(
                        width: 90,
                        height: 17,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.surface2, height: 1),
                  const SizedBox(height: 10),
                  const ShimmerBox(width: 50, height: 12),
                  const SizedBox(height: AppTheme.xs),
                  const ShimmerBox(width: 160, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
