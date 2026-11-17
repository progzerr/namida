// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/live_progress.dart';
import 'package:namida/youtube/class/youtube_id.dart';

/// Used in fullscreen lyrics & widescreen player
class PlayerTransportControls extends StatefulWidget {
  final bool addBottomSafePadding;
  final double waveformYScale;
  final double waveformBottomGap;
  final double bottomPadding;

  const PlayerTransportControls({
    super.key,
    this.addBottomSafePadding = true,
    this.waveformYScale = 1.0,
    this.waveformBottomGap = 12.0,
    this.bottomPadding = 24.0,
  });

  @override
  State<PlayerTransportControls> createState() => _PlayerTransportControlsState();
}

class _PlayerTransportControlsState extends State<PlayerTransportControls> {
  final _currentItemDurationMS = RxnO<int>();

  @override
  void initState() {
    super.initState();
    _itemDurationUpdater();
    Player.inst.currentItemDuration.addListener(_itemDurationUpdater);
  }

  @override
  void dispose() {
    Player.inst.currentItemDuration.removeListener(_itemDurationUpdater);
    _currentItemDurationMS.close();
    super.dispose();
  }

  int _itemDurationUpdater() {
    int totalDurMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
    if (totalDurMS == 0) {
      final current = Player.inst.currentItem.value;
      if (current is Selectable) {
        totalDurMS = current.track.durationMS;
      } else if (current is YoutubeID) {
        totalDurMS = Player.inst.getCurrentVideoDuration.inMilliseconds;
      }
    }
    _currentItemDurationMS.value = totalDurMS;
    return totalDurMS;
  }

