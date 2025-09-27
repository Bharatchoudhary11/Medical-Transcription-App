import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/patient.dart';
import '../models/recording_session.dart';
import '../services/audio_recording_service.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/patient_list_widget.dart';
import '../widgets/recording_controls_widget.dart';
import '../widgets/audio_visualizer_widget.dart';
import 'patient_detail_screen.dart';
import 'add_patient_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final ApiService _apiService = ApiService();
  final LocalStorageService _storageService = LocalStorageService();
  
  List<Patient> _patients = [];
  RecordingSession? _currentSession;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupAudioService();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load patients from local storage
      final patients = await _storageService.getPatients();
      
      // Try to sync with server
      try {
        final serverPatients = await _apiService.getPatients('current_user_id');
        if (serverPatients.isNotEmpty) {
          // Update local storage with server data
          for (final patient in serverPatients) {
            await _storageService.savePatient(patient);
          }
          final updatedPatients = await _storageService.getPatients();
          setState(() {
            _patients = updatedPatients;
          });
        } else {
          setState(() {
            _patients = patients;
          });
        }
      } catch (e) {
        // Use local data if server is unavailable
        setState(() {
          _patients = patients;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load patients: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupAudioService() {
    _audioService.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _currentSession = session;
        });
      }
    });
  }

  Future<bool> _requestPermissions() async {
    final microphoneStatus = await Permission.microphone.status;
    final microphonePermission = microphoneStatus.isGranted
        ? microphoneStatus
        : await Permission.microphone.request();

    if (!microphonePermission.isGranted) {
      if (mounted) {
        final snackBar = SnackBar(
          content: const Text('Microphone permission is required for recording'),
          backgroundColor: Colors.red,
          action: microphonePermission.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: openAppSettings,
                )
              : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      return false;
    }

    final notificationPermission = await Permission.notification.request();
    if (!notificationPermission.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission is required for background recording'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return true;
  }

  Future<void> _startRecording(Patient patient) async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      return;
    }
    
    try {
      final success = await _audioService.startRecording(patient.id, 'current_user_id');
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started recording for ${patient.name}'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _stopRecording() async {
    try {
      final success = await _audioService.stopRecording();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording stopped and saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      final success = await _audioService.pauseRecording();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording paused'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resumeRecording() async {
    try {
      final success = await _audioService.resumeRecording();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording resumed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume recording: $e'),
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
        title: const Text('AI Scribe Copilot'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPatientScreen(),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No patients found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first patient to start recording consultations',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPatientScreen(),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Patient'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_currentSession != null) _buildRecordingStatus(),
        Expanded(
          child: PatientListWidget(
            patients: _patients,
            onPatientTap: (patient) async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailScreen(patient: patient),
                ),
              );
              _loadData();
            },
            onStartRecording: _startRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _currentSession?.status == RecordingStatus.recording
          ? Colors.red[50]
          : Colors.orange[50],
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _currentSession?.status == RecordingStatus.recording
                    ? Icons.mic
                    : Icons.pause,
                color: _currentSession?.status == RecordingStatus.recording
                    ? Colors.red
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _currentSession?.status == RecordingStatus.recording
                    ? 'Recording in progress'
                    : 'Recording paused',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _currentSession?.status == RecordingStatus.recording
                      ? Colors.red[700]
                      : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AudioVisualizerWidget(),
          const SizedBox(height: 8),
          RecordingControlsWidget(
            isRecording: _audioService.isRecording,
            isPaused: _audioService.isPaused,
            onPause: _pauseRecording,
            onResume: _resumeRecording,
            onStop: _stopRecording,
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_patients.isEmpty) return null;
    
    return FloatingActionButton.extended(
      onPressed: () {
        // Show patient selection dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Patient'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _patients.length,
                itemBuilder: (context, index) {
                  final patient = _patients[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(patient.name[0].toUpperCase()),
                    ),
                    title: Text(patient.name),
                    subtitle: Text(patient.medicalRecordNumber ?? 'No MRN'),
                    onTap: () {
                      Navigator.pop(context);
                      _startRecording(patient);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.mic),
      label: const Text('Start Recording'),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    );
  }
}
