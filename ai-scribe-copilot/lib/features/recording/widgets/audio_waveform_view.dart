import 'dart:math' as math;

import 'package:flutter/material.dart';

class AudioWaveformView extends StatefulWidget {
  const AudioWaveformView({super.key, required this.isRecording});

  final bool isRecording;

  @override
  State<AudioWaveformView> createState() => _AudioWaveformViewState();
}

class _AudioWaveformViewState extends State<AudioWaveformView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _amplitudes;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _amplitudes = _generateAmplitudes();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (!mounted || !widget.isRecording) {
          return;
        }
        if (status == AnimationStatus.completed) {
          setState(() {
            _amplitudes = _generateAmplitudes();
          });
        }
      });
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _amplitudes = _generateAmplitudes();
      _controller
        ..reset()
        ..repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _generateAmplitudes() {
    return List<double>.generate(48, (_) => _random.nextDouble());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live waveform',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _WaveformPainter(
                    progress: widget.isRecording ? _controller.value : 0,
                    amplitudes: _amplitudes,
                    color: theme.colorScheme.primary,
                    isRecording: widget.isRecording,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isRecording
                ? 'Streaming in real time. Interruptions are automatically recovered.'
                : 'Paused. Resume when ready.',
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.amplitudes,
    required this.color,
    required this.isRecording,
  });

  final double progress;
  final List<double> amplitudes;
  final Color color;
  final bool isRecording;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    final barCount = amplitudes.length;
    final step = size.width / barCount;
    final barWidth = step * 0.55;
    final paint = Paint()
      ..color = isRecording ? color : color.withOpacity(0.4)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final baseline = size.height / 2;
    final animationPhase = progress * 2 * math.pi;

    for (int i = 0; i < barCount; i++) {
      final amplitude = amplitudes[i];
      final oscillation = isRecording
          ? (math.sin(animationPhase + i * 0.35) + 1) / 2
          : 0.0;
      final intensity = (0.25 + amplitude * 0.5 + oscillation * 0.35)
          .clamp(0.0, 1.0);
      final barHeight = size.height * intensity;
      final x = step * i + step / 2;
      canvas.drawLine(
        Offset(x, baseline - barHeight / 2),
        Offset(x, baseline + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.amplitudes != amplitudes ||
        oldDelegate.color != color ||
        oldDelegate.isRecording != isRecording;
  }
}
