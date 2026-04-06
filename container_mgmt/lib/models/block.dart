class Block {
  final int blockId;
  final int blockNumber;
  final String? blockDesc;
  final String? blockName;
  final int yardId;
  final int portId;
  final int? orientationId;
  final int? sizeId;
  final double? posX;
  final double? posY;
  final double rotation;

  Block({
    required this.blockId,
    required this.blockNumber,
    this.blockDesc,
    this.blockName,
    required this.yardId,
    required this.portId,
    this.orientationId,
    this.sizeId,
    this.posX,
    this.posY,
    this.rotation = 0,
  });

  bool get isVertical => orientationId == 2;
  bool get is40ft => sizeId == 2;

  factory Block.fromJson(Map<String, dynamic> json) => Block(
    blockId: json['blockId'],
    blockNumber: json['blockNumber'],
    blockDesc: json['blockDesc'],
    blockName: json['blockName'],
    yardId: json['yardId'],
    portId: json['portId'],
    orientationId: json['orientationId'],
    sizeId: json['sizeId'],
    posX: (json['posX'] as num?)?.toDouble(),
    posY: (json['posY'] as num?)?.toDouble(),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
  );

  Block copyWith({double? posX, double? posY, double? rotation}) => Block(
    blockId: blockId,
    blockNumber: blockNumber,
    blockDesc: blockDesc,
    blockName: blockName,
    yardId: yardId,
    portId: portId,
    orientationId: orientationId,
    sizeId: sizeId,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    rotation: rotation ?? this.rotation,
  );
}
