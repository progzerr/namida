// ignore_for_file: unused_import

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';

/// Drop-in alternative to [ArtworkWidget] for the "now playing" surfaces
/// (mini player, full player). Instead of a flat square/rounded cover, the
/// track's artwork is shown as the label of a vinyl record whose body is a
/// translucent liquid-fill disc — colored from the track's own artwork,
/// the way the "liquid vinyl" pressings look under light.
///
/// Spins continuously while [Player.inst.isPlaying] is true and freezes at
/// its current angle when paused. The liquid layer underneath keeps a slow
/// drift of its own even at rest, independent from the groove/label spin,
/// so it reads as fluid rather than a texture painted on the disc.
class VinylDiscArtwork extends StatefulWidget {
  final Track? track;
  final String? path;
  final Uint8List? bytes;
  final bool extractInternally;
  final bool fallbackToFolderCover;

  /// outer diameter of the whole disc (square box).
  final double size;
  final double thumbnailSize;
  final bool compressed;
  final ValueListenable<double>? glowOpacity;
  final List<BoxShadow>? boxShadow;
  final int fadeMilliSeconds;

  /// how long one full rotation takes while playing.
  final Duration rotationDuration;

  const VinylDiscArtwork({
    super.key,
    this.track,
    this.path,
    this.bytes,
    this.extractInternally = true,
    this.fallbackToFolderCover = true,
    required this.size,
    required this.thumbnailSize,
    this.compressed = true,
    this.glowOpacity,
    this.boxShadow,
    this.fadeMilliSeconds = 300,
    this.rotationDuration = const Duration(seconds: 2),
  });

  @override
  State<VinylDiscArtwork> createState() => _VinylDiscArtworkState();
}

class _VinylDiscArtworkState extends State<VinylDiscArtwork> with TickerProviderStateMixin {
  static const _kLiquidDriftPlaying = Duration(seconds: 11);
  static const _kLiquidDriftIdle = Duration(seconds: 34);

  /// a soft far ambient shadow plus a tighter contact shadow reads as
  /// "lifted off the shelf" far better than one single blurred shadow.
  static const _kDefaultElevationShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 30.0, offset: Offset(0.0, 14.0), spreadRadius: -4.0),
    BoxShadow(color: Color(0x33000000), blurRadius: 10.0, offset: Offset(0.0, 4.0)),
  ];

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: widget.rotationDuration,
  );

  /// Independent, slower loop for the liquid pattern so it drifts at its
  /// own pace rather than being glued to the disc's spin — that mismatch in
  /// speed is what reads as "liquid sloshing inside glass" rather than a
  /// printed swirl.
  late final AnimationController _liquidController = AnimationController(
    vsync: this,
    duration: _kLiquidDriftIdle,
  )..repeat();

  @override
  void initState() {
    super.initState();
    Player.inst.isPlaying.addListener(_onPlayingChanged);
    _syncSpinState();
  }

  @override
  void didUpdateWidget(covariant VinylDiscArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationDuration != widget.rotationDuration) {
      _spinController.duration = widget.rotationDuration;
    }
  }

  void _onPlayingChanged() => _syncSpinState();

  void _syncSpinState() {
    final isPlaying = Player.inst.isPlaying.value;
    if (isPlaying) {
      if (!_spinController.isAnimating) _spinController.repeat();
      _liquidController.repeat(period: _kLiquidDriftPlaying);
    } else {
      // -- freeze the disc at its current angle instead of snapping to 0.
      _spinController.stop(canceled: false);
      // -- the liquid keeps a slow ambient drift rather than stopping dead.
      _liquidController.repeat(period: _kLiquidDriftIdle);
    }
  }

  @override
  void dispose() {
    Player.inst.isPlaying.removeListener(_onPlayingChanged);
    _spinController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final labelSize = size * 0.44;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: widget.boxShadow ?? _kDefaultElevationShadow,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_spinController, _liquidController]),
          builder: (context, child) {
            // -- pulled fresh every frame: once the palette finishes
            // -- extracting for a newly-changed track, the very next tick
            // -- of these already-running animations picks up the new tint.
            final liquidColor = CurrentColor.inst.color;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // -- ambient bloom: the liquid's own color, soft and large,
                // -- spilling a little past the disc's edge rather than
                // -- stopping dead at it.
                IgnorePointer(
                  child: Container(
                    width: size * 1.3,
                    height: size * 1.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [liquidColor.withOpacityExt(0.30), liquidColor.withOpacityExt(0.10), Colors.transparent],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _VinylDiscPainter(
                      liquidColor: liquidColor,
                      liquidPhase: _liquidController.value,
                      spinPhase: _spinController.value,
                    ),
                  ),
                ),
                ClipOval(
                  child: SizedBox(
                    width: labelSize,
                    height: labelSize,
                    child: Transform.rotate(
                      angle: _spinController.value * 2 * math.pi,
                      child: child,
                    ),
                  ),
                ),
                // -- spindle hole
                Container(
                  width: size * 0.026,
                  height: size * 0.026,
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                ),
              ],
            );
          },
          child: ArtworkWidget(
            key: widget.track != null ? Key('vinyl_label_${widget.track!.pathToImage}') : UniqueKey(),
            track: widget.track,
            path: widget.path,
            bytes: widget.bytes,
            extractInternally: widget.extractInternally,
            fallbackToFolderCover: widget.fallbackToFolderCover,
            thumbnailSize: widget.thumbnailSize,
            width: labelSize,
            height: labelSize,
            isCircle: true,
            compressed: widget.compressed,
            borderRadius: labelSize,
            fadeMilliSeconds: widget.fadeMilliSeconds,
            blur: 0,
            glowOpacity: widget.glowOpacity,
            iconSize: labelSize * 0.45,
          ),
        ),
      ),
    );
  }
}

