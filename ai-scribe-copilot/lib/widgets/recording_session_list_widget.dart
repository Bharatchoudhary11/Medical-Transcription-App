import 'package:flutter/material.dart';
import '../models/recording_session.dart';

class RecordingSessionListWidget extends StatelessWidget {
  final List<RecordingSession> sessions;
  final Function(RecordingSession) onViewTranscription;

  const RecordingSessionListWidget({
    super.key,
    required this.sessions,
    required this.onViewTranscription,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionCard(context, session);
      },
    );
  }

  Widget _buildSessionCard(BuildContext context, RecordingSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(session.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSessionTitle(session),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSessionSubtitle(session),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSessionActions(context, session),
              ],
            ),
            const SizedBox(height: 12),
            _buildSessionProgress(context, session),
            if (session.transcription != null) ...[
              const SizedBox(height: 12),
              _buildTranscriptionPreview(context, session.transcription!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(RecordingStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case RecordingStatus.recording:
        icon = Icons.mic;
        color = Colors.red;
        break;
      case RecordingStatus.paused:
        icon = Icons.pause;
        color = Colors.orange;
        break;
      case RecordingStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case RecordingStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSessionActions(BuildContext context, RecordingSession session) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'transcription':
            onViewTranscription(session);
            break;
          case 'details':
            _showSessionDetails(context, session);
            break;
        }
      },
      itemBuilder: (context) => [
        if (session.transcription != null)
          const PopupMenuItem(
            value: 'transcription',
            child: Row(
              children: [
                Icon(Icons.text_fields),
                SizedBox(width: 8),
                Text('View Transcription'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              Icon(Icons.info),
              SizedBox(width: 8),
              Text('Session Details'),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }

  Widget _buildSessionProgress(BuildContext context, RecordingSession session) {
    final progress = session.totalChunks > 0 
        ? session.uploadedChunks / session.totalChunks 
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upload Progress',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${session.uploadedChunks}/${session.totalChunks} chunks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress == 1.0 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptionPreview(BuildContext context, String transcription) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Transcription Preview',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transcription.length > 100 
                ? '${transcription.substring(0, 100)}...'
                : transcription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatSessionTitle(RecordingSession session) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : DateTime.now().difference(session.startTime);
    
    return 'Session ${_formatDuration(duration)}';
  }

  String _formatSessionSubtitle(RecordingSession session) {
    final startTime = session.startTime;
    return 'Started ${_formatDateTime(startTime)}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'yesterday at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showSessionDetails(BuildContext context, RecordingSession session) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', _getStatusText(session.status)),
              _buildDetailRow('Start Time', _formatDateTime(session.startTime)),
              if (session.endTime != null)
                _buildDetailRow('End Time', _formatDateTime(session.endTime!)),
              _buildDetailRow('Duration', _formatDuration(
                session.endTime != null
                    ? session.endTime!.difference(session.startTime)
                    : DateTime.now().difference(session.startTime),
              )),
              _buildDetailRow('Total Chunks', session.totalChunks.toString()),
              _buildDetailRow('Uploaded Chunks', session.uploadedChunks.toString()),
              _buildDetailRow('Upload Progress', 
                  '${(session.uploadedChunks / session.totalChunks * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatusText(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return 'Recording';
      case RecordingStatus.paused:
        return 'Paused';
      case RecordingStatus.completed:
        return 'Completed';
      case RecordingStatus.failed:
        return 'Failed';
    }
  }
}
