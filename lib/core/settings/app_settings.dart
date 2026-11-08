import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();
  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool showImages = true;
  bool compactCards = true;
  bool dataSaver = false;
  double newsTextScale = 1.0;

  Future<void> load() async {
    showImages = await _prefs.getBool('display_images') ?? true;
    compactCards = await _prefs.getBool('compact_cards') ?? true;
    dataSaver = await _prefs.getBool('data_saver') ?? false;
    newsTextScale = (await _prefs.getDouble('news_text_scale') ?? 1.0).clamp(0.85, 1.35).toDouble();
    notifyListeners();
  }
  Future<void> setImages(bool value) async {
    showImages = value; notifyListeners();
    await _prefs.setBool('display_images', value);
  }
  Future<void> setCompact(bool value) async {
    compactCards = value; notifyListeners();
    await _prefs.setBool('compact_cards', value);
  }
  Future<void> setDataSaver(bool value) async {
    dataSaver = value; notifyListeners();
    await _prefs.setBool('data_saver', value);
  }
  Future<void> setTextScale(double value) async {
    newsTextScale = value.clamp(0.85, 1.35).toDouble(); notifyListeners();
    await _prefs.setDouble('news_text_scale', newsTextScale);
  }
  Future<void> reset() async {
    showImages = true; compactCards = true; dataSaver = false; newsTextScale = 1.0;
    notifyListeners();
    await Future.wait([
      _prefs.remove('display_images'),
      _prefs.remove('compact_cards'),
      _prefs.remove('data_saver'),
      _prefs.remove('news_text_scale'),
    ]);
  }
}
