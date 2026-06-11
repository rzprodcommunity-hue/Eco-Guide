import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global control for spoken audio (text-to-speech) used across the app:
/// POI reading, the chatbot, trail navigation instructions and alerts.
///
/// - Persisted (on/off + selected voice).
/// - Fully OFFLINE: uses the device's built-in TTS engine (no network).
/// - Offers a few named voices (Charlot / Mike / Mohamed). Each one sounds
///   different thanks to a distinct pitch + speech rate and, when the device
///   exposes several voices for the current language, a different one of them.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const String _enabledKey = 'voice_enabled';
  static const String _profileKey = 'voice_profile';

  /// Selectable named voices (ids). Display names come from [displayName].
  static const List<String> profiles = ['charlot', 'mohamed'];

  static String displayName(String id) {
    switch (id) {
      case 'mohamed':
        return 'Mohamed';
      case 'charlot':
      default:
        return 'Charlot';
    }
  }

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// One of [profiles].
  final ValueNotifier<String> profile = ValueNotifier<String>('charlot');

  final FlutterTts _previewTts = FlutterTts();

  bool get isEnabled => enabled.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_enabledKey) ?? true;
    final p = prefs.getString(_profileKey);
    profile.value = profiles.contains(p) ? p! : profiles.first;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setProfile(String id) async {
    if (!profiles.contains(id)) return;
    profile.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, id);
  }

  // ── Per-voice tuning ───────────────────────────────────────────────────────
  double get _pitch {
    switch (profile.value) {
      case 'mohamed':
        return 1.0; // neutral
      case 'charlot':
      default:
        return 1.25; // brighter / higher
    }
  }

  // Speech rate — kept fast so the spoken response feels snappy.
  double get _rate {
    switch (profile.value) {
      case 'mohamed':
        return 0.66;
      case 'charlot':
      default:
        return 0.70;
    }
  }

  /// Which device voice (of those available for the current language) to use,
  /// so the two names map to different actual voices when possible.
  int get _voiceIndex {
    switch (profile.value) {
      case 'mohamed':
        return 1;
      case 'charlot':
      default:
        return 0;
    }
  }

  /// Maps an app locale code (fr/en/ar) to a TTS language tag.
  static String tag(String localeCode) {
    switch (localeCode) {
      case 'en':
        return 'en-US';
      case 'ar':
        return 'ar-SA';
      case 'fr':
      default:
        return 'fr-FR';
    }
  }

  /// Applies language + the selected voice (rate, pitch, and a distinct device
  /// voice when available) to [tts] before it speaks.
  Future<void> configure(FlutterTts tts, {required String langTag}) async {
    try {
      await tts.setLanguage(langTag);
      await tts.setSpeechRate(_rate);
      await tts.setPitch(_pitch);
      await _selectVoice(tts, langTag);
    } catch (_) {
      // Best-effort; pitch + rate already differentiate the voices.
    }
  }

  // Cache the available voices per language so we don't query the TTS engine
  // (a relatively slow call) before every utterance — keeps speech snappy.
  final Map<String, List<Map>> _localeVoiceCache = {};

  Future<List<Map>> _localeVoices(FlutterTts tts, String lang) async {
    final cached = _localeVoiceCache[lang];
    if (cached != null) return cached;
    final result = <Map>[];
    try {
      final voices = await tts.getVoices;
      if (voices is List) {
        for (final raw in voices) {
          if (raw is! Map) continue;
          final loc = (raw['locale'] ?? '').toString().toLowerCase();
          if (loc.startsWith(lang)) result.add(raw);
        }
      }
    } catch (_) {
      // Voice list unavailable on this device — pitch + rate still apply.
    }
    _localeVoiceCache[lang] = result;
    return result;
  }

  Future<void> _selectVoice(FlutterTts tts, String langTag) async {
    final lang = langTag.split('-').first.toLowerCase();
    final localeVoices = await _localeVoices(tts, lang);
    if (localeVoices.isEmpty) return;
    final pick = localeVoices[_voiceIndex % localeVoices.length];
    try {
      await tts.setVoice({
        'name': (pick['name'] ?? '').toString(),
        'locale': (pick['locale'] ?? langTag).toString(),
      });
    } catch (_) {
      // Best-effort; pitch + rate already differentiate the voices.
    }
  }

  /// Speaks a short sample so the user can hear the selected voice while
  /// choosing it in the settings screen.
  Future<void> preview(String localeCode) async {
    final langTag = tag(localeCode);
    await configure(_previewTts, langTag: langTag);
    final sample = localeCode == 'ar'
        ? 'مرحبًا، أنا ${displayName(profile.value)}.'
        : localeCode == 'en'
            ? 'Hello, I am ${displayName(profile.value)}.'
            : 'Bonjour, je suis ${displayName(profile.value)}.';
    try {
      await _previewTts.stop();
      await _previewTts.speak(sample);
    } catch (_) {}
  }
}
