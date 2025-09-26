class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.mrn,
  });

  final String id;
  final String name;
  final DateTime? dateOfBirth;
  final String? mrn;

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'].toString(),
      name: json['name'] as String,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      mrn: json['mrn'] as String?,
    );
  }
}
