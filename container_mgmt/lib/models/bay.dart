class Bay {
  final int bayId;
  final String bayNumber;
  final int blockId;

  Bay({required this.bayId, required this.bayNumber, required this.blockId});

  factory Bay.fromJson(Map<String, dynamic> json) => Bay(
    bayId: json['bayId'],
    bayNumber: json['bayNumber'],
    blockId: json['blockId'],
  );
}
