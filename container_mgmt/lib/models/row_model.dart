class RowModel {
  final int rowId;
  final int rowNumber;
  final int bayId;

  // Layout fields (merged from Slots)
  final int? sizeId;
  final int? orientationId;
  final int maxStack;
  final bool isDeleted;
  final double? posX;
  final double? posY;

  RowModel({
    required this.rowId,
    required this.rowNumber,
    required this.bayId,
    this.sizeId,
    this.orientationId,
    this.maxStack = 5,
    this.isDeleted = false,
    this.posX,
    this.posY,
  });

  bool get isVertical => orientationId == 2;
  bool get is40ft => sizeId == 2;

  factory RowModel.fromJson(Map<String, dynamic> json) => RowModel(
    rowId: json['rowId'],
    rowNumber: json['rowNumber'],
    bayId: json['bayId'],
    sizeId: json['sizeId'],
    orientationId: json['orientationId'],
    maxStack: json['maxStack'] ?? 5,
    isDeleted: json['isDeleted'] ?? false,
    posX: (json['posX'] as num?)?.toDouble(),
    posY: (json['posY'] as num?)?.toDouble(),
  );
}
