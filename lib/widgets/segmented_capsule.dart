import 'package:material_ui/material_ui.dart';

import '../utils/theme.dart';

/// The app's pill-shaped switch between a few options, one selected.
class SegmentedCapsule extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedCapsule({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final last = options.length - 1;
    const end = Radius.circular(AppTheme.radiusFull);
    // Each option is its own 44 dp tall tap target, with its share of the
    // capsule painted inside it, so the touch area outgrows the capsule.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.indexed.map((record) {
        final (index, option) = record;
        final isSelected = index == selected;
        // Flexible, with the label scaling down, so large text shrinks the
        // pill's options instead of overflowing it.
        return Flexible(
          child: Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(index),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                // Only as wide as its label, however wide the space it is given.
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.horizontal(
                        left: index == 0 ? end : Radius.zero,
                        right: index == last ? end : Radius.zero,
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      index == 0 ? 3 : 0,
                      3,
                      index == last ? 3 : 0,
                      3,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.onAccent
                                : AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
