import 'package:flutter/material.dart';

/// A stable visual signature per source, restricted to the ocean/teal/purple
/// spectrum so that cards never become bright red or alarm-like.
abstract final class ChannelAccent {
  static const _hues = <double>[
    188, 201, 215, 230, 245, 261, 278, 174, 193, 224, 252, 282,
  ];

  static Color forSource(String channelUsername) {
    var hash = 0x811C9DC5;
    for (final unit in channelUsername.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final hue = _hues[hash % _hues.length];
    final lightness = ((hash >> 8) & 1) == 0 ? 0.37 : 0.42;
    return HSLColor.fromAHSL(1, hue, 0.66, lightness).toColor();
  }

  static Color tint(String channelUsername) =>
      Color.lerp(Colors.white, forSource(channelUsername), 0.065)!;
}
