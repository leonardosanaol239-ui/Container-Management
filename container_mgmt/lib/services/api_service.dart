import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/port.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../models/size_model.dart';
import '../models/orientation_model.dart';
import '../models/truck.dart';
import '../models/user_model.dart';
import '../models/session.dart';
import '../models/customer_model.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

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

  Future<Yard> createYard(
    int portId, {
    double width = 300,
    double height = 170,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Yards'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'portId': portId,
        'yardWidth': width,
        'yardHeight': height,
      }),
    );
    _check(res);
    return Yard.fromJson(jsonDecode(res.body));
  }

  Future<Yard?> getYardById(int yardId) async {
    final res = await http.get(Uri.parse('$baseUrl/Yards/$yardId'));
    if (res.statusCode == 404) return null;
    _check(res);
    return Yard.fromJson(jsonDecode(res.body));
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
    required int containerSizeId,
    required String desc,
    required int portId,
    int? customerId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Containers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'statusId': statusId,
        'type': containerSizeId == 1 ? '20ft' : '40ft',
        'containerSizeId': containerSizeId,
        'containerDesc': desc,
        'currentPortId': portId,
        if (customerId != null) 'customerId': customerId,
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
    int? locationStatusId,
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
        if (locationStatusId != null) 'locationStatusId': locationStatusId,
      }),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<ContainerModel> confirmMoveRequest(int containerId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Containers/$containerId/locationstatus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'locationStatusId': 1}),
    );
    _check(res);
    return ContainerModel.fromJson(jsonDecode(res.body));
  }

  Future<ContainerModel> setMoveRequest(int containerId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Containers/$containerId/locationstatus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'locationStatusId': 3}),
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

  // ── Auth ─────────────────────────────────────────────────
  /// Returns the logged-in [Session] or throws with a user-facing message.
  Future<Session> login({
    required String userCode,
    required String password,
    required int userTypeId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userCode': userCode.trim(),
          'password': password,
          'userTypeId': userTypeId,
        }),
      );
      if (res.statusCode == 200) {
        return Session.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      // Parse error message from API (401, 400, etc.)
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(body['message'] ?? 'Login failed.');
      } catch (inner) {
        if (inner is Exception) rethrow;
        throw Exception('Login failed (${res.statusCode}).');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(
        'Could not reach the server. Please check your connection.',
      );
    }
  }

  // ── Customers ────────────────────────────────────────────
  Future<List<CustomerModel>> getCustomers() async {
    final res = await http.get(Uri.parse('$baseUrl/Customers'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => CustomerModel.fromJson(e))
        .toList();
  }

  // ── Users ────────────────────────────────────────────────
  Future<List<UserModel>> getUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/Users'));
    _check(res);
    return (jsonDecode(res.body) as List)
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> createUser(UserModel user) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user.toJson()),
    );
    if (res.statusCode == 409) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'User code already taken');
    }
    _check(res);
    return UserModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(UserModel user) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Users/${user.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user.toJson()),
    );
    if (res.statusCode == 409) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'User code already taken');
    }
    _check(res);
    return UserModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Soft-delete: sets StatusId = 5 (Deleted) instead of removing the row
  Future<UserModel> deleteUser(int userId, UserModel user) async {
    final softDeleted = user.copyWith(statusId: userStatusDeleted);
    final res = await http.put(
      Uri.parse('$baseUrl/Users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(softDeleted.toJson()),
    );
    _check(res);
    return UserModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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

  Future<void> updateBlockRotation(int blockId, double rotation) async {
    final res = await http.put(
      Uri.parse('$baseUrl/Layout/blocks/$blockId/rotation'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rotation': rotation}),
    );
    _check(res);
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

  Future<String> uploadYardImage(
    int yardId,
    List<int> bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$baseUrl/Yards/$yardId/image');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', filename.split('.').last),
        ),
      );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _check(res);
    return (jsonDecode(res.body) as Map)['imagePath'] as String;
  }
}
