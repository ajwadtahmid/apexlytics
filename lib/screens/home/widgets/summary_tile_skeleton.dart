import 'package:material_ui/material_ui.dart';
import '../../../utils/theme.dart';
import '../../../widgets/shimmer.dart';
import '../../../widgets/surface_card.dart';

class SummaryTileSkeleton extends StatelessWidget {
  const SummaryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerWrapper(
      child: SurfaceCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.md,
          vertical: AppTheme.summaryTileVerticalPadding,
        ),
        child: Row(
          children: [
            ShimmerBox(
              width: 28,
              height: 28,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            SizedBox(width: AppTheme.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 110, height: 18),
                  SizedBox(height: 2),
                  ShimmerBox(width: 170, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
