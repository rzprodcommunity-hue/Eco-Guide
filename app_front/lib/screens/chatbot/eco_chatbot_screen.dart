import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../services/voice_service.dart';
import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../../providers/weather_provider.dart';
import '../map/navigation_sos_screen.dart';
import '../poi/poi_detail_screen.dart';
import '../services/local_service_detail_screen.dart';
import '../sos/sos_button.dart';
import '../trails/trail_detail_screen.dart';

/// Local chatbot — uses providers for trail/POI/service data + weather.
/// Pattern-matches FR/EN/AR keywords and replies via text + TTS voice.
/// Includes SOS quick actions, navigation, location sharing.
class EcoChatbotScreen extends StatefulWidget {
  final LatLng? userPosition;

  const EcoChatbotScreen({super.key, this.userPosition});

  @override
  State<EcoChatbotScreen> createState() => _EcoChatbotScreenState();
}

class _EcoChatbotScreenState extends State<EcoChatbotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final List<_ChatMessage> _messages = [];
  bool _voiceOn = true;
  bool _thinking = false;
  bool _hasText = false;
  late AnimationController _avatarPulse;

  // Quick suggestion buttons (with icon) — localized at build time.
  List<_Suggestion> _localizedSuggestions() => [
        _Suggestion(_tr('Sentiers', 'Trails', 'المسارات'), Icons.hiking,
            _tr('Sentiers proches', 'Nearby trails', 'مسارات قريبة')),
        _Suggestion(_tr('Météo', 'Weather', 'الطقس'), Icons.wb_sunny_outlined,
            _tr('Météo', 'Weather', 'طقس')),
        _Suggestion(_tr('POI', 'POI', 'نقاط'), Icons.place_outlined,
            _tr('Points d\'intérêt', 'Points of interest', 'نقاط الاهتمام')),
        _Suggestion(
            _tr('Services', 'Services', 'خدمات'),
            Icons.storefront_outlined,
            _tr('Services à proximité', 'Nearby services', 'خدمات قريبة')),
        _Suggestion(
            _tr('Urgence', 'Emergency', 'طوارئ'),
            Icons.warning_amber_rounded,
            _tr('SOS urgence', 'SOS emergency', 'استغاثة طوارئ'),
            isSos: true),
        _Suggestion(
            _tr('Conseils', 'Tips', 'نصائح'),
            Icons.tips_and_updates_outlined,
            _tr('Conseils randonnée', 'Hiking tips', 'نصائح المشي')),
        _Suggestion(
            _tr('Premiers soins', 'First aid', 'إسعافات'),
            Icons.medical_services_outlined,
            _tr('Premiers soins', 'First aid', 'إسعافات أولية')),
        _Suggestion(
            _tr('Faune', 'Wildlife', 'حيوانات'),
            Icons.pets,
            _tr('Quels animaux dans la région ?',
                'What animals are in the area?', 'ما الحيوانات في المنطقة؟')),
      ];

  @override
  void initState() {
    super.initState();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // Rebuild the send button as the user types (enabled/disabled state).
    _input.addListener(_onInputChanged);
    // TTS rate/pitch/voice are applied per-utterance by VoiceService.configure().
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _addBot(
        _tr(
          'Salut ! 👋 Je suis EcoBot, ton assistant randonnée. '
              'Je connais les sentiers, la météo, les services, et je peux '
              'déclencher une alerte SOS pour toi.',
          'Hi! 👋 I\'m EcoBot, your hiking assistant. I know the trails, '
              'the weather, local services, and I can trigger an SOS alert '
              'for you.',
          'مرحبًا! 👋 أنا EcoBot، مساعدك في المشي. أعرف المسارات والطقس '
              'والخدمات، ويمكنني إطلاق تنبيه استغاثة من أجلك.',
        ),
      );
    });
  }

  void _onInputChanged() {
    final hasText = _input.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _avatarPulse.dispose();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Send / answer logic ─────────────────────────────────────────────

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _input.clear();
      _thinking = true;
    });
    _scrollDown();

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final reply = _generateReply(text);
    setState(() {
      _thinking = false;
      _messages.add(reply);
    });
    _scrollDown();

    if (_voiceOn && reply.text.isNotEmpty) await _speak(reply.text);
  }

  _ChatMessage _generateReply(String userText) {
    final q = userText.toLowerCase();
    final pos = widget.userPosition ??
        LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);

    if (_match(q, ['salut', 'bonjour', 'hello', 'hi', 'مرحبا', 'سلام'])) {
      return _ChatMessage(
        text: _tr('Salut ! Comment puis-je t\'aider ?', 'Hi! How can I help you?',
            'مرحبًا! كيف يمكنني مساعدتك؟'),
        isUser: false,
      );
    }

    // SOS — show critical action buttons
    if (_match(q, [
      'sos',
      'urgence',
      'aide',
      'danger',
      'help',
      'emergency',
      'طوارئ',
      'مساعدة',
      'blessé',
      'blesse',
      'perdu',
    ])) {
      return _ChatMessage(
        text: _tr('Mode urgence activé. Choisis une action :',
            'Emergency mode on. Choose an action:',
            'تم تفعيل وضع الطوارئ. اختر إجراءً:'),
        isUser: false,
        actions: [
          _ChatAction(
            label: _tr('Ouvrir SOS', 'Open SOS', 'فتح الاستغاثة'),
            icon: Icons.sos,
            color: const Color(0xFFE53935),
            onTap: _openSosScreen,
          ),
          _ChatAction(
            label: _tr('Appeler 198', 'Call 198', 'الاتصال بـ 198'),
            icon: Icons.call,
            color: const Color(0xFFE53935),
            onTap: () => _call('198'),
          ),
          _ChatAction(
            label: _tr('Appeler 190', 'Call 190', 'الاتصال بـ 190'),
            icon: Icons.medical_services,
            color: const Color(0xFFE53935),
            onTap: () => _call('190'),
          ),
          _ChatAction(
            label: _tr('Partager position', 'Share location', 'مشاركة الموقع'),
            icon: Icons.share_location,
            color: const Color(0xFF1E88E5),
            onTap: _shareLocation,
          ),
        ],
      );
    }

    if (_match(q, [
      'premier',
      'soin',
      'first aid',
      'blessure',
      'plaie',
      'saigne',
      'إسعاف',
      'إسعافات',
    ])) {
      return _ChatMessage(
        text: _tr(
          'Gestes essentiels :\n'
              '• Mettre la victime en sécurité\n'
              '• Évaluer conscience et respiration\n'
              '• Saignement : compression directe avec tissu propre\n'
              '• Entorse : RICE (Repos, Glace, Compression, Élévation)\n'
              '• Insolation : ombre + eau + ventiler\n'
              '• Appeler les secours (190/198)',
          'Essential steps:\n'
              '• Move the victim to safety\n'
              '• Check consciousness and breathing\n'
              '• Bleeding: direct pressure with a clean cloth\n'
              '• Sprain: RICE (Rest, Ice, Compression, Elevation)\n'
              '• Heatstroke: shade + water + ventilate\n'
              '• Call emergency services (190/198)',
          'إجراءات أساسية:\n'
              '• ضع المصاب في مكان آمن\n'
              '• تحقق من الوعي والتنفس\n'
              '• النزيف: ضغط مباشر بقطعة قماش نظيفة\n'
              '• الالتواء: راحة وثلج وضغط ورفع\n'
              '• ضربة الشمس: ظل + ماء + تهوية\n'
              '• اتصل بالإسعاف (190/198)',
        ),
        isUser: false,
        actions: [
          _ChatAction(
            label: _tr('Appeler SAMU 190', 'Call ambulance 190',
                'اتصل بالإسعاف 190'),
            icon: Icons.medical_services,
            color: const Color(0xFFE53935),
            onTap: () => _call('190'),
          ),
        ],
      );
    }

    if (_match(q, ['meteo', 'météo', 'temps', 'weather', 'vent', 'pluie', 'طقس'])) {
      return _ChatMessage(text: _weatherReply(), isUser: false);
    }

    if (_match(q, ['sentier', 'trail', 'randonnée', 'randonnee', 'hike', 'مسار'])) {
      return _trailsReply(pos);
    }

    if (_match(q, [
      'poi',
      'point',
      'intérêt',
      'interet',
      'nature',
      'flore',
      'fleur',
      'نقاط',
      'اهتمام',
    ])) {
      return _poisReply(pos);
    }

    if (_match(q, [
      'service',
      'annuaire',
      'guide',
      'restaurant',
      'hôtel',
      'hotel',
      'café',
      'cafe',
      'commerce',
      'خدمة',
      'خدمات',
    ])) {
      return _servicesReply(pos);
    }

    if (_match(q,
        ['faune', 'animal', 'animaux', 'wildlife', 'oiseau', 'حيوان', 'حيوانات'])) {
      return _ChatMessage(
        text: _tr(
          'Faune typique du nord-ouest tunisien :\n'
              '🦌 Cerf de Berbérie (Kroumirie)\n'
              '🐗 Sanglier (forêts)\n'
              '🐎 Lièvre du Cap\n'
              '🦅 Aigle royal, faucon pèlerin\n'
              '🦊 Renard roux, mangouste\n'
              'Reste discret et garde tes distances. Ne donne pas à manger.',
          'Typical wildlife of north-west Tunisia:\n'
              '🦌 Barbary deer (Kroumirie)\n'
              '🐗 Wild boar (forests)\n'
              '🐎 Cape hare\n'
              '🦅 Golden eagle, peregrine falcon\n'
              '🦊 Red fox, mongoose\n'
              'Stay discreet and keep your distance. Do not feed them.',
          'الحيوانات النموذجية في شمال غرب تونس:\n'
              '🦌 أيل بربري (الخمير)\n'
              '🐗 خنزير بري (الغابات)\n'
              '🐎 أرنب الرأس\n'
              '🦅 العقاب الذهبي، صقر شاهين\n'
              '🦊 الثعلب الأحمر، النمس\n'
              'ابقَ بعيدًا وحافظ على المسافة. لا تطعمها.',
        ),
        isUser: false,
      );
    }

    if (_match(q, ['flore', 'plante', 'arbre', 'fleur', 'نبات', 'شجرة'])) {
      return _ChatMessage(
        text: _tr(
          'Flore caractéristique :\n'
              '🌲 Chêne-liège (Quercus suber)\n'
              '🌳 Chêne zéen, pin maritime\n'
              '🌿 Bruyère arborescente, ciste\n'
              '🌼 Anémone, asphodèle (printemps)\n'
              'Cueillette interdite dans les zones protégées.',
          'Characteristic flora:\n'
              '🌲 Cork oak (Quercus suber)\n'
              '🌳 Zeen oak, maritime pine\n'
              '🌿 Tree heath, rockrose\n'
              '🌼 Anemone, asphodel (spring)\n'
              'Picking is forbidden in protected areas.',
          'النباتات المميزة:\n'
              '🌲 بلوط الفلين\n'
              '🌳 بلوط الزان، الصنوبر البحري\n'
              '🌿 الخلنج الشجري، اللاذن\n'
              '🌼 شقائق النعمان، الأسفوديل (الربيع)\n'
              'القطف ممنوع في المناطق المحمية.',
        ),
        isUser: false,
      );
    }

    if (_match(q, [
      'conseil',
      'tip',
      'preparer',
      'préparer',
      'partir',
      'equip',
      'équip',
      'نصيحة',
      'نصائح',
    ])) {
      return _ChatMessage(text: _tipsReply(), isUser: false);
    }

    if (_match(q, ['eau', 'hydrate', 'boire', 'ماء', 'شرب'])) {
      return _ChatMessage(
        text: _tr(
          'Hydratation :\n'
              '• Minimum 1.5L pour 4h de marche\n'
              '• Par forte chaleur : +0.5L par heure\n'
              '• Bois avant d\'avoir soif\n'
              '• Ajoute une pincée de sel par litre si transpiration intense',
          'Hydration:\n'
              '• At least 1.5L for 4h of walking\n'
              '• In hot weather: +0.5L per hour\n'
              '• Drink before you feel thirsty\n'
              '• Add a pinch of salt per liter if sweating heavily',
          'الترطيب:\n'
              '• 1.5 لتر على الأقل لكل 4 ساعات مشي\n'
              '• في الحر الشديد: +0.5 لتر في الساعة\n'
              '• اشرب قبل الشعور بالعطش\n'
              '• أضف رشة ملح لكل لتر عند التعرق الشديد',
        ),
        isUser: false,
      );
    }

    if (_match(q, ['batterie', 'battery', 'téléphone', 'بطارية', 'هاتف'])) {
      return _ChatMessage(
        text: _tr(
          'Économiser la batterie :\n'
              '• Active le mode économie\n'
              '• Désactive Bluetooth/WiFi inutiles\n'
              '• Verrouille l\'écran entre les consultations\n'
              '• Mode avion + GPS quand seul le GPS suffit',
          'Save battery:\n'
              '• Turn on power saving mode\n'
              '• Disable unused Bluetooth/WiFi\n'
              '• Lock the screen between checks\n'
              '• Airplane mode + GPS when only GPS is needed',
          'توفير البطارية:\n'
              '• فعّل وضع توفير الطاقة\n'
              '• أوقف البلوتوث/الواي فاي غير المستخدم\n'
              '• اقفل الشاشة بين عمليات التحقق\n'
              '• وضع الطيران + GPS عند الحاجة إلى GPS فقط',
        ),
        isUser: false,
      );
    }

    if (_match(q,
        ['où', 'ou suis', 'where', 'position', 'localisation', 'gps', 'موقع', 'أين'])) {
      final coords = '${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';
      return _ChatMessage(
        text: _tr('Tu es à : $coords', 'You are at: $coords', 'أنت في: $coords'),
        isUser: false,
        actions: [
          _ChatAction(
            label:
                _tr('Copier coordonnées', 'Copy coordinates', 'نسخ الإحداثيات'),
            icon: Icons.copy,
            color: const Color(0xFF0E7A23),
            onTap: () => _copy('${pos.latitude}, ${pos.longitude}'),
          ),
          _ChatAction(
            label: _tr('Partager', 'Share', 'مشاركة'),
            icon: Icons.share_location,
            color: const Color(0xFF1E88E5),
            onTap: _shareLocation,
          ),
        ],
      );
    }

    if (_match(q, ['merci', 'thanks', 'thank you', 'شكرا'])) {
      return _ChatMessage(
        text: _tr('Avec plaisir ! 🌿 Bonne randonnée.',
            'You\'re welcome! 🌿 Enjoy your hike.',
            'على الرحب والسعة! 🌿 رحلة موفقة.'),
        isUser: false,
      );
    }

    // Fallback
    return _ChatMessage(
      text: _tr('Hmm, je n\'ai pas compris. Voici ce que je sais faire :',
          'Hmm, I didn\'t get that. Here\'s what I can do:',
          'لم أفهم تمامًا. إليك ما يمكنني فعله:'),
      isUser: false,
      actions: [
        _ChatAction(
          label: _tr('Sentiers', 'Trails', 'المسارات'),
          icon: Icons.hiking,
          color: const Color(0xFF0E7A23),
          onTap: () => _send(_tr('Sentiers proches', 'Nearby trails',
              'مسارات قريبة')),
        ),
        _ChatAction(
          label: _tr('Météo', 'Weather', 'الطقس'),
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFFFA000),
          onTap: () => _send(_tr('Météo', 'Weather', 'طقس')),
        ),
        _ChatAction(
          label: _tr('SOS', 'SOS', 'استغاثة'),
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFE53935),
          onTap: () => _send(_tr('SOS urgence', 'SOS emergency',
              'استغاثة طوارئ')),
        ),
      ],
    );
  }

  bool _match(String q, List<String> keywords) {
    for (final k in keywords) {
      if (q.contains(k)) return true;
    }
    return false;
  }

  // ── i18n ─────────────────────────────────────────────────────────────
  String get _code {
    try {
      return context.read<LocaleProvider>().locale.languageCode;
    } catch (_) {
      return 'fr';
    }
  }

  /// Picks the string matching the active app language (fr / en / ar).
  String _tr(String fr, String en, String ar) {
    switch (_code) {
      case 'en':
        return en;
      case 'ar':
        return ar;
      default:
        return fr;
    }
  }

  // ── Reply builders ───────────────────────────────────────────────────

  String _weatherReply() {
    final w = context.read<WeatherProvider>().currentWeather;
    if (w == null) {
      return _tr('Pas de données météo. Vérifie ta connexion internet.',
          'No weather data. Check your internet connection.',
          'لا توجد بيانات طقس. تحقق من اتصالك بالإنترنت.');
    }
    final advice = _weatherAdvice(w.temperature);
    return _tr(
      '${w.temperatureText}, vent ${w.windText}, '
          'humidité ${w.humidityText}.\n$advice',
      '${w.temperatureText}, wind ${w.windText}, '
          'humidity ${w.humidityText}.\n$advice',
      '${w.temperatureText}، الرياح ${w.windText}، '
          'الرطوبة ${w.humidityText}.\n$advice',
    );
  }

  String _weatherAdvice(double? tempC) {
    if (tempC == null) return '';
    if (tempC < 5) {
      return _tr('❄️ Il fait froid, prévois plusieurs couches.',
          '❄️ It\'s cold, bring several layers.', '❄️ الجو بارد، خذ عدة طبقات.');
    }
    if (tempC < 15) {
      return _tr('🧥 Frais — une veste est conseillée.',
          '🧥 Cool — a jacket is recommended.', '🧥 الجو منعش — يُنصح بسترة.');
    }
    if (tempC < 25) {
      return _tr('✨ Conditions idéales pour randonner.',
          '✨ Ideal conditions for hiking.', '✨ ظروف مثالية للمشي.');
    }
    if (tempC < 32) {
      return _tr('☀️ Chaud — hydrate-toi régulièrement.',
          '☀️ Hot — drink regularly.', '☀️ حار — اشرب الماء بانتظام.');
    }
    return _tr('🔥 Très chaud — évite 11h-16h.',
        '🔥 Very hot — avoid 11am-4pm.', '🔥 حار جدًا — تجنّب من 11ص إلى 4م.');
  }

  _ChatMessage _trailsReply(LatLng pos) {
    final trails = context.read<TrailProvider>().trails;
    if (trails.isEmpty) {
      return _ChatMessage(
        text: _tr('Aucun sentier disponible. Rafraîchis l\'application.',
            'No trail available. Refresh the app.',
            'لا يوجد مسار متاح. حدّث التطبيق.'),
        isUser: false,
      );
    }
    const d = Distance();
    final ranked = trails
        .where((t) => t.startLatitude != null && t.startLongitude != null)
        .map((t) => MapEntry(
              t,
              d.as(LengthUnit.Kilometer, pos,
                  LatLng(t.startLatitude!, t.startLongitude!)),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final top = ranked.take(3).toList();
    final actions = top.map((e) {
      return _ChatAction(
        label: '${e.key.name} (${e.value.toStringAsFixed(1)} km)',
        icon: Icons.terrain,
        color: const Color(0xFF0E7A23),
        onTap: () => _openTrail(e.key),
      );
    }).toList();

    return _ChatMessage(
      text: _tr('Voici les sentiers les plus proches :',
          'Here are the nearest trails:', 'إليك أقرب المسارات:'),
      isUser: false,
      actions: actions,
    );
  }

  _ChatMessage _poisReply(LatLng pos) {
    final pois = context.read<PoiProvider>().pois;
    if (pois.isEmpty) {
      return _ChatMessage(
        text: _tr('Aucun point d\'intérêt disponible.',
            'No point of interest available.', 'لا توجد نقطة اهتمام متاحة.'),
        isUser: false,
      );
    }
    const d = Distance();
    final ranked = pois
        .map<MapEntry<Poi, double>>((p) => MapEntry(
              p,
              d.as(LengthUnit.Kilometer, pos,
                  LatLng(p.latitude, p.longitude)),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final top = ranked.take(3).toList();
    final actions = top.map((e) {
      return _ChatAction(
        label: '${e.key.name} (${e.value.toStringAsFixed(1)} km)',
        icon: Icons.place,
        color: const Color(0xFF8E44AD),
        onTap: () => _openPoi(e.key),
      );
    }).toList();

    return _ChatMessage(
      text: _tr('Points d\'intérêt à proximité :', 'Points of interest nearby:',
          'نقاط الاهتمام القريبة:'),
      isUser: false,
      actions: actions,
    );
  }

  _ChatMessage _servicesReply(LatLng pos) {
    final services = context.read<LocalServiceProvider>().services;
    if (services.isEmpty) {
      return _ChatMessage(
        text: _tr('Aucun service disponible.', 'No service available.',
            'لا توجد خدمة متاحة.'),
        isUser: false,
      );
    }
    const d = Distance();
    final ranked = services
        .where((s) => s.latitude != null && s.longitude != null)
        .map<MapEntry<LocalService, double>>((s) => MapEntry(
              s,
              d.as(LengthUnit.Kilometer, pos,
                  LatLng(s.latitude!, s.longitude!)),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (ranked.isEmpty) {
      return _ChatMessage(
        text: _tr('Pas de services géolocalisés.', 'No geolocated services.',
            'لا توجد خدمات محددة الموقع.'),
        isUser: false,
      );
    }
    final top = ranked.take(3).toList();
    final actions = top.map((e) {
      return _ChatAction(
        label: '${e.key.name} (${e.value.toStringAsFixed(1)} km)',
        icon: Icons.storefront,
        color: const Color(0xFF1E9A35),
        onTap: () => _openService(e.key),
      );
    }).toList();

    return _ChatMessage(
      text: _tr('Services à proximité :', 'Nearby services:', 'الخدمات القريبة:'),
      isUser: false,
      actions: actions,
    );
  }

  String _tipsReply() {
    return _tr(
      'Checklist randonnée :\n'
          '🚶 Préviens quelqu\'un de ton itinéraire\n'
          '💧 Eau : 1.5L mini pour 4h\n'
          '👟 Chaussures adaptées + crème solaire\n'
          '☁️ Vérifie la météo avant de partir\n'
          '🔋 Téléphone chargé (mode économie)\n'
          '🍎 Encas énergétique (fruits secs)\n'
          '🆘 Connais l\'emplacement du bouton SOS',
      'Hiking checklist:\n'
          '🚶 Tell someone your route\n'
          '💧 Water: at least 1.5L for 4h\n'
          '👟 Proper shoes + sunscreen\n'
          '☁️ Check the weather before leaving\n'
          '🔋 Phone charged (power saving)\n'
          '🍎 Energy snack (dried fruit)\n'
          '🆘 Know where the SOS button is',
      'قائمة المشي:\n'
          '🚶 أخبر شخصًا بمسارك\n'
          '💧 الماء: 1.5 لتر على الأقل لكل 4 ساعات\n'
          '👟 أحذية مناسبة + واقٍ من الشمس\n'
          '☁️ تحقق من الطقس قبل الانطلاق\n'
          '🔋 هاتف مشحون (وضع التوفير)\n'
          '🍎 وجبة طاقة (فواكه مجففة)\n'
          '🆘 اعرف مكان زر الاستغاثة',
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast(_tr('Impossible de lancer l\'appel.', 'Unable to start the call.',
          'تعذّر بدء المكالمة.'));
    }
  }

  Future<void> _shareLocation() async {
    final pos = widget.userPosition;
    if (pos == null) {
      _toast(_tr('Position GPS non disponible.', 'GPS location unavailable.',
          'موقع GPS غير متاح.'));
      return;
    }
    final url =
        'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    final body =
        'Ma position actuelle : $url\n(${pos.latitude.toStringAsFixed(5)}, '
        '${pos.longitude.toStringAsFixed(5)})';
    final smsUri = Uri(
      scheme: 'sms',
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      await Clipboard.setData(ClipboardData(text: body));
      _toast(_tr('Position copiée dans le presse-papier.',
          'Location copied to clipboard.', 'تم نسخ الموقع إلى الحافظة.'));
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(_tr('Copié.', 'Copied.', 'تم النسخ.'));
  }

  void _openSosScreen() {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SosScreen()),
    );
  }

  void _openTrail(Trail trail) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: trail)),
    );
  }

  void _openPoi(Poi poi) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: poi)),
    );
  }

  void _openService(LocalService service) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalServiceDetailScreen(
          serviceId: service.id,
          fallbackService: service,
        ),
      ),
    );
  }

  // ignore: unused_element
  void _navigateTo(LatLng dest, String label) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationSosScreen(
          destination: dest,
          destinationLabel: label,
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── TTS ─────────────────────────────────────────────────────────────

  Future<void> _speak(String text) async {
    if (!VoiceService.instance.isEnabled) return;
    final code = context.read<LocaleProvider>().locale.languageCode;
    await VoiceService.instance.configure(_tts, langTag: VoiceService.tag(code));
    await _tts.stop();
    await _tts.speak(text);
  }

  void _toggleVoice() {
    setState(() => _voiceOn = !_voiceOn);
    if (!_voiceOn) _tts.stop();
  }

  void _addBot(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollDown();
    if (_voiceOn) _speak(text);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sheetController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header — gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                    child: Row(
                      children: [
                        // Animated avatar
                        AnimatedBuilder(
                          animation: _avatarPulse,
                          builder: (_, _) => Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(
                                      alpha: 0.5 - _avatarPulse.value * 0.4),
                                  blurRadius:
                                      8 + _avatarPulse.value * 12,
                                  spreadRadius: _avatarPulse.value * 4,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/images/bot.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.eco,
                                  color: Color(0xFF0E7A23),
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'EcoBot',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.verified,
                                      color: Colors.white, size: 16),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const _StatusDot(),
                                  const SizedBox(width: 6),
                                  Text(
                                    _tr('En ligne · Assistant local',
                                        'Online · Local assistant',
                                        'متصل · مساعد محلي'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleVoice,
                          icon: Icon(
                            _voiceOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: Colors.white,
                          ),
                          tooltip: _tr('Voix', 'Voice', 'الصوت'),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_thinking && i == _messages.length) {
                    return _buildThinking(isDark);
                  }
                  return _buildBubble(_messages[i], isDark, onSurface);
                },
              ),
            ),
            // Suggestion grid (only when conversation just started)
            if (_messages.length <= 1) _buildSuggestions(),
            // Input bar — animated padding lifts it above the on-screen keyboard
            AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: _tr('Pose ta question...',
                                'Ask your question...', 'اطرح سؤالك...'),
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.withValues(alpha: 0.10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.message_outlined,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send button — highlighted when there is text to send
                      Material(
                        shape: const CircleBorder(),
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: _hasText
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF22B53A),
                                      Color(0xFF0E7A23),
                                    ],
                                  )
                                : null,
                            color: _hasText
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _send(),
                            child: const SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _localizedSuggestions();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = suggestions[i];
            final isSos = s.isSos;
            return InkWell(
              onTap: () => _send(s.query),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 78,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSos
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFF6B60), Color(0xFFE53935)],
                        )
                      : null,
                  color: isSos
                      ? null
                      : const Color(0xFF22B53A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSos
                        ? Colors.transparent
                        : const Color(0xFF22B53A).withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s.icon,
                      size: 22,
                      color: isSos
                          ? Colors.white
                          : const Color(0xFF0E7A23),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSos
                            ? Colors.white
                            : const Color(0xFF0E7A23),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBubble(
    _ChatMessage m,
    bool isDark,
    Color onSurface,
  ) {
    final isUser = m.isUser;
    final bg = isUser
        ? const Color(0xFF0E7A23)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade200);
    final fg = isUser ? Colors.white : onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        const AssetImage('assets/images/bot.png'),
                    onBackgroundImageError: (_, _) {},
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF22B53A),
                              Color(0xFF0E7A23),
                            ],
                          )
                        : null,
                    color: isUser ? null : bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Action chips below message
          if (m.actions != null && m.actions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32, right: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: m.actions!.map(_buildActionChip).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip(_ChatAction a) {
    return InkWell(
      onTap: a.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: a.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: a.color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 14, color: a.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                a.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: a.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinking(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white,
              backgroundImage: const AssetImage('assets/images/bot.png'),
              onBackgroundImageError: (_, _) {},
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const SizedBox(
              width: 32,
              height: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(delay: 0),
                  SizedBox(width: 4),
                  _Dot(delay: 200),
                  SizedBox(width: 4),
                  _Dot(delay: 400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Models ──────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<_ChatAction>? actions;
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.actions,
  });
}

class _ChatAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ChatAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _Suggestion {
  final String label;
  final IconData icon;
  final String query;
  final bool isSos;
  const _Suggestion(this.label, this.icon, this.query, {this.isSos = false});
}

class _StatusDot extends StatefulWidget {
  const _StatusDot();

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.lightGreenAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.lightGreenAccent,
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: const SizedBox(
        width: 6,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF0E7A23),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
