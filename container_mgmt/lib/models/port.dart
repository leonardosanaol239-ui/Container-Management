class Port {
  final int portId;
  final String portDesc;

  Port({required this.portId, required this.portDesc});

  factory Port.fromJson(Map<String, dynamic> json) =>
      Port(portId: json['portId'], portDesc: json['portDesc']);
}
