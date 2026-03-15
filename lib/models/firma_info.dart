class FirmaInfo {
  final String emri;
  final String description;
  final String nrTel;

  const FirmaInfo({
    required this.emri,
    required this.description,
    required this.nrTel,
  });

  factory FirmaInfo.empty() {
    return const FirmaInfo(
      emri: '',
      description: '',
      nrTel: '',
    );
  }

  FirmaInfo copyWith({
    String? emri,
    String? description,
    String? nrTel,
  }) {
    return FirmaInfo(
      emri: emri ?? this.emri,
      description: description ?? this.description,
      nrTel: nrTel ?? this.nrTel,
    );
  }
}
