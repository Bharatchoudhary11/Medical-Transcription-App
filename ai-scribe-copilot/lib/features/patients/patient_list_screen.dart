import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/user_constants.dart';
import '../../core/models/patient.dart';
import '../../core/network/api_endpoints.dart';
import '../../shared/providers.dart';

final _patientListProvider = FutureProvider<List<Patient>>((ref) async {
  final patientService = ref.watch(patientServiceProvider);
  return patientService.fetchPatients(UserConstants.demoUserId);
});

class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key, this.viewSessionsOnly = false});

  final bool viewSessionsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(_patientListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(viewSessionsOnly ? 'Patient History' : 'Select Patient'),
      ),
      body: patients.when(
        data: (data) => ListView.separated(
          itemBuilder: (context, index) {
            final patient = data[index];
            return ListTile(
              title: Text(patient.name),
              subtitle: patient.dateOfBirth != null
                  ? Text('DOB: ${patient.dateOfBirth!.toLocal().toShortString()}')
                  : null,
              trailing: viewSessionsOnly ? const Icon(Icons.chevron_right) : null,
              onTap: viewSessionsOnly
                  ? () {
                      // Future enhancement: navigate to sessions list.
                    }
                  : () => Navigator.of(context).pop(patient),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: data.length,
        ),
        error: (error, stackTrace) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final baseUrl = ApiEndpoints.baseUrl;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load patients',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The app could not reach the backend at $baseUrl.\n'
                        '• Make sure the API server is running (e.g. `docker-compose up -d`).\n'
                        '• If you are testing on a physical device, replace 10.0.2.2 with your computer\'s LAN IP and rebuild with:\n'
                        '  flutter run --dart-define=API_BASE_URL=http://<your-ip>:3000/api\n'
                        '• On IPv6 networks you can provide the components separately instead:\n'
                        '  flutter run --dart-define=API_HOST=<ipv6-host> --dart-define=API_PORT=3000 --dart-define=API_PATH=api',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Details: $error',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(_patientListProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: viewSessionsOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                _showAddPatientDialog(context, ref);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add patient'),
            ),
    );
  }

  Future<void> _showAddPatientDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final mrnController = TextEditingController();
    DateTime? dob;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New patient'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mrnController,
                      decoration: const InputDecoration(labelText: 'MRN (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(dob == null
                            ? 'DOB not set'
                            : 'DOB: ${dob!.toLocal().toShortString()}'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: DateTime(now.year - 30),
                              firstDate: DateTime(now.year - 120),
                              lastDate: now,
                            );
                            if (selected != null) {
                              setState(() {
                                dob = selected;
                              });
                            }
                          },
                          child: const Text('Set DOB'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final patientService = ref.read(patientServiceProvider);
                      await patientService.addPatient(
                        name: nameController.text,
                        dateOfBirth: dob,
                        mrn: mrnController.text.isEmpty ? null : mrnController.text,
                        userId: UserConstants.demoUserId,
                      );
                      ref.invalidate(_patientListProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension on DateTime {
  String toShortString() => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
