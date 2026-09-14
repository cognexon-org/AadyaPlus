import 'dart:convert';

import 'package:aadya_plus/models/chat_message.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/services/secure_storage_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  List<dynamic> _sessions = [];
  bool _isLoading = false;
  bool _isLoadingSessions = false;
  IO.Socket? _socket;
  String? _sessionId;
  String? _error;

  List<ChatMessage> get messages => _messages;
  List<dynamic> get sessions => _sessions;
  bool get isLoading => _isLoading;
  bool get isLoadingSessions => _isLoadingSessions;
  String? get error => _error;

  Future<String?> _getToken() => SecureStorageService.instance.readToken();

  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) return;

      final res = await http.get(
        http.apiUri('/chat/patient/sessions'),
      );
      final data = _decode(res.body);
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          data['success'] == true) {
        _sessions = data['sessions'] is List ? data['sessions'] : [];
      } else {
        throw Exception(data['error'] ?? data['message'] ?? 'Unable to load chats');
      }
    } catch (e) {
      _error = _cleanError(e);
      debugPrint('Error loading chat sessions: $e');
    } finally {
      _isLoadingSessions = false;
      notifyListeners();
    }
  }

  Future<void> loadChatMessages(
    String professionalId, {
    String professionalType = 'doctor',
    String? appointmentId,
  }) async {
    _isLoading = true;
    _messages = [];
    _error = null;
    Future.microtask(notifyListeners);

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Authentication required');

      // Backend B1 derives the patient identity from the authenticated JWT.
      // The client supplies only the intended professional/relationship.
      final res = await http.post(
        http.apiUri('/chat/session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'professionalId': professionalId,
          'professionalType': professionalType,
          if (appointmentId != null && appointmentId.isNotEmpty)
            'appointmentId': appointmentId,
        }),
      );

      final data = _decode(res.body);
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(
          data['error'] ?? data['message'] ?? 'Unable to open secure chat',
        );
      }

      final session = data['session'];
      if (session is! Map || session['_id'] == null) {
        throw Exception('Chat session response is invalid');
      }
      _sessionId = session['_id'].toString();

      final historyRes = await http.get(
        http.apiUri('/chat/session/$_sessionId/messages'),
      );
      final historyData = _decode(historyRes.body);
      if (historyRes.statusCode < 200 ||
          historyRes.statusCode >= 300 ||
          historyData['success'] != true) {
        throw Exception(
          historyData['error'] ??
              historyData['message'] ??
              'Unable to load chat history',
        );
      }

      final rows = historyData['messages'] is List
          ? historyData['messages'] as List
          : const [];
      _messages = rows.whereType<Map>().map((raw) {
        final message = Map<String, dynamic>.from(raw);
        final senderRaw = message['senderId'];
        final senderId = senderRaw is Map
            ? (senderRaw['_id'] ?? '').toString()
            : (senderRaw ?? '').toString();
        return ChatMessage(
          id: (message['_id'] ?? '').toString(),
          senderId: senderId,
          receiverId: '',
          message: (message['content'] ?? '').toString(),
          timestamp: DateTime.tryParse(
                    (message['createdAt'] ?? '').toString(),
                  )?.toLocal() ??
              DateTime.now(),
          isRead: message['isRead'] == true,
          type: MessageType.text,
        );
      }).toList();

      _connectSocket(token, _sessionId!);
    } catch (e) {
      _error = _cleanError(e);
      debugPrint('Error loading chat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _connectSocket(String token, String sessionId) {
    disconnectSocket();

    _socket = IO.io(
      AppConstants.socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Patient App: authenticated socket connected');
      _socket!.emit('join_chat', {'sessionId': sessionId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('Patient App: socket disconnected');
    });
    _socket!.onConnectError((error) {
      _error = 'Secure chat connection failed';
      debugPrint('Patient App: socket connect error: $error');
      notifyListeners();
    });
    _socket!.on('chat_error', (data) {
      final message = data is Map ? data['error'] : data;
      _error = (message ?? 'Chat request failed').toString();
      debugPrint('Patient App: secure chat error: $_error');
      notifyListeners();
    });

    _socket!.on('receive_message', (data) {
      try {
        final msgData = data is String
            ? Map<String, dynamic>.from(jsonDecode(data) as Map)
            : Map<String, dynamic>.from(data as Map);

        final senderRaw = msgData['senderId'];
        final senderId = senderRaw is Map
            ? (senderRaw['_id'] ?? '').toString()
            : (senderRaw ?? '').toString();

        final id = (msgData['_id'] ?? '').toString();
        final isDuplicate = _messages.any(
          (message) => id.isNotEmpty && message.id == id,
        );
        if (isDuplicate) return;

        _messages.add(
          ChatMessage(
            id: id.isEmpty
                ? DateTime.now().microsecondsSinceEpoch.toString()
                : id,
            senderId: senderId,
            receiverId: '',
            message: (msgData['content'] ?? '').toString(),
            timestamp: DateTime.tryParse(
                      (msgData['createdAt'] ?? '').toString(),
                    )?.toLocal() ??
                DateTime.now(),
            isRead: msgData['isRead'] == true,
            type: MessageType.text,
          ),
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Patient chat socket parse error: $e');
      }
    });

    _socket!.connect();
  }

  void sendMessage({
    required String message,
    MessageType type = MessageType.text,
  }) {
    final sessionId = _sessionId;
    final socket = _socket;
    final content = message.trim();
    if (socket == null || sessionId == null || content.isEmpty) return;

    // SECURITY: senderId/senderType are intentionally absent. Backend B1
    // derives both values from the authenticated Socket.IO JWT handshake.
    socket.emit('send_message', {
      'sessionId': sessionId,
      'content': content,
      'messageType': type == MessageType.text ? 'text' : 'text',
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _sessionId = null;
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
