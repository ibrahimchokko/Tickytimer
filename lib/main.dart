import 'dart:async';
import 'package:flutter/material.dart';

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

class _TimerDemoPageState extends State<TimerDemoPage> {
  // 1) Core state
  final int _durationMs = 10 * 1000; // 10 seconds for testing
  late int _remainingMs;
  TimerStatus _status = TimerStatus.idle;

  // 2) Timer internals
  Timer? _ticker;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _remainingMs = _durationMs;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  // 3) Start logic
  void _start() {
    if (_status == TimerStatus.running) return;

    final now = DateTime.now();
    _endTime = now.add(Duration(milliseconds: _remainingMs));

    _status = TimerStatus.running;

    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _onTick();
    });

    setState(() {});
  }

  // 4) Tick logic (runs repeatedly)
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
      return;
    }

    _remainingMs = newRemaining;
    setState(() {});
  }

  // 5) Pause logic
  void _pause() {
    if (_status != TimerStatus.running) return;

    _stopTicker();
    _status = TimerStatus.paused;
    setState(() {});
  }

  // 6) Reset logic
  void _reset() {
    _stopTicker();
    _endTime = null;
    _remainingMs = _durationMs;
    _status = TimerStatus.idle;
    setState(() {});
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(_remainingMs);

    String statusText() {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Basic Timer Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${statusText()}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: (_status == TimerStatus.running) ? null : _start,
                    child: const Text('Start'),
                  ),
                  ElevatedButton(
                    onPressed: (_status == TimerStatus.running) ? _pause : null,
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
    );
  }
}