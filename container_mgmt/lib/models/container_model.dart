class ContainerModel {
  final int containerId;
  final String containerNumber;
  final int statusId;
  final String? type;
  final String? containerDesc;
  final int currentPortId;
  final int? yardId;
  final int? blockId;
  final int? bayId;
  final int? rowId;
  final int? tier;
  final int? locationStatusId;
  final int? truckId;
  final String? boundTo;
  final String createdDate;
  final int? containerSizeId;

  ContainerModel({
    required this.containerId,
    required this.containerNumber,
    required this.statusId,
    this.type,
    this.containerDesc,
    required this.currentPortId,
    this.yardId,
    this.blockId,
    this.bayId,
    this.rowId,
    this.tier,
    this.locationStatusId,
    this.truckId,
    this.boundTo,
    required this.createdDate,
    this.containerSizeId,
  });

  bool get isInYard => yardId != null;
  bool get isMovedOut => locationStatusId == 2;

  factory ContainerModel.fromJson(Map<String, dynamic> json) => ContainerModel(
    containerId: json['containerId'],
    containerNumber: json['containerNumber'],
    statusId: json['statusId'],
    type: json['type'],
    containerDesc: json['containerDesc'],
    currentPortId: json['currentPortId'],
    yardId: json['yardId'],
    blockId: json['blockId'],
    bayId: json['bayId'],
    rowId: json['rowId'],
    tier: json['tier'],
    locationStatusId: json['locationStatusId'],
    truckId: json['truckId'],
    boundTo: json['boundTo'],
    createdDate: json['createdDate'],
    containerSizeId: json['containerSizeId'],
  );
}
