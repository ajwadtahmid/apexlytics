import '../constants/api_constants.dart';
import '../models/map_rotation.dart';
import '../utils/error_messages.dart' show MalformedResponseException;
import 'api_service.dart';

/// [body] as a map rotation, or a [MalformedResponseException] when it is not
/// one. A `200` that carries the upstream's own `{"Error": ...}`, an empty
/// object or an intermediary's page would otherwise read as a rotation with
/// every mode unknown, which cancels every alert and stops the refresh loop.
/// Shared with the background alert job, which does its own request.
MapRotation parseMapRotation(Object? body) {
  if (body is Map<String, dynamic> &&
      !body.containsKey('Error') &&
      !body.containsKey('error') &&
      (body['battle_royale'] is Map || body['ranked'] is Map)) {
    return MapRotation.fromJson(body);
  }
  throw const MalformedResponseException(
    "Couldn't read the map rotation from the server's reply. "
    'Try again in a moment.',
  );
}

class MapService {
  final ApiService _api;
  MapService(this._api);

  Future<ApiResult<MapRotation>> getMapRotation() async {
    // Map rotation contains live countdown timers — always fetch fresh.
    final result = await _api.get(
      ApiConstants.mapRotationPath,
      params: {'version': ApiConstants.mapRotationVersion},
      noCache: true,
    );
    return ApiResult(parseMapRotation(result.data));
  }
}
