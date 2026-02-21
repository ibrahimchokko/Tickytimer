import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const TimerDemoApp());
}

enum TimerStatus { idle, running, paused, done }

class TimerDemoApp extends StatelessWidget {
  const TimerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimerDemoPage(),
    );
  }
}

class TimerDemoPage extends StatefulWidget {
  const TimerDemoPage({super.key});

  @override
  State<TimerDemoPage> createState() => _TimerDemoPageState();
}

class _TimerDemoPageState extends State<TimerDemoPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _minController = TextEditingController(text: '0');
  final TextEditingController _secController = TextEditingController(text: '10');

  int _durationMs = 10 * 1000;
  late int _remainingMs;
  TimerStatus _status = TimerStatus.idle;

  Timer? _ticker;
  DateTime? _endTime;

  static const int _adjustStepMs = 10 * 1000;
  static const int _minAllowedMs = 1 * 1000;

  bool _didDoneTrigger = false;

  // Sound
  late final AudioPlayer _player;

  // Effects animation
  late final AnimationController _fxController;

  @override
  void initState() {
    super.initState();
    _remainingMs = _durationMs;

    _player = AudioPlayer();

    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _stopTicker();
    _minController.dispose();
    _secController.dispose();
    _player.dispose();
    _fxController.dispose();
    super.dispose();
  }

  void _start() {
    if (_status == TimerStatus.running) return;
    if (_remainingMs <= 0) return;

    _didDoneTrigger = false;

    final now = DateTime.now();
    _endTime = now.add(Duration(milliseconds: _remainingMs));

    _status = TimerStatus.running;

    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _onTick());

    setState(() {});
  }

  void _onTick() {
    final end = _endTime;
    if (end == null) return;

    final now = DateTime.now();
    final diffMs = end.difference(now).inMilliseconds;
    final newRemaining = diffMs.clamp(0, _durationMs);

    if (newRemaining == 0) {
      _remainingMs = 0;
      _status = TimerStatus.done;
      _stopTicker();
      setState(() {});

      _onDoneEffects();
      return;
    }

    _remainingMs = newRemaining;
    setState(() {});
  }

  void _pause() {
    if (_status != TimerStatus.running) return;
    _stopTicker();
    _status = TimerStatus.paused;
    setState(() {});
  }

  void _reset() {
    _stopTicker();
    _endTime = null;
    _remainingMs = _durationMs;
    _status = TimerStatus.idle;
    _didDoneTrigger = false;
    _fxController.stop();
    _fxController.value = 0;
    setState(() {});
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _applyDurationFromInputs() {
    if (_status == TimerStatus.running) return;

    final min = int.tryParse(_minController.text.trim()) ?? 0;
    final sec = int.tryParse(_secController.text.trim()) ?? 0;

    if (min < 0 || sec < 0) {
      _showSnack('Minutes and seconds must be 0 or more.');
      return;
    }

    final normalizedMin = min + (sec ~/ 60);
    final normalizedSec = sec % 60;

    final totalSeconds = (normalizedMin * 60) + normalizedSec;
    if (totalSeconds == 0) {
      _showSnack('Duration must be more than 0 seconds.');
      return;
    }

    _durationMs = totalSeconds * 1000;
    _remainingMs = _durationMs;
    _status = TimerStatus.idle;
    _endTime = null;
    _didDoneTrigger = false;

    _minController.text = normalizedMin.toString();
    _secController.text = normalizedSec.toString();

    setState(() {});
  }

  void _adjustTime(int deltaMs) {
    if (_status == TimerStatus.done && deltaMs > 0) {
      _status = TimerStatus.idle;
      _didDoneTrigger = false;
      _fxController.stop();
      _fxController.value = 0;
    }

    if (_status == TimerStatus.running) {
      final end = _endTime;
      if (end == null) return;

      final newDuration =
          (_durationMs + deltaMs).clamp(_minAllowedMs, 24 * 60 * 60 * 1000);
      final durationDelta = newDuration - _durationMs;

      _durationMs = newDuration;
      _endTime = end.add(Duration(milliseconds: durationDelta));

      _onTick();
      return;
    }

    final newDuration =
        (_durationMs + deltaMs).clamp(_minAllowedMs, 24 * 60 * 60 * 1000);
    final durationDelta = newDuration - _durationMs;

    _durationMs = newDuration;
    _remainingMs = (_remainingMs + durationDelta).clamp(0, _durationMs);

    _syncInputsToDuration();

    if (_remainingMs == 0) {
      _status = TimerStatus.done;
      setState(() {});
      _onDoneEffects();
      return;
    }

    setState(() {});
  }

  void _syncInputsToDuration() {
    final totalSeconds = (_durationMs / 1000).round();
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    _minController.text = min.toString();
    _secController.text = sec.toString();
  }

  Future<void> _onDoneEffects() async {
    if (_didDoneTrigger) return;
    _didDoneTrigger = true;

    // Vibration (built-in)
    await HapticFeedback.vibrate();
    for (int i = 0; i < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
    }

    // Sound (asset)
    // If you do not hear sound: check pubspec assets path, and try on real device
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/done.mp3'));
    } catch (_) {
      // If audio fails, we still keep the app functional.
    }

    // Visual pulse + flash
    _fxController.forward(from: 0);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _statusText() {
    switch (_status) {
      case TimerStatus.idle:
        return 'Idle';
      case TimerStatus.running:
        return 'Running';
      case TimerStatus.paused:
        return 'Paused';
      case TimerStatus.done:
        return 'Done';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(_remainingMs);

    final canEditDuration = _status != TimerStatus.running;
    final canStart = _status != TimerStatus.running && _remainingMs > 0;
    final canPause = _status == TimerStatus.running;

    final animateInfinity = _status == TimerStatus.running;

    return Scaffold(
      appBar: AppBar(title: const Text('Timer: Sound + Effects')),
      body: AnimatedBuilder(
        animation: _fxController,
        builder: (context, child) {
          // Flash effect: a white overlay that fades out
          final flashOpacity = (1.0 - Curves.easeOut.transform(_fxController.value)) * 0.22;

          // Pulse scale: small pop when done
          final scale = 1.0 + (math.sin(_fxController.value * math.pi) * 0.04);

          return Stack(
            children: [
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
              IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(flashOpacity),
                ),
              ),
            ],
          );
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InfinityTimerViz(isAnimating: animateInfinity),

                const SizedBox(height: 14),

                Text(
                  timeText,
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Status: ${_statusText()}'),

                const SizedBox(height: 20),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () => _adjustTime(-_adjustStepMs),
                      child: const Text('-10s'),
                    ),
                    OutlinedButton(
                      onPressed: () => _adjustTime(_adjustStepMs),
                      child: const Text('+10s'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _minController,
                        enabled: canEditDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _secController,
                        enabled: canEditDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sec',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: canEditDuration ? _applyDurationFromInputs : null,
                      child: const Text('Apply'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: canStart ? _start : null,
                      child: const Text('Start'),
                    ),
                    ElevatedButton(
                      onPressed: canPause ? _pause : null,
                      child: const Text('Pause'),
                    ),
                    ElevatedButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfinityTimerViz extends StatefulWidget {
  const InfinityTimerViz({
    super.key,
    required this.isAnimating,
  });

  final bool isAnimating;

  @override
  State<InfinityTimerViz> createState() => _InfinityTimerVizState();
}

class _InfinityTimerVizState extends State<InfinityTimerViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (widget.isAnimating) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant InfinityTimerViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return CustomPaint(
            painter: InfinityPainter(t: _controller.value),
          );
        },
      ),
    );
  }
}

class InfinityPainter extends CustomPainter {
  InfinityPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final a = size.width * 0.24;
    final b = size.height * 0.30;

    final points = <Offset>[];
    const steps = 520;

    for (int i = 0; i <= steps; i++) {
      final theta = (i / steps) * math.pi * 2;
      final x = a * math.cos(theta);
      final y = b * math.sin(theta) * math.cos(theta);
      points.add(center + Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withOpacity(0.08);

    canvas.drawPath(path, basePaint);

    final idx = (t * steps).floor().clamp(0, steps);
    final head = points[idx];

    for (int k = 26; k >= 1; k--) {
      final trailT = (t - (k * 0.010)) % 1.0;
      final trailIdx = (trailT * steps).floor().clamp(0, steps);
      final p = points[trailIdx];

      final alpha = (1.0 - (k / 26)).clamp(0.0, 1.0);
      final trailPaint = Paint()..color = Colors.black.withOpacity(0.10 * alpha);
      canvas.drawCircle(p, 6 + (2 * alpha), trailPaint);
    }

    final glowPaint = Paint()..color = Colors.black.withOpacity(0.18);
    canvas.drawCircle(head, 18, glowPaint);

    final headPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawCircle(head, 8, headPaint);
  }

  @override
  bool shouldRepaint(covariant InfinityPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}