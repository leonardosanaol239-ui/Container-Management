class OrientationModel {
  final int orientationId;
  final String orientationDesc;

  OrientationModel({
    required this.orientationId,
    required this.orientationDesc,
  });

  factory OrientationModel.fromJson(Map<String, dynamic> json) =>
      OrientationModel(
        orientationId: json['orientationId'],
        orientationDesc: json['orientationDesc'],
      );
}
