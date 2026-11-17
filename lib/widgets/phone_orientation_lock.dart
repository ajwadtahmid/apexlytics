import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps a phone upright. The screens are laid out for a tall window: in
/// landscape the pinned headers and the bottom bar leave a thin strip for
/// content. A tablet, which has the room, may still turn, and so may a desktop
/// window.
class PhoneOrientationLock extends StatefulWidget {
  final Widget child;

  /// Below this shortest side, in logical pixels, a screen counts as a phone.
  /// It is the width a phone has either way up, so turning one never flips it
  /// into a tablet.
  static const double phoneShortestSide = 600;

  /// A test seam in place of the platform call.
  final Future<void> Function(List<DeviceOrientation> orientations)? onApply;

  const PhoneOrientationLock({super.key, required this.child, this.onApply});

  @override
  State<PhoneOrientationLock> createState() => _PhoneOrientationLockState();
}

class _PhoneOrientationLockState extends State<PhoneOrientationLock> {
  bool? _locked;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isMobile) return;
    final phone =
        MediaQuery.sizeOf(context).shortestSide <
        PhoneOrientationLock.phoneShortestSide;
    if (phone == _locked) return;
    _locked = phone;
    final apply = widget.onApply ?? SystemChrome.setPreferredOrientations;
    apply(
      phone
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : DeviceOrientation.values,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
