import 'package:flutter/material.dart';

/// Chatbot avec clignotement rapide des yeux (effet "chargement").
///
/// Technique : l'image PNG d'origine n'est PAS modifiée. On superpose des
/// "paupières" sur les yeux ; elles descendent rapidement pour simuler le
/// clignotement.
///
/// Les coordonnées des yeux sont des FRACTIONS de la boîte affichée, donc
/// indépendantes de la taille. Elles sont calibrées par défaut pour le logo
/// 1002x814 ; ajuste-les via [imageAspect] et les paramètres d'œil si tu
/// utilises une autre image.
class BlinkingChatbot extends StatefulWidget {
  /// Chemin de l'asset (déclaré dans pubspec.yaml).
  final String assetPath;

  /// Taille du logo (largeur). La hauteur suit [imageAspect].
  final double size;

  /// Ratio largeur/hauteur de l'image source (par défaut 1002/814).
  final double imageAspect;

  /// Durée d'un cycle complet de clignotement.
  final Duration duration;

  /// Couleur de la "paupière" (doit matcher le fond de l'écran du logo).
  final Color lidColor;

  /// Couleur du trait "œil fermé".
  final Color eyeColor;

  /// Positions des yeux (fractions de la boîte) : (left, top, width, height).
  final Rect leftEye;
  final Rect rightEye;

  const BlinkingChatbot({
    super.key,
    this.assetPath = 'assets/images/bot.png',
    this.size = 160,
    this.imageAspect = 1002 / 814,
    this.duration = const Duration(milliseconds: 900),
    this.lidColor = const Color(0xFF000000),
    this.eyeColor = const Color(0xFF39D65C),
    this.leftEye = const Rect.fromLTWH(0.335, 0.465, 0.13, 0.17),
    this.rightEye = const Rect.fromLTWH(0.535, 0.465, 0.145, 0.17),
  });

  @override
  State<BlinkingChatbot> createState() => _BlinkingChatbotState();
}

class _BlinkingChatbotState extends State<BlinkingChatbot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w / widget.imageAspect;

    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final lid = _fastBlink(_controller.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Image originale, intacte.
              Image.asset(
                widget.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                ),
              ),
              _eyeOverlay(w, h, widget.leftEye, lid),
              _eyeOverlay(w, h, widget.rightEye, lid),
            ],
          );
        },
      ),
    );
  }

  /// Courbe de clignotement rapide : 3 impulsions nettes par cycle.
  double _fastBlink(double t) {
    bool inPulse(double start) => t >= start && t < start + 0.12;
    double pulse(double start) {
      final local = (t - start) / 0.12;
      return local < 0.5 ? local * 2 : (1 - local) * 2;
    }

    if (inPulse(0.05)) return pulse(0.05);
    if (inPulse(0.30)) return pulse(0.30);
    if (inPulse(0.55)) return pulse(0.55);
    return 0.0;
  }

  Widget _eyeOverlay(double w, double h, Rect eye, double lid) {
    final boxW = eye.width * w;
    final boxH = eye.height * h;

    return Positioned(
      left: eye.left * w,
      top: eye.top * h,
      width: boxW,
      height: boxH,
      child: ClipRect(
        child: Stack(
          children: [
            // Paupière : rectangle qui descend (scaleY depuis le haut).
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                widthFactor: 1.0,
                heightFactor: lid.clamp(0.0, 1.0),
                child: Container(color: widget.lidColor),
              ),
            ),
            // Trait "œil fermé" quand la paupière couvre l'œil.
            if (lid > 0.6)
              Align(
                alignment: const Alignment(0, 0.2),
                child: Container(
                  width: boxW * 0.7,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.eyeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
