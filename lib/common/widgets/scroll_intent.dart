import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';

/// Visible portions remain interactive; translation maps hits to the painted bar.
class ScrollLinkedNavigation extends StatelessWidget {
  const ScrollLinkedNavigation({
    super.key,
    required this.offset,
    required this.child,
    this.animate = true,
  });
  final double offset;
  final Widget child;
  final bool animate;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: offset, end: offset),
    duration: animate && !MediaQuery.disableAnimationsOf(context)
        ? ScrollVisibility.duration
        : Duration.zero,
    curve: ScrollVisibility.curve,
    child: child,
    builder: (context, position, child) => IgnorePointer(
      ignoring: position >= 1,
      child: ExcludeSemantics(
        excluding: position >= 1,
        child: FractionalTranslation(
          translation: Offset(0, position),
          child: child,
        ),
      ),
    ),
  );
}

/// Shared hysteresis for scroll-linked controls. Positive deltas move down.
class ScrollVisibility {
  static const hideDistance = 24.0;
  static const showDistance = 48.0;
  static const duration = Duration(milliseconds: 180);
  static const curve = Curves.easeInOut;

  double _distance = 0;
  ScrollDirection? _accepted;
  bool _userScrolling = false;

  void reset() {
    _distance = 0;
    _accepted = null;
    _userScrolling = false;
  }

  ScrollDirection? updateDelta(double delta) {
    if (delta == 0) return null;
    if (_distance.sign != delta.sign) {
      _distance = 0;
      _accepted = null;
    }
    _distance += delta;
    if (_distance >= hideDistance) _accepted = .reverse;
    if (_distance <= -showDistance) _accepted = .forward;
    return _accepted;
  }

  ScrollDirection? update(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return null;
    if (notification is ScrollStartNotification) {
      reset();
      _userScrolling = notification.dragDetails != null;
    } else if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != .idle;
      if (!_userScrolling) reset();
    } else if (notification is ScrollUpdateNotification &&
        (notification.dragDetails != null || _userScrolling)) {
      return updateDelta(notification.scrollDelta!);
    } else if (notification is ScrollEndNotification) {
      reset();
      if (notification.metrics.extentBefore == 0) return .forward;
    }
    return null;
  }
}
