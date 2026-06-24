import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:server_module/server_module.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

abstract class MatchingRemoteDataSource {
  Future<BaseResponse<dynamic>> getMatchingSessions({
    String? sportId,
    String? facilityId,
    String? bookingDate,
    int? neededSpots,
  });

  Future<BaseResponse<dynamic>> getMatchingSessionDetail(String id);

  Future<BaseResponse<dynamic>> createMatchingSession(
    Map<String, dynamic> data,
  );

  Future<BaseResponse<dynamic>> joinMatchingSession(
    String id, {
    Map<String, dynamic>? data,
  });

  Future<BaseResponse<dynamic>> leaveMatchingSession(String id);

  Future<BaseResponse<dynamic>> updateMemberStatus(
    String id,
    String userId,
    String status,
  );

  Future<BaseResponse<dynamic>> updateSessionStatus(String id, String status);

  Future<BaseResponse<dynamic>> joinQueue(Map<String, dynamic> data);

  Future<BaseResponse<dynamic>> leaveQueue();

  Future<BaseResponse<dynamic>> getQueueStatus();

  // Socket.IO
  void connectSocket(String token);
  void disconnectSocket();
  void joinMatchingRoom(String sessionId);
  void leaveMatchingRoom(String sessionId);
  Stream<Map<String, dynamic>> get matchingSessionUpdates;
}

class MatchingRemoteDataSourceImpl implements MatchingRemoteDataSource {
  final DioClient _dioClient;
  io.Socket? _socket;
  final _matchingUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  MatchingRemoteDataSourceImpl(this._dioClient);

  @override
  Stream<Map<String, dynamic>> get matchingSessionUpdates =>
      _matchingUpdatesController.stream;

  @override
  void connectSocket(String token) {
    if (_socket != null && _socket!.connected) return;

    try {
      final baseUri = Uri.parse(ApiConfig.baseUrl);
      final socketUrl = '${baseUri.scheme}://${baseUri.host}:${baseUri.port}';

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[Socket.IO] Connected to Matchmaking Hub');
      });

      _socket!.onDisconnect((_) {
        debugPrint('[Socket.IO] Disconnected from Matchmaking Hub');
      });

      _socket!.on('matching_session_updated', (data) {
        debugPrint('[Socket.IO] matching_session_updated: $data');
        if (data is Map<String, dynamic>) {
          _matchingUpdatesController.add(data);
        } else if (data is Map) {
          _matchingUpdatesController.add(Map<String, dynamic>.from(data));
        }
      });
    } catch (e) {
      debugPrint('[Socket.IO] Error connecting socket: $e');
    }
  }

  @override
  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }

  @override
  void joinMatchingRoom(String sessionId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_matching_room', {'matchingSessionId': sessionId});
      debugPrint('[Socket.IO] Emitted join_matching_room for: $sessionId');
    }
  }

  @override
  void leaveMatchingRoom(String sessionId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_matching_room', {'matchingSessionId': sessionId});
      debugPrint('[Socket.IO] Emitted leave_matching_room for: $sessionId');
    }
  }

  @override
  Future<BaseResponse<dynamic>> getMatchingSessions({
    String? sportId,
    String? facilityId,
    String? bookingDate,
    int? neededSpots,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sportId != null) queryParams['sportId'] = sportId;
      if (facilityId != null) queryParams['facilityId'] = facilityId;
      if (bookingDate != null) queryParams['bookingDate'] = bookingDate;
      if (neededSpots != null) queryParams['neededSpots'] = neededSpots;

      final response = await _dioClient.dio.get(
        '/matching',
        queryParameters: queryParams,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> getMatchingSessionDetail(String id) async {
    try {
      final response = await _dioClient.dio.get('/matching/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> createMatchingSession(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.dio.post('/matching', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> joinMatchingSession(
    String id, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/matching/$id/join',
        data: data,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> leaveMatchingSession(String id) async {
    try {
      final response = await _dioClient.dio.post('/matching/$id/leave');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> updateMemberStatus(
    String id,
    String userId,
    String status,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        '/matching/$id/members/$userId',
        data: {'status': status},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> updateSessionStatus(
    String id,
    String status,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        '/matching/$id/status',
        data: {'status': status},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> joinQueue(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post(
        '/matching/queue/join',
        data: data,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> leaveQueue() async {
    try {
      final response = await _dioClient.dio.post('/matching/queue/leave');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> getQueueStatus() async {
    try {
      final response = await _dioClient.dio.get('/matching/queue/status');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}