class _VinylDiscPainter extends CustomPainter {
  final Color liquidColor;
  final double liquidPhase;
  final double spinPhase;

  const _VinylDiscPainter({
    required this.liquidColor,
    required this.liquidPhase,
    required this.spinPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final discRect = Rect.fromCircle(center: center, radius: radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(discRect));

    // -- near-black translucent base, barely tinted, so the disc still
    // -- reads as vinyl first and liquid-filled second.
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF131316));

    // -- the colored liquid wash, deepest at the centre, so the label
    // -- appears to float inside it rather than sit on top.
    final washColor = liquidColor.withOpacityExt(0.5);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [washColor.withOpacityExt(0.62), washColor.withOpacityExt(0.22), Colors.transparent],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(discRect),
    );

    // -- directional sunlight ray: a tight warm beam raking across the
    // -- disc. Its angle drifts with the liquid's own motion so the light
    // -- feels like it's catching a moving surface, not pasted on top.
    final liquidAngle = liquidPhase * 2 * math.pi;
    final beamAngle = -0.78 + math.sin(liquidAngle) * 0.12;
    final beamDir = Offset(math.cos(beamAngle), math.sin(beamAngle));
    final beamNormal = Offset(-beamDir.dy, beamDir.dx);
    final beamHalfWidth = radius * 0.16;
    final beamOrigin = center + beamNormal * (radius * 0.22);

    canvas.save();
    canvas.translate(beamOrigin.dx, beamOrigin.dy);
    canvas.rotate(beamAngle);
    final beamRect = Rect.fromCenter(center: Offset.zero, width: radius * 2.6, height: beamHalfWidth * 2);
    canvas.drawRect(
      beamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFFFFF3D0).withOpacityExt(0.5), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(beamRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, beamHalfWidth * 0.5)
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();

    // -- a handful of soft, pale air pockets drifting at their own slow
    // -- pace — this is the main "liquid" tell, more than any one detail.
    // -- where the sun beam crosses one, it gets a bright refraction glint
    // -- plus a faint dispersed-color fringe, like light bending through
    // -- the liquid's surface right at that pocket's edge.
    const blobs = [
      (angle: 0.3, dist: 0.30, size: 0.30, opacity: 0.20),
      (angle: 2.1, dist: 0.55, size: 0.20, opacity: 0.16),
      (angle: 3.4, dist: 0.68, size: 0.16, opacity: 0.14),
      (angle: 4.6, dist: 0.42, size: 0.13, opacity: 0.12),
    ];
    for (final blob in blobs) {
      final angle = liquidAngle + blob.angle;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius * blob.dist;
      final blobRadius = radius * blob.size;
      canvas.drawCircle(
        pos,
        blobRadius,
        Paint()
          ..color = Colors.white.withOpacityExt(blob.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobRadius * 0.55),
      );

      final toBlob = pos - beamOrigin;
      final perp = (toBlob.dx * beamNormal.dx + toBlob.dy * beamNormal.dy).abs();
      final lit = (1.0 - perp / beamHalfWidth).clamp(0.0, 1.0);
      if (lit > 0.01) {
        final glintPos = pos - beamNormal * (blobRadius * 0.3);
        canvas.drawCircle(
          glintPos,
          blobRadius * 0.4 * lit,
          Paint()
            ..color = Colors.white.withOpacityExt(0.4 * lit)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobRadius * 0.3)
            ..blendMode = BlendMode.plus,
        );
        // -- dispersion fringe: light splitting at the lit edge, three
        // -- faint rings nudged along the beam direction.
        const fringeColors = [Color(0x40FF7A7A), Color(0x4070FFB0), Color(0x406FA0FF)];
        for (int i = 0; i < fringeColors.length; i++) {
          final nudge = beamDir * ((i - 1) * radius * 0.007);
          canvas.drawCircle(
            glintPos + nudge,
            blobRadius * 0.46 * lit,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = radius * 0.009
              ..color = fringeColors[i].withOpacityExt(lit * 0.55),
          );
        }
      }
    }

    // -- a few fine sparkle specks suspended in the liquid, drifting a
    // -- touch faster than the big air pockets and twinkling gently —
    // -- this is the "not muted" detail, kept tiny so it adds life
    // -- without competing with the beam or the blobs.
    const sparkles = [
      (angle: 0.9, dist: 0.25, size: 0.018, seed: 0.0),
      (angle: 1.8, dist: 0.60, size: 0.014, seed: 1.3),
      (angle: 3.0, dist: 0.38, size: 0.016, seed: 2.6),
      (angle: 4.2, dist: 0.70, size: 0.012, seed: 0.7),
      (angle: 5.4, dist: 0.50, size: 0.015, seed: 3.1),
    ];
    for (final sparkle in sparkles) {
      final angle = liquidAngle * 1.6 + sparkle.angle;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius * sparkle.dist;
      final twinkle = math.sin(liquidAngle * 3 + sparkle.seed) * 0.5 + 0.5;
      final sparkleRadius = radius * sparkle.size;
      canvas.drawCircle(
        pos,
        sparkleRadius,
        Paint()
          ..color = Colors.white.withOpacityExt(0.15 + 0.45 * twinkle)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sparkleRadius * 0.6)
          ..blendMode = BlendMode.plus,
      );
    }

    // -- a couple of thin, pale tendrils near the rim: the faint capillary
    // -- bleed where liquid clings to the inner edge of the sleeve.
    for (final seed in [liquidAngle, liquidAngle + 2.4]) {
      final start = center + Offset(math.cos(seed), math.sin(seed)) * radius * 0.92;
      final ctrl = center + Offset(math.cos(seed + 0.5), math.sin(seed + 0.5)) * radius * 0.75;
      final end = center + Offset(math.cos(seed + 0.9), math.sin(seed + 0.9)) * radius * 0.6;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.025
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacityExt(0.07),
      );
    }

    // -- label-edge ring, where the printed label meets the liquid.
    canvas.drawCircle(
      center,
      radius * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.012
        ..color = Colors.black.withOpacityExt(0.55),
    );

    // -- concentric grooves, etched through the liquid, uneven so they
    // -- don't read as a drawn target.
    const grooveCount = 50;
    for (int i = 0; i < grooveCount; i++) {
      final t = i / grooveCount;
      final r = radius * (0.5 + 0.47 * t);
      final isAccent = i % 7 == 0;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isAccent ? 0.9 : 0.5
          ..color = Colors.white.withOpacityExt(isAccent ? 0.07 : 0.035),
      );
    }

    // -- outer rim shadow so the edge doesn't vanish on a black background.
    final rimWidth = radius * 0.018;
    canvas.drawCircle(
      center,
      radius - rimWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..color = Colors.black.withOpacityExt(0.55),
    );

    // -- glass-edge highlight: a thin bright arc exactly where the sun
    // -- beam's own direction grazes the disc's rim, like light catching
    // -- the curved edge of the acrylic. Drawn last so it stays crisp on
    // -- top of the rim shadow instead of getting muddied by it.
    final litRimAngle = math.atan2(beamNormal.dy, beamNormal.dx);
    const litRimSpan = 0.55;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - rimWidth),
      litRimAngle - litRimSpan / 2,
      litRimSpan,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth * 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacityExt(0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rimWidth * 0.9)
        ..blendMode = BlendMode.plus,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VinylDiscPainter oldDelegate) =>
      oldDelegate.liquidColor != liquidColor || oldDelegate.liquidPhase != liquidPhase || oldDelegate.spinPhase != spinPhase;
}
