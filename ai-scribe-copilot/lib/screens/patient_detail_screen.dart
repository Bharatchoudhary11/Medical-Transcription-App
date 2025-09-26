import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/recording_session.dart';
import '../services/audio_recording_service.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/recording_session_list_widget.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final Patient patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final ApiService _apiService = ApiService();
  final LocalStorageService _storageService = LocalStorageService();
  
  List<RecordingSession> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load sessions from local storage
      final sessions = await _storageService.getSessionsByPatient(widget.patient.id);
      
      // Try to sync with server
      try {
        final serverSessions = await _apiService.getSessionsByPatient(widget.patient.id);
        if (serverSessions.isNotEmpty) {
          // Update local storage with server data
          for (final session in serverSessions) {
            await _storageService.saveSession(session);
          }
          final updatedSessions = await _storageService.getSessionsByPatient(widget.patient.id);
          setState(() {
            _sessions = updatedSessions;
          });
        } else {
          setState(() {
            _sessions = sessions;
          });
        }
      } catch (e) {
        // Use local data if server is unavailable
        setState(() {
          _sessions = sessions;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load sessions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final success = await _audioService.startRecording(
        widget.patient.id,
        'current_user_id',
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started recording for ${widget.patient.name}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSessions(); // Refresh sessions
      } else {
        throw Exception('Failed to start recording');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewTranscription(RecordingSession session) async {
    try {
      final transcription = await _apiService.getTranscription(session.id);
      if (transcription != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transcription'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(transcription),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcription not available yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transcription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientInfo(),
          const SizedBox(height: 24),
          _buildSessionsSection(),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    widget.patient.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (widget.patient.medicalRecordNumber != null)
                        Text(
                          'MRN: ${widget.patient.medicalRecordNumber}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.patient.email != null) ...[
              _buildInfoRow(Icons.email, 'Email', widget.patient.email!),
              const SizedBox(height: 8),
            ],
            if (widget.patient.phone != null) ...[
              _buildInfoRow(Icons.phone, 'Phone', widget.patient.phone!),
              const SizedBox(height: 8),
            ],
            _buildInfoRow(
              Icons.cake,
              'Date of Birth',
              _formatDate(widget.patient.dateOfBirth),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Added',
              _formatDate(widget.patient.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recording Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _buildErrorWidget()
        else if (_sessions.isEmpty)
          _buildEmptySessionsWidget()
        else
          RecordingSessionListWidget(
            sessions: _sessions,
            onViewTranscription: _viewTranscription,
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySessionsWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.mic_none,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No recording sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first consultation recording',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Start Recording'),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_audioService.isRecording) return null;
    
    return FloatingActionButton.extended(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic),
      label: const Text('Start Recording'),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
