import 'dart:ui';

/// Best-effort 2-letter country code for ITAD's price/currency lookups —
/// ITAD prices (and their currency) are region-specific, so this picks the
/// device's own region automatically instead of a hardcoded market.
/// Falls back to Germany when the platform doesn't expose a usable one.
class RegionDetector {
  static String detect() {
    final code = PlatformDispatcher.instance.locale.countryCode;
    return (code != null && code.length == 2) ? code.toUpperCase() : 'DE';
  }
}
