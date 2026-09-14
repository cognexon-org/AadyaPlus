import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/chat_provider.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/models/chat_message.dart';
import 'package:aadya_plus/models/doctor.dart';
import 'package:intl/intl.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/screens/appointments/appointment_details_screen.dart';
import 'package:aadya_plus/models/appointment.dart';

class ChatScreen extends StatefulWidget {
  final Doctor doctor;
  final String? appointmentId;

  const ChatScreen({super.key, required this.doctor, this.appointmentId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Appointment? _currentAppointment;
  bool _isLoadingAppointment = false;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.loadChatMessages(
      widget.doctor.id,
      professionalType: widget.doctor.professionalType,
      appointmentId: widget.appointmentId,
    );
    
    if (widget.appointmentId != null) {
      _loadAppointmentContext();
    }
  }

  Future<void> _loadAppointmentContext() async {
    setState(() => _isLoadingAppointment = true);
    final aptProvider = Provider.of<AppointmentProvider>(context, listen: false);
    
    // Try to find it immediately
    try {
      _currentAppointment = aptProvider.appointments.firstWhere((a) => a.id == widget.appointmentId);
    } catch (_) {
      // Not found locally? Load appointments from server
      await aptProvider.loadAppointments();
      try {
        _currentAppointment = aptProvider.appointments.firstWhere((a) => a.id == widget.appointmentId);
      } catch (_) {
        // Still not found, might belong to past that isn't paginated, or just an edge case.
      }
    }
    
    if (mounted) {
      setState(() => _isLoadingAppointment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppConstants.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[200]!, width: 2),
              ),
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.doctor.imageUrl),
                radius: 18,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctor.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online',
                    style: TextStyle(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.appointmentId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppConstants.textColor),
              onSelected: (value) {
                if (value == 'appointment_details') {
                  if (_currentAppointment != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentDetailsScreen(appointment: _currentAppointment!),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not load appointment details. Please check My Appointments tab.')),
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'appointment_details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('ID: ${widget.appointmentId}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  reverse: false,
                  itemCount: chatProvider.messages.length + 1, // +1 for the context card
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildAppointmentContextCard();
                    }
                    
                    final message = chatProvider.messages[index - 1];
                    final authUser = Provider.of<AuthProvider>(context, listen: false).user;
                    final myId = authUser?.profileId ?? authUser?.id;
                    final isUser = message.senderId == myId;
                    
                    return _buildMessageBubble(message, isUser);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAppointmentContextCard() {
    if (widget.appointmentId == null) return const SizedBox.shrink();
    if (_isLoadingAppointment) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_currentAppointment == null) return const SizedBox.shrink();

    final apt = _currentAppointment!;
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(apt.dateTime.toLocal());
    final timeStr = DateFormat('hh:mm a').format(apt.dateTime.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month, color: AppConstants.primaryColor.withOpacity(0.8), size: 28),
          const SizedBox(height: 8),
          Text('Consultation Chat', style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 6),
          Text('$dateStr • $timeStr', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
          if (apt.appointmentType.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Type: ${apt.appointmentType.toUpperCase()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ]
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.doctor.imageUrl),
                  radius: 14,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppConstants.primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isUser ? null : Border.all(color: Colors.grey[100]!),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppConstants.textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 28), // Space for timing below or alignment
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 40,
              right: isUser ? 8 : 0,
            ),
            child: Text(
              DateFormat('hh:mm a').format(message.timestamp.toLocal()),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppConstants.primaryColor),
              onPressed: _showAttachmentOptions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppConstants.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                // Implement image attachment
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                // Implement document attachment
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_information),
              title: const Text('Prescription'),
              onTap: () {
                Navigator.pop(context);
                // Implement prescription attachment
              },
            ),
          ],
        );
      },
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(
      message: _messageController.text.trim(),
      type: MessageType.text,
    );

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    Provider.of<ChatProvider>(context, listen: false).disconnectSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}