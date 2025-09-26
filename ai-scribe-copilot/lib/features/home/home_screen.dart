import 'package:flutter/material.dart';

import '../patients/patient_list_screen.dart';
import '../recording/screens/recording_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Scribe Copilot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture every word even when the day gets chaotic.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final patient = await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PatientListScreen(),
                ));
                if (patient != null && context.mounted) {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RecordingScreen(patient: patient),
                  ));
                }
              },
              icon: const Icon(Icons.mic),
              label: const Text('Start new consultation'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PatientListScreen(viewSessionsOnly: true),
                ));
              },
              icon: const Icon(Icons.people_alt_outlined),
              label: const Text('Patients & history'),
            ),
            const Spacer(),
            Text(
              "The recorder is resilient to network drops, phone calls, and backgrounding. Keep caring for patients—we'll keep recording.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
