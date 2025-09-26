import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/patient.dart';
import '../../shared/providers.dart';

final _patientListProvider = FutureProvider<List<Patient>>((ref) async {
  final patientService = ref.watch(patientServiceProvider);
  const demoUserId = 'demo-user';
  return patientService.fetchPatients(demoUserId);
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
        error: (error, stackTrace) => Center(
          child: Text('Failed to load patients: $error'),
        ),
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
