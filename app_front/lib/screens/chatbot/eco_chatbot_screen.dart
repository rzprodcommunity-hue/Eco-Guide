import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
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
  late AnimationController _avatarPulse;

  // Quick suggestion buttons (with icon)
  final _suggestions = const [
    _Suggestion('Sentiers', Icons.hiking, 'Sentiers proches'),
    _Suggestion('Météo', Icons.wb_sunny_outlined, 'Météo'),
    _Suggestion('POI', Icons.place_outlined, 'Points d\'intérêt'),
    _Suggestion('Services', Icons.storefront_outlined, 'Services à proximité'),
    _Suggestion('Urgence', Icons.warning_amber_rounded, 'SOS urgence'),
    _Suggestion('Conseils', Icons.tips_and_updates_outlined, 'Conseils randonnée'),
    _Suggestion('Premiers soins', Icons.medical_services_outlined, 'Premiers soins'),
    _Suggestion('Faune', Icons.pets, 'Quels animaux dans la région ?'),
  ];

  @override
  void initState() {
    super.initState();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _addBot(
        'Salut ! 👋 Je suis EcoBot, ton assistant randonnée. '
        'Je connais les sentiers, la météo, les services, et je peux '
        'déclencher une alerte SOS pour toi.',
      );
    });
  }

  @override
  void dispose() {
    _avatarPulse.dispose();
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

    await Future.delayed(const Duration(milliseconds: 400));
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
        text: 'Salut ! Comment puis-je t\'aider ?',
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
        text: 'Mode urgence activé. Choisis une action :',
        isUser: false,
        actions: [
          _ChatAction(
            label: 'Ouvrir SOS',
            icon: Icons.sos,
            color: const Color(0xFFE53935),
            onTap: _openSosScreen,
          ),
          _ChatAction(
            label: 'Appeler 198',
            icon: Icons.call,
            color: const Color(0xFFE53935),
            onTap: () => _call('198'),
          ),
          _ChatAction(
            label: 'Appeler 190',
            icon: Icons.medical_services,
            color: const Color(0xFFE53935),
            onTap: () => _call('190'),
          ),
          _ChatAction(
            label: 'Partager position',
            icon: Icons.share_location,
            color: const Color(0xFF1E88E5),
            onTap: _shareLocation,
          ),
        ],
      );
    }

    if (_match(q, ['premier', 'soin', 'first aid', 'blessure', 'plaie', 'saigne'])) {
      return _ChatMessage(
        text: 'Gestes essentiels :\n'
            '• Mettre la victime en sécurité\n'
            '• Évaluer conscience et respiration\n'
            '• Saignement : compression directe avec tissu propre\n'
            '• Entorse : RICE (Repos, Glace, Compression, Élévation)\n'
            '• Insolation : ombre + eau + ventiler\n'
            '• Appeler les secours (190/198)',
        isUser: false,
        actions: [
          _ChatAction(
            label: 'Appeler SAMU 190',
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
    ])) {
      return _servicesReply(pos);
    }

    if (_match(q, ['faune', 'animal', 'animaux', 'wildlife', 'oiseau'])) {
      return _ChatMessage(
        text: 'Faune typique du nord-ouest tunisien :\n'
            '🦌 Cerf de Berbérie (Kroumirie)\n'
            '🐗 Sanglier (forêts)\n'
            '🐎 Lièvre du Cap\n'
            '🦅 Aigle royal, faucon pèlerin\n'
            '🦊 Renard roux, mangouste\n'
            'Reste discret et garde tes distances. Ne donne pas à manger.',
        isUser: false,
      );
    }

    if (_match(q, ['flore', 'plante', 'arbre', 'fleur'])) {
      return _ChatMessage(
        text: 'Flore caractéristique :\n'
            '🌲 Chêne-liège (Quercus suber)\n'
            '🌳 Chêne zéen, pin maritime\n'
            '🌿 Bruyère arborescente, ciste\n'
            '🌼 Anémone, asphodèle (printemps)\n'
            'Cueillette interdite dans les zones protégées.',
        isUser: false,
      );
    }

    if (_match(q, ['conseil', 'tip', 'preparer', 'préparer', 'partir', 'equip', 'équip'])) {
      return _ChatMessage(text: _tipsReply(), isUser: false);
    }

    if (_match(q, ['eau', 'hydrate', 'boire'])) {
      return _ChatMessage(
        text: 'Hydratation :\n'
            '• Minimum 1.5L pour 4h de marche\n'
            '• Par forte chaleur : +0.5L par heure\n'
            '• Bois avant d\'avoir soif\n'
            '• Ajoute une pincée de sel par litre si transpiration intense',
        isUser: false,
      );
    }

    if (_match(q, ['batterie', 'battery', 'téléphone'])) {
      return _ChatMessage(
        text: 'Économiser la batterie :\n'
            '• Active le mode économie\n'
            '• Désactive Bluetooth/WiFi inutiles\n'
            '• Verrouille l\'écran entre les consultations\n'
            '• Mode avion + GPS quand seul le GPS suffit',
        isUser: false,
      );
    }

    if (_match(q, ['où', 'ou suis', 'where', 'position', 'localisation', 'gps'])) {
      return _ChatMessage(
        text: 'Tu es à : ${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}',
        isUser: false,
        actions: [
          _ChatAction(
            label: 'Copier coordonnées',
            icon: Icons.copy,
            color: const Color(0xFF0E7A23),
            onTap: () => _copy('${pos.latitude}, ${pos.longitude}'),
          ),
          _ChatAction(
            label: 'Partager',
            icon: Icons.share_location,
            color: const Color(0xFF1E88E5),
            onTap: _shareLocation,
          ),
        ],
      );
    }

    if (_match(q, ['merci', 'thanks', 'thank you', 'شكرا'])) {
      return _ChatMessage(
        text: 'Avec plaisir ! 🌿 Bonne randonnée.',
        isUser: false,
      );
    }

    // Fallback
    return _ChatMessage(
      text: 'Hmm, je n\'ai pas compris. Voici ce que je sais faire :',
      isUser: false,
      actions: [
        _ChatAction(
          label: 'Sentiers',
          icon: Icons.hiking,
          color: const Color(0xFF0E7A23),
          onTap: () => _send('Sentiers proches'),
        ),
        _ChatAction(
          label: 'Météo',
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFFFA000),
          onTap: () => _send('Météo'),
        ),
        _ChatAction(
          label: 'SOS',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFE53935),
          onTap: () => _send('SOS urgence'),
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

  // ── Reply builders ───────────────────────────────────────────────────

  String _weatherReply() {
    final w = context.read<WeatherProvider>().currentWeather;
    if (w == null) {
      return 'Pas de données météo. Vérifie ta connexion internet.';
    }
    return '${w.temperatureText}, vent ${w.windText}, '
        'humidité ${w.humidityText}.\n${_weatherAdvice(w.temperature)}';
  }

  String _weatherAdvice(double? tempC) {
    if (tempC == null) return '';
    if (tempC < 5) return '❄️ Il fait froid, prévois plusieurs couches.';
    if (tempC < 15) return '🧥 Frais — une veste est conseillée.';
    if (tempC < 25) return '✨ Conditions idéales pour randonner.';
    if (tempC < 32) return '☀️ Chaud — hydrate-toi régulièrement.';
    return '🔥 Très chaud — évite 11h-16h.';
  }

  _ChatMessage _trailsReply(LatLng pos) {
    final trails = context.read<TrailProvider>().trails;
    if (trails.isEmpty) {
      return _ChatMessage(
        text: 'Aucun sentier disponible. Rafraîchis l\'application.',
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
      text: 'Voici les sentiers les plus proches :',
      isUser: false,
      actions: actions,
    );
  }

  _ChatMessage _poisReply(LatLng pos) {
    final pois = context.read<PoiProvider>().pois;
    if (pois.isEmpty) {
      return _ChatMessage(
        text: 'Aucun point d\'intérêt disponible.',
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
      text: 'Points d\'intérêt à proximité :',
      isUser: false,
      actions: actions,
    );
  }

  _ChatMessage _servicesReply(LatLng pos) {
    final services = context.read<LocalServiceProvider>().services;
    if (services.isEmpty) {
      return _ChatMessage(
        text: 'Aucun service disponible.',
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
        text: 'Pas de services géolocalisés.',
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
      text: 'Services à proximité :',
      isUser: false,
      actions: actions,
    );
  }

  String _tipsReply() {
    return 'Checklist randonnée :\n'
        '🚶 Préviens quelqu\'un de ton itinéraire\n'
        '💧 Eau : 1.5L mini pour 4h\n'
        '👟 Chaussures adaptées + crème solaire\n'
        '☁️ Vérifie la météo avant de partir\n'
        '🔋 Téléphone chargé (mode économie)\n'
        '🍎 Encas énergétique (fruits secs)\n'
        '🆘 Connais l\'emplacement du bouton SOS';
  }

  // ── Action handlers ──────────────────────────────────────────────────

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Impossible de lancer l\'appel.');
    }
  }

  Future<void> _shareLocation() async {
    final pos = widget.userPosition;
    if (pos == null) {
      _toast('Position GPS non disponible.');
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
      _toast('Position copiée dans le presse-papier.');
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copié.');
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
    final lp = context.read<LocaleProvider>();
    final code = lp.locale.languageCode;
    await _tts.setLanguage(
      code == 'ar' ? 'ar-SA' : code == 'en' ? 'en-US' : 'fr-FR',
    );
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
                            child: const Center(
                              child: Icon(Icons.eco,
                                  color: Color(0xFF0E7A23), size: 26),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
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
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  _StatusDot(),
                                  SizedBox(width: 6),
                                  Text(
                                    'En ligne · Assistant local',
                                    style: TextStyle(
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
                          tooltip: 'Voix',
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
            // Input bar
            SafeArea(
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
                          hintText: 'Pose ta question...',
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
                    Material(
                      shape: const CircleBorder(),
                      color: Colors.transparent,
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF22B53A),
                              Color(0xFF0E7A23),
                            ],
                          ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            final isSos = s.label == 'Urgence';
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
                const Padding(
                  padding: EdgeInsets.only(right: 6, bottom: 4),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: Color(0xFF22B53A),
                    child: Icon(Icons.eco, color: Colors.white, size: 14),
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
          const Padding(
            padding: EdgeInsets.only(right: 6, bottom: 4),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFF22B53A),
              child: Icon(Icons.eco, color: Colors.white, size: 14),
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
  const _Suggestion(this.label, this.icon, this.query);
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
