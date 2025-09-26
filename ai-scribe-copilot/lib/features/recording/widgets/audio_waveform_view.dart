import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class AudioWaveformView extends StatefulWidget {
  const AudioWaveformView({super.key, required this.isRecording});

  final bool isRecording;

  @override
  State<AudioWaveformView> createState() => _AudioWaveformViewState();
}

class _AudioWaveformViewState extends State<AudioWaveformView> {
  late final RecorderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RecorderController();
    if (widget.isRecording) {
      _controller.refresh();
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live waveform',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AudioWaveforms(
              size: const Size(double.infinity, double.infinity),
              recorderController: _controller,
              waveStyle: const WaveStyle(
                waveColor: Colors.blueAccent,
                extendWaveform: true,
                showMiddleLine: false,
              ),
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
