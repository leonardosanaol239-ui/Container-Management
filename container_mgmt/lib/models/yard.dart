class Yard {
  final int yardId;
  final int yardNumber;
  final int portId;
  final double? yardWidth;
  final double? yardHeight;
  final String? imagePath;

  Yard({
    required this.yardId,
    required this.yardNumber,
    required this.portId,
    this.yardWidth,
    this.yardHeight,
    this.imagePath,
  });

  bool get hasLayout => yardWidth != null && yardHeight != null;

  factory Yard.fromJson(Map<String, dynamic> json) => Yard(
    yardId: json['yardId'],
    yardNumber: json['yardNumber'],
    portId: json['portId'],
    yardWidth: (json['yardWidth'] as num?)?.toDouble(),
    yardHeight: (json['yardHeight'] as num?)?.toDouble(),
    imagePath: json['imagePath'] as String?,
  );
}
