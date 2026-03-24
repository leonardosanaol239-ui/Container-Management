import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/port.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../models/size_model.dart';
import '../models/orientation_model.dart';
import '../models/truck.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.118.132:5000/api';

  // ── Ports ────────────────────────────────────────────────
  Future<List<Port>> getPorts() async {
    final res = await http.get(Uri.parse('$baseUrl/Ports'));
    _check(res);
    return (jsonDecode(res.body) as List).map((e) => Port.fromJson(e)).toList();
  }

  // ── Yards ────────────────────────────────────────────────
  Future<List<Yard>> getYards(int portId) async {
    final res = await http.get(Uri.parse('$baseUrl/Yards?portId=$portId'));
    _check(res);
    return (jsonDecode(res.body) as List).map((e) => Yard.fromJson(e)).toList();
  }

  // ── Blocks ──────────────────────────────────────────────
  Future<List<Block>> getBlocks(int yardId) async {
    final res = await http.get(Uri.parse('$baseUrl/Blocks?yardId=$yardId'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => Block.fromJson(e))
        .toList();
  }

  // ── Bays ────────────────────────────────────────────────
  Future<List<Bay>> getBays(int blockId) async {
    final res = await http.get(Uri.parse('$baseUrl/Bays?blockId=$blockId'));
    _check(res);
    return (jsonDecode(res.body) as List).map((e) => Bay.fromJson(e)).toList();
  }

  // ── Rows ────────────────────────────────────────────────
  Future<List<RowModel>> getRows(int bayId) async {
    final res = await http.get(Uri.parse('$baseUrl/Rows?bayId=$bayId'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => RowModel.fromJson(e))
        .toList();
  }

  // ── Containers ──────────────────────────────────────────
  Future<List<ContainerModel>> getContainersByPort(int portId) async {
    final res = await http.get(Uri.parse('$baseUrl/Containers?portId=$portId'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => ContainerModel.fromJson(e))
        .toList();
  }

  Future<List<ContainerModel>> getContainersByLocation({
    int? yardId,
    int? blockId,
    int? bayId,
    int? rowId,
  }) async {
    final params = <String, String>{};
    if (yardId != null) params['yardId'] = '$yardId';
    if (blockId != null) params['blockId'] = '$blockId';
    if (bayId != null) params['bayId'] = '$bayId';
    if (rowId != null) params['rowId'] = '$rowId';
    final uri = Uri.parse(
      '$baseUrl/Containers/location',
    ).replace(queryParameters: params);
    final res = await http.get(uri);
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => ContainerModel.fromJson(e))
        .toList();
  }

  Future<ContainerModel?> searchContainer(String containerNumber) async {
    final res = await http.get(
      Uri.parse('$baseUrl/Containers/search?containerNumber=$containerNumber'),
    );
    if (res.statusCode == 404) return null;
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<ContainerModel> createContainer({
    required int statusId,
    required String type,
    required String desc,
    required int portId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Containers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'statusId': statusId,
        'type': type,
        'containerDesc': desc,
        'currentPortId': portId,
      }),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<ContainerModel> moveContainer({
    required int containerId,
    required int yardId,
    required int blockId,
    required int bayId,
    required int rowId,
    required int tier,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Containers/$containerId/location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'yardId': yardId,
        'blockId': blockId,
        'bayId': bayId,
        'rowId': rowId,
        'tier': tier,
      }),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<ContainerModel> removeContainerFromSlot(int containerId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Containers/$containerId/location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'yardId': null,
        'blockId': null,
        'bayId': null,
        'rowId': null,
        'tier': null,
      }),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  // ── Trucks ───────────────────────────────────────────────
  Future<List<Truck>> getTrucks() async {
    final res = await http.get(Uri.parse('$baseUrl/Trucks'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => Truck.fromJson(e))
        .toList();
  }

  // ── Move Out ─────────────────────────────────────────────
  Future<ContainerModel> moveOutContainer({
    required int containerId,
    required int truckId,
    required String boundTo,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Containers/$containerId/moveout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'truckId': truckId, 'boundTo': boundTo}),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<List<ContainerModel>> getMovedOutContainers(int portId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/Containers/movedout?portId=$portId'),
    );
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => ContainerModel.fromJson(e))
        .toList();
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }

  // ── Layout ───────────────────────────────────────────────
  Future<List<SizeModel>> getSizes() async {
    final res = await http.get(Uri.parse('$baseUrl/Layout/sizes'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => SizeModel.fromJson(e))
        .toList();
  }

  Future<List<OrientationModel>> getOrientations() async {
    final res = await http.get(Uri.parse('$baseUrl/Layout/orientations'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => OrientationModel.fromJson(e))
        .toList();
  }

  Future<Block> createBlock({
    required int yardId,
    required int portId,
    required String blockName,
    required int numBays,
    required int numRows,
    required int orientationId,
    required int sizeId,
    required int maxStack,
    double posX = 0,
    double posY = 0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Layout/blocks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'yardId': yardId,
        'portId': portId,
        'blockName': blockName,
        'numBays': numBays,
        'numRows': numRows,
        'orientationId': orientationId,
        'sizeId': sizeId,
        'maxStack': maxStack,
        'posX': posX,
        'posY': posY,
      }),
    );
    _check(res);
    return Block.fromJson(jsonDecode(res.body));
  }

  Future<Block> updateBlockPosition(
    int blockId,
    double posX,
    double posY,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/position'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'posX': posX, 'posY': posY}),
    );
    _check(res);
    return Block.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteBlock(int blockId) async {
    final res = await http.delete(Uri.parse('$baseUrl/Layout/blocks/$blockId'));
    _check(res);
  }

  Future<void> addBay(int blockId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/bays'),
    );
    _check(res);
  }

  Future<void> removeBay(int blockId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/bays'),
    );
    _check(res);
  }

  Future<void> addRow(int blockId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/rows'),
    );
    _check(res);
  }

  Future<void> removeRow(int blockId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/rows'),
    );
    _check(res);
  }

  Future<RowModel> updateRow(
    int rowId, {
    int? sizeId,
    int? orientationId,
    int? maxStack,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Layout/rows/$rowId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (sizeId != null) 'sizeId': sizeId,
        if (orientationId != null) 'orientationId': orientationId,
        if (maxStack != null) 'maxStack': maxStack,
      }),
    );
    _check(res);
    return RowModel.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteRow(int rowId) async {
    final res = await http.delete(Uri.parse('$baseUrl/Layout/rows/$rowId'));
    _check(res);
  }
}
