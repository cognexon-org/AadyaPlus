import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/models/chat_message.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  List<dynamic> _sessions = [];
  bool _isLoading = false;
  bool _isLoadingSessions = false;
  IO.Socket? _socket;
  String? _sessionId;
  String? _currentPatientId;

  List<ChatMessage> get messages => _messages;
  List<dynamic> get sessions => _sessions;
  bool get isLoading => _isLoading;
  bool get isLoadingSessions => _isLoadingSessions;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/chat/patient/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = json.decode(res.body);
      if (data['success'] == true) {
        _sessions = data['sessions'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }

    _isLoadingSessions = false;
    notifyListeners();
  }

  Future<void> loadChatMessages(String professionalId, {String? appointmentId}) async {
    _isLoading = true;
    _messages = [];
    Future.microtask(() => notifyListeners());

    try {
      final token = await _getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString(AppConstants.userKey);
      if (userDataStr == null) return;
      final userData = json.decode(userDataStr);
      _currentPatientId = userData['profileId'] ?? userData['id'] ?? userData['_id'];

      // 1. Create or Get Session
      final url = Uri.parse('${AppConstants.chatUrl}/session');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'patientId': _currentPatientId,
          'professionalId': professionalId,
          'professionalType': 'doctor', // Assuming doctor for now
          if (appointmentId != null) 'appointmentId': appointmentId,
        }),
      );

      final data = json.decode(res.body);
      if (data['success'] == true) {
        _sessionId = data['session']['_id'];

        // 2. Fetch history
        final historyRes = await http.get(
          Uri.parse('${AppConstants.chatUrl}/session/$_sessionId/messages'),
          headers: {'Authorization': 'Bearer $token'},
        );
        
        final historyData = json.decode(historyRes.body);
        if (historyData['success'] == true) {
          final msgs = List.from(historyData['messages']);
          _messages = msgs.map((m) => ChatMessage(
            id: m['_id'] ?? '',
            senderId: m['senderId'] ?? '',
            receiverId: '', // not strictly needed for UI here
            message: m['content'] ?? '',
            timestamp: m['createdAt'] != null ? DateTime.parse(m['createdAt']) : DateTime.now(),
            isRead: m['isRead'] ?? false,
            type: MessageType.text,
          )).toList();
        }

        // 3. Connect Socket
        _connectSocket(token, _sessionId!);
      }
    } catch (e) {
      print('Error loading chat: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _connectSocket(String token, String sessionId) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    final uri = Uri.parse(AppConstants.baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

    _socket = IO.io(socketUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build());

    _socket!.onConnect((_) {
      print('Patient App: Socket connected!');
      _socket!.emit('join_chat', {'sessionId': sessionId});
    });

    _socket!.onDisconnect((_) => print('Patient App: Socket disconnected.'));
    _socket!.onConnectError((err) => print('Patient App: Socket ConnectError: $err'));
    _socket!.onError((err) => print('Patient App: Socket Error: $err'));

    _socket!.on('receive_message', (data) {
      debugPrint('Patient App: New message received: $data');
      try {
        Map<String, dynamic> msgData;
        if (data is String) {
           msgData = Map<String, dynamic>.from(jsonDecode(data));
        } else {
           msgData = Map<String, dynamic>.from(data);
        }

        final senderRaw = msgData['senderId'];
        final senderId = senderRaw is Map ? (senderRaw['_id'] ?? '') : (senderRaw?.toString() ?? '');

        // Deduplicate
        final isDuplicate = _messages.any((m) => 
          (m.id.isNotEmpty && m.id == msgData['_id']) ||
          (m.message == msgData['content'] && m.senderId == senderId &&
           DateTime.now().difference(m.timestamp).inSeconds < 2)
        );

        if (!isDuplicate) {
          final msg = ChatMessage(
            id: msgData['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: senderId,
            receiverId: '',
            message: msgData['content'] ?? '',
            timestamp: msgData['createdAt'] != null ? DateTime.parse(msgData['createdAt']) : DateTime.now(),
            isRead: false,
            type: MessageType.text,
          );
          _messages.add(msg);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Patient Chat socket parse error: $e');
      }
    });

    _socket!.connect();
  }

  void sendMessage({
    required String doctorId,
    required String message,
    required MessageType type,
  }) {
    if (_socket == null || _sessionId == null) return;
    
    final payload = {
      'sessionId': _sessionId,
      'senderId': _currentPatientId,
      'senderType': 'patient',
      'content': message,
      'messageType': 'text',
    };

    _socket!.emit('send_message', payload);
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _sessionId = null;
  }
}