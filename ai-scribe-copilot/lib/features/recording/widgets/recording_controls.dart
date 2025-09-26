import 'package:flutter/material.dart';

import '../state/recording_state.dart';

class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.lifecycle,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final RecordingLifecycle lifecycle;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: lifecycle == RecordingLifecycle.recording ? onPause : onResume,
            icon: Icon(
              lifecycle == RecordingLifecycle.recording
                  ? Icons.pause
                  : Icons.play_arrow,
            ),
            label: Text(lifecycle == RecordingLifecycle.recording ? 'Pause' : 'Resume'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await onStop();
            },
            icon: const Icon(Icons.stop),
            label: const Text('Finish & sync'),
          ),
        ),
      ],
    );
  }
}
