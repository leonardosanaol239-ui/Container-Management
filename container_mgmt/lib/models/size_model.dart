class SizeModel {
  final int sizeId;
  final String sizeDesc;

  SizeModel({required this.sizeId, required this.sizeDesc});

  factory SizeModel.fromJson(Map<String, dynamic> json) =>
      SizeModel(sizeId: json['sizeId'], sizeDesc: json['sizeDesc']);
}