  @override
  Widget build(BuildContext context) {
    const waveform = WaveformMiniplayer(
      fixPadding: true,
      enableHero: false,
    );
    final waveformYScale = widget.waveformYScale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        waveformYScale == 1.0
            ? waveform
            : Align(
                heightFactor: waveformYScale,
                child: Transform.scale(
                  scaleY: waveformYScale,
                  child: waveform,
                ),
              ),
        SizedBox(height: widget.waveformBottomGap),
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SeekBackwardsDetectorWidget(
                      child: NamidaHero(
                        enabled: false,
                        tag: 'MINIPLAYER_POSITION',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: ObxO(
                            rx: Player.inst.currentLiveWindow,
                            builder: (context, liveWindow) => liveWindow != null
                                ? LivePositionText(
                                    window: liveWindow,
                                    style: NText.small,
                                  )
                                : ObxO(
                                    rx: Player.inst.nowPlayingPosition,
                                    builder: (context, currentMS) => NamidaText(
                                      currentMS.milliSecondsLabel,
                                      style: NText.small,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Obx(
                (context) {
                  final miniplayerColor = CurrentColor.inst.miniplayerColor;
                  return _LiquidRippleTap(
                    color: miniplayerColor,
                    child: NamidaIconButton(
                      icon: Broken.previous,
                      iconSize: 24.0,
                      iconColor: NColors.fixed(Color.lerp(Colors.white70, miniplayerColor, 0.6)!),
                      onPressed: Player.inst.previous,
                    ),
                  );
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: (constraints.maxWidth * 0.04).clampDouble(8.0, 32.0)),
                child: const _PlayPauseButton(),
              ),
              Obx(
                (context) {
                  final miniplayerColor = CurrentColor.inst.miniplayerColor;
                  return _LiquidRippleTap(
                    color: miniplayerColor,
                    child: NamidaIconButton(
                      icon: Broken.next,
                      iconSize: 24.0,
                      iconColor: NColors.fixed(Color.lerp(Colors.white70, miniplayerColor, 0.6)!),
                      onPressed: Player.inst.next,
                    ),
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SeekForwardDetectorWidget(
                      child: NamidaHero(
                        enabled: false,
                        tag: 'MINIPLAYER_DURATION',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: ObxO(
                            rx: Player.inst.currentLiveWindow,
                            builder: (context, liveWindow) => liveWindow != null
                                ? LiveEdgeChip(window: liveWindow)
                                : ObxO(
                                    rx: settings.player.displayRemainingDurInsteadOfTotal,
                                    builder: (context, displayRemainingDurInsteadOfTotal) => displayRemainingDurInsteadOfTotal
                                        ? ObxO(
                                            rx: _currentItemDurationMS,
                                            builder: (context, durMS) {
                                              int finalDurMS = durMS ?? 0;
                                              return ObxO(
                                                rx: Player.inst.currentItem,
                                                builder: (context, currentItem) {
                                                  if (finalDurMS == 0 && currentItem is Selectable) {
                                                    finalDurMS = currentItem.track.durationMS;
                                                  }
                                                  return ObxO(
                                                    rx: Player.inst.nowPlayingPosition,
                                                    builder: (context, toSubtract) => NamidaText(
                                                      "- ${(finalDurMS - toSubtract).milliSecondsLabel}",
                                                      style: NText.small,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                        : ObxO(
                                            rx: _currentItemDurationMS,
                                            builder: (context, milliseconds) {
                                              if (milliseconds == null || milliseconds == 0) {
                                                return ObxO(
                                                  rx: Player.inst.currentItem,
                                                  builder: (context, currentItem) => NamidaText(
                                                    (currentItem is Selectable ? currentItem.track.durationMS : 0).milliSecondsLabel,
                                                    style: NText.small,
                                                  ),
                                                );
                                              }
                                              return NamidaText(
                                                milliseconds.milliSecondsLabel,
                                                style: NText.small,
                                              );
                                            },
                                          ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: widget.bottomPadding),
        if (widget.addBottomSafePadding) SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// A soft, liquid-tinted ripple that blooms from the center on tap-down and
/// fades out — purely cosmetic, sits behind whatever [child] is and never
/// intercepts the tap itself (the real button underneath still handles it).
class _LiquidRippleTap extends StatefulWidget {
  final Widget child;
  final Color color;

  const _LiquidRippleTap({required this.child, required this.color});

  @override
  State<_LiquidRippleTap> createState() => _LiquidRippleTapState();
}

class _LiquidRippleTapState extends State<_LiquidRippleTap> with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _rippleController.forward(from: 0.0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _rippleController,
              builder: (context, _) {
                final t = _rippleController.value;
                if (t == 0.0) return const SizedBox.shrink();
                return Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: Container(
                    width: 40.0 + 16.0 * t,
                    height: 40.0 + 16.0 * t,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacityExt(0.38)),
                  ),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Play/pause with the same colored circle the main player uses.
class _PlayPauseButton extends StatefulWidget {
  final double iconSize;
  final double extraPadding;

  const _PlayPauseButton({this.iconSize = 32.0, this.extraPadding = 12.0});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  /// a slow, continuous breathing glow behind the button while playing —
  /// distinct from the on-tap ripple, this one just lives there the whole
  /// time music is playing, like the button itself is breathing.
  late final AnimationController _breathController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    Player.inst.isPlaying.addListener(_onPlayingChanged);
    _syncBreathing();
  }

  void _onPlayingChanged() => _syncBreathing();

  void _syncBreathing() {
    if (Player.inst.isPlaying.value) {
      if (!_breathController.isAnimating) _breathController.repeat(reverse: true);
    } else {
      _breathController.animateTo(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  void _setHighlighted(bool value) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = value;

  @override
  void dispose() {
    Player.inst.isPlaying.removeListener(_onPlayingChanged);
    _rippleController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Player.inst.togglePlayPause,
      onTapDown: (_) {
        _setHighlighted(true);
        _rippleController.forward(from: 0.0);
      },
      onTapUp: (_) => _setHighlighted(false),
      onTapCancel: () => _setHighlighted(false),
      child: Obx(
        (context) {
          final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.valueR;
          final miniplayerColor = CurrentColor.inst.miniplayerColor;
          final tintedIconColor = Color.lerp(Colors.white, miniplayerColor, 0.18)!.withOpacityExt(0.88);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, _) {
                    final t = _breathController.value;
                    if (t == 0.0) return const SizedBox.shrink();
                    final glowSize = (widget.iconSize + widget.extraPadding * 2) * (1.35 + 0.35 * t);
                    return Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [miniplayerColor.withOpacityExt(0.32 * t), Colors.transparent],
                        ),
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, _) {
                    final t = _rippleController.value;
                    if (t == 0.0) return const SizedBox.shrink();
                    final rippleSize = (widget.iconSize + widget.extraPadding * 2) * (0.7 + 0.7 * t);
                    return Opacity(
                      opacity: (1.0 - t).clamp(0.0, 1.0),
                      child: Container(
                        width: rippleSize,
                        height: rippleSize,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: miniplayerColor.withOpacityExt(0.3)),
                      ),
                    );
                  },
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 400),
                scale: isButtonHighlighed ? 0.97 : 1.0,
                child: AnimatedDecoration(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    color: isButtonHighlighed ? Color.alphaBlend(miniplayerColor.withOpacityExt(0.91), Colors.white) : miniplayerColor,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        miniplayerColor,
                        Color.alphaBlend(miniplayerColor.withOpacityExt(0.78), Colors.grey),
                      ],
                      stops: const [0, 0.7],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: miniplayerColor.withOpacityExt(0.63),
                        blurRadius: 8.0,
                        spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                        offset: const Offset(0.0, 2.0),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(widget.extraPadding),
                        child: ObxO(
                          rx: Player.inst.playWhenReady,
                          builder: (context, playWhenReady) => CustomAnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              playWhenReady ? Broken.pause : Broken.play,
                              size: widget.iconSize,
                              key: Key(playWhenReady ? 'pauseicon' : 'playicon'),
                              color: tintedIconColor,
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Obx(
                          (context) => Player.inst.shouldShowLoadingIndicatorR
                              ? ThreeArchedCircle(
                                  color: Colors.white.withOpacityExt(0.47),
                                  size: widget.iconSize * 1.4,
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
