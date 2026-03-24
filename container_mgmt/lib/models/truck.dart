class Truck {
  final int truckId;
  final String truckName;

  Truck({required this.truckId, required this.truckName});

  factory Truck.fromJson(Map<String, dynamic> json) =>
      Truck(truckId: json['truckId'], truckName: json['truckName']);
}
