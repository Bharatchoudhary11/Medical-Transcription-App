import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/audio_recording_service.dart';

class AudioVisualizerWidget extends StatefulWidget {
  const AudioVisualizerWidget({super.key});

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with TickerProviderStateMixin {
  final AudioRecordingService _audioService = AudioRecordingService();
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  StreamSubscription<double>? _amplitudeSubscription;
  double _currentAmplitude = 0.0;
  final List<double> _amplitudeHistory = [];
  static const int _maxHistoryLength = 50;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _setupAmplitudeListener();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupAmplitudeListener() {
    _amplitudeSubscription = _audioService.amplitudeStream.listen((amplitude) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amplitude;
          _amplitudeHistory.add(amplitude);
          
          if (_amplitudeHistory.length > _maxHistoryLength) {
            _amplitudeHistory.removeAt(0);
          }
        });
        
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic,
            color: _getAmplitudeColor(),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildVisualizer(),
          ),
          const SizedBox(width: 12),
          _buildAmplitudeText(),
        ],
      ),
    );
  }

  Widget _buildVisualizer() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: AudioVisualizerPainter(
            amplitudeHistory: _amplitudeHistory,
            currentAmplitude: _currentAmplitude,
            animationValue: _animation.value,
          ),
          size: const Size(double.infinity, 60),
        );
      },
    );
  }

  Widget _buildAmplitudeText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getAmplitudeColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAmplitudeColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        '${(_currentAmplitude * 100).toInt()}%',
        style: TextStyle(
          color: _getAmplitudeColor(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getAmplitudeColor() {
    if (_currentAmplitude < 0.1) {
      return Colors.grey;
    } else if (_currentAmplitude < 0.3) {
      return Colors.green;
    } else if (_currentAmplitude < 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class AudioVisualizerPainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final double currentAmplitude;
  final double animationValue;

  AudioVisualizerPainter({
    required this.amplitudeHistory,
    required this.currentAmplitude,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudeHistory.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / _maxBars;
    final centerY = size.height / 2;

    for (int i = 0; i < _maxBars; i++) {
      final amplitudeIndex = (i / _maxBars * amplitudeHistory.length).floor();
      final amplitude = amplitudeIndex < amplitudeHistory.length
          ? amplitudeHistory[amplitudeIndex]
          : 0.0;

      final barHeight = (amplitude * size.height * 0.8) * animationValue;
      final x = i * barWidth + barWidth / 2;
      
      // Color based on amplitude
      if (amplitude < 0.1) {
        paint.color = Colors.grey.withOpacity(0.3);
      } else if (amplitude < 0.3) {
        paint.color = Colors.green.withOpacity(0.7);
      } else if (amplitude < 0.6) {
        paint.color = Colors.orange.withOpacity(0.7);
      } else {
        paint.color = Colors.red.withOpacity(0.7);
      }

      // Draw bar
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: barWidth * 0.6,
          height: barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  static const int _maxBars = 20;
}
