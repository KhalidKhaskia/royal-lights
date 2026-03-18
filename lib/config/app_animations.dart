import 'package:flutter/material.dart';

/// Shared animation durations and curves for a heavier, more deliberate feel.
class AppAnimations {
  AppAnimations._();

  static const Duration durationFast = Duration(milliseconds: 220);
  static const Duration durationNormal = Duration(milliseconds: 380);
  static const Duration durationMedium = Duration(milliseconds: 500);
  static const Duration durationSlow = Duration(milliseconds: 650);

  /// Heavier curve: more deceleration at the end (weight settling).
  static const Curve curveDefault = Curves.easeOutQuart;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveGentle = Curves.easeInOutCubic;
}

/// Fades in a single child with optional slide and subtle scale for a heavier feel.
class AnimatedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final bool slideUp;
  /// Slight scale-up from this value to 1 (e.g. 0.96) for a weighted landing.
  final double scaleBegin;

  const AnimatedFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimations.durationMedium,
    this.curve = AppAnimations.curveDefault,
    this.slideUp = false,
    this.scaleBegin = 1.0,
  });

  @override
  State<AnimatedFadeIn> createState() => _AnimatedFadeInState();
}

class _AnimatedFadeInState extends State<AnimatedFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: widget.slideUp ? const Offset(0, 24) : Offset.zero,
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(
      begin: widget.scaleBegin,
      end: 1.0,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget result = child!;
        if (widget.slideUp) {
          result = Transform.translate(
            offset: _offset.value,
            child: result,
          );
        }
        if (widget.scaleBegin < 1.0) {
          result = Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: result,
          );
        }
        return Opacity(
          opacity: _opacity.value,
          child: result,
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps a list/grid child with a staggered fade-in (use index for delay).
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final int stepMilliseconds;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stepMilliseconds = 55,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.durationMedium,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.curveDefault,
    );
    final delay = Duration(milliseconds: widget.index * widget.stepMilliseconds);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
