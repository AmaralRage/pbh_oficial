import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ProfileSurfaceScope extends InheritedWidget {
  const ProfileSurfaceScope({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;
  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfileSurfaceScope>()
          ?.enabled ??
      false;
  @override
  bool updateShouldNotify(ProfileSurfaceScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Only the decoration is translucent. Content is painted after the backdrop.
class ProfileSurface extends StatelessWidget {
  const ProfileSurface({
    super.key,
    required this.decoration,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.clipBehavior = Clip.none,
    this.blur = true,
  });
  final BoxDecoration decoration;
  final Widget child;
  final EdgeInsetsGeometry? padding, margin;
  final double? width;
  final Clip clipBehavior;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final glass = ProfileSurfaceScope.enabledOf(context);
    final opacity = MediaQuery.highContrastOf(context) ? .96 : .52;
    final gradient = decoration.gradient;
    final fill = glass
        ? decoration.copyWith(
            color: decoration.color?.withValues(alpha: opacity),
            gradient: gradient is LinearGradient
                ? LinearGradient(
                    begin: gradient.begin,
                    end: gradient.end,
                    stops: gradient.stops,
                    colors: gradient.colors
                        .map((c) => c.withValues(alpha: opacity))
                        .toList(),
                  )
                : gradient,
          )
        : decoration;
    Widget card = Container(
      width: width,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: fill,
      child: child,
    );
    if (glass && blur) {
      card = ClipRRect(
        borderRadius: (decoration.borderRadius ?? BorderRadius.zero).resolve(
          Directionality.of(context),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: card,
        ),
      );
    }
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
