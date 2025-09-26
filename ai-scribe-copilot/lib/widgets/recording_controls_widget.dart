import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecordingControlsWidget extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const RecordingControlsWidget({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isRecording && !isPaused) ...[
          _buildControlButton(
            context: context,
            icon: Icons.pause,
            label: 'Pause',
            color: Colors.orange,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onPause();
            },
          ),
          const SizedBox(width: 16),
        ],
        if (isRecording && isPaused) ...[
          _buildControlButton(
            context: context,
            icon: Icons.play_arrow,
            label: 'Resume',
            color: Colors.green,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onResume();
            },
          ),
          const SizedBox(width: 16),
        ],
        _buildControlButton(
          context: context,
          icon: Icons.stop,
          label: 'Stop',
          color: Colors.red,
          onPressed: () {
            HapticFeedback.heavyImpact();
            _showStopConfirmation(context);
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            iconSize: 24,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showStopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording'),
        content: const Text(
          'Are you sure you want to stop recording? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onStop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
