import 'package:flutter/material.dart';

/// Stable signature across application launches, including private channels.
/// Colors are visual aids, not category labels inferred from news content.
abstract final class ChannelAccent {
  static Color forSource(String channelUsername) {
    var hash = 0x811C9DC5;
    for (final unit in channelUsername.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.68, 0.39).toColor();
  }

  static Color tint(String channelUsername) =>
      Color.lerp(Colors.white, forSource(channelUsername), 0.065)!;
}
