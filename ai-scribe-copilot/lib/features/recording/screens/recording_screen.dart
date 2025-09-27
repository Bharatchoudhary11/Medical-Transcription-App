import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/user_constants.dart';
import '../../../core/models/patient.dart';
import '../controllers/recording_controller.dart';
import '../state/recording_state.dart';
import '../widgets/audio_waveform_view.dart';
import '../widgets/recording_controls.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.patient});

  final Patient patient;

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final controller = ref.read(recordingControllerProvider.notifier);
      await controller.start(
        widget.patient.id,
        widget.patient.name,
        UserConstants.demoUserId,
      );
    });
  }

  @override
  void dispose() {
    final controller = ref.read(recordingControllerProvider.notifier);
    unawaited(controller.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _statusLabel(state.lifecycle),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultation timer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatDuration(state.duration),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _Badge(
                          icon: state.networkStatus == NetworkStatus.online
                              ? Icons.wifi
                              : Icons.wifi_off,
                          label: state.networkStatus == NetworkStatus.online
                              ? 'Streaming live'
                              : 'Offline - queued',
                          backgroundColor: state.networkStatus == NetworkStatus.online
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                        ),
                        if (state.batteryStatus != null)
                          _Badge(
                            icon: state.batteryStatus == BatteryStatus.healthy
                                ? Icons.battery_full
                                : Icons.battery_alert,
                            label: state.batteryStatus == BatteryStatus.healthy
                                ? 'Battery healthy'
                                : 'Charge soon',
                            backgroundColor:
                                state.batteryStatus == BatteryStatus.healthy
                                    ? Colors.blue.shade100
                                    : Colors.red.shade100,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AudioWaveformView(
                isRecording: state.lifecycle == RecordingLifecycle.recording,
              ),
            ),
            const SizedBox(height: 16),
            RecordingControls(
              lifecycle: state.lifecycle,
              onPause: () => ref.read(recordingControllerProvider.notifier).pause(),
              onResume: () => ref.read(recordingControllerProvider.notifier).resume(),
              onStop: () async {
                await ref.read(recordingControllerProvider.notifier).stop();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(RecordingLifecycle lifecycle) {
    switch (lifecycle) {
      case RecordingLifecycle.preparing:
        return 'Preparing';
      case RecordingLifecycle.recording:
        return 'Recording';
      case RecordingLifecycle.paused:
        return 'Paused';
      case RecordingLifecycle.error:
        return 'Error';
      case RecordingLifecycle.idle:
        return 'Idle';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
