import 'package:aadya_plus/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:aadya_plus/providers/chat_provider.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:aadya_plus/models/doctor.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('My Chats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20,)),
        backgroundColor: AppConstants.primaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: chatProvider.isLoadingSessions
          ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
          : chatProvider.sessions.isEmpty
              ? const Center(
                  child: Text(
                    'No active chats found.\nBook an appointment to start chatting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppConstants.lightTextColor, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: chatProvider.sessions.length,
                  itemBuilder: (context, index) {
                    final session = chatProvider.sessions[index];
                    final prof = session['professional'];
                    if (prof == null) return const SizedBox.shrink();

                    final profName = prof['name'] ?? 'Doctor';
                    final profImage = prof['profileImage']?.toString() ?? 'https://cdn-icons-png.flaticon.com/512/2785/2785501.png';
                    
                    final specRaw = prof['specialization'] ?? prof['specialty'];
                    String specialty = '';
                    if (specRaw is List) {
                      specialty = specRaw.join(', ');
                    } else if (specRaw != null) {
                      specialty = specRaw.toString();
                    }
                    
                    final lastMessage = session['lastMessage'];
                    final msgText = lastMessage != null ? (lastMessage['content']?.toString() ?? 'Attachment') : 'Tap to start chat';
                    final msgTime = lastMessage != null && lastMessage['createdAt'] != null
                      ? DateFormat('hh:mm a').format(DateTime.parse(lastMessage['createdAt']).toLocal())
                      : '';
                    final unreadCount = lastMessage != null && lastMessage['isRead'] == false && lastMessage['senderType'] != 'patient' ? 1 : 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2), width: 2),
                            ),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(profImage),
                              radius: 26,
                              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  profName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textColor),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (msgTime.isNotEmpty)
                                Text(
                                  msgTime,
                                  style: TextStyle(fontSize: 11, color: unreadCount > 0 ? AppConstants.primaryColor : Colors.grey[500], fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (specialty.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  specialty,
                                  style: TextStyle(fontSize: 11, color: AppConstants.primaryColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msgText,
                                      style: TextStyle(
                                        fontSize: 13, 
                                        color: unreadCount > 0 ? AppConstants.textColor : AppConstants.lightTextColor,
                                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle),
                                      child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            // Mocking the Doctor object locally to interface with ChatScreen
                            final doc = Doctor(
                              id: prof['_id'] ?? session['professionalId'],
                              name: profName,
                              specialty: specialty,
                              hospital: '',
                              rating: 0.0,
                              reviews: 0,
                              consultationFee: 0.0,
                              experience: 0,
                              imageUrl: profImage,
                              description: '',
                              languages: [],
                              availability: {},
                            );
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  doctor: doc,
                                  appointmentId: session['appointmentId'],
                                ),
                              ),
                            ).then((_) {
                              // refresh on back
                              Provider.of<ChatProvider>(context, listen: false).loadSessions();
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}