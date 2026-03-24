class Yard {
  final int yardId;
  final int yardNumber;
  final int portId;
  final double? yardWidth;
  final double? yardHeight;

  Yard({
    required this.yardId,
    required this.yardNumber,
    required this.portId,
    this.yardWidth,
    this.yardHeight,
  });

  bool get hasLayout => yardWidth != null && yardHeight != null;

  factory Yard.fromJson(Map<String, dynamic> json) => Yard(
    yardId: json['yardId'],
    yardNumber: json['yardNumber'],
    portId: json['portId'],
    yardWidth: (json['yardWidth'] as num?)?.toDouble(),
    yardHeight: (json['yardHeight'] as num?)?.toDouble(),
  );
}
