import 'dart:io';

import 'package:aadya_plus/services/consultation_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class VideoCallScreen extends StatefulWidget {
  final String appointmentId;
  final String joinUrl;
  final String doctorName;

  const VideoCallScreen({
    super.key,
    required this.appointmentId,
    required this.joinUrl,
    required this.doctorName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  bool _leaveSent = false;

  @override
  void initState() {
    super.initState();

    // The call page may not navigate away from the meeting's own site, so
    // camera/mic requests can only ever come from the meeting.
    final meetingHost = Uri.tryParse(widget.joinUrl)?.host ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final host = Uri.tryParse(request.url)?.host ?? '';
            return host == meetingHost || host.endsWith('.$meetingHost')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('Consultation WebView error: ${error.description}');
          },
        ),
      );

    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      // Camera and microphone only — anything else the page asks for is
      // refused.
      const allowed = {
        WebViewPermissionResourceType.camera,
        WebViewPermissionResourceType.microphone,
      };
      androidController.setOnPlatformPermissionRequest((request) {
        if (request.types.every(allowed.contains)) {
          request.grant();
        } else {
          request.deny();
        }
      });
    }

    _controller.loadRequest(Uri.parse(widget.joinUrl));
  }

  Future<void> _notifyLeave() async {
    if (_leaveSent) return;
    _leaveSent = true;
    try {
      await ConsultationService.instance.leave(widget.appointmentId);
    } catch (e) {
      debugPrint('Unable to notify consultation leave: $e');
    }
  }

  Future<void> _leaveCall() async {
    await _notifyLeave();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_leaveSent) {
      ConsultationService.instance.leave(widget.appointmentId).catchError((_) {});
      _leaveSent = true;
    }
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Consultation?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Leaving closes the video on this device. The professional controls when the consultation itself is completed.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave Call'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave()) await _leaveCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (await _confirmLeave()) await _leaveCall();
            },
          ),
          title: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.amber : Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctorName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isLoading ? 'Connecting securely...' : 'In consultation',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isLoading ? Colors.amber.shade200 : Colors.greenAccent.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () async {
                  if (await _confirmLeave()) await _leaveCall();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.call_end, size: 16),
                label: const Text('Leave'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                value: _loadingProgress / 100,
                backgroundColor: Colors.grey.shade900,
                valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                minHeight: 2,
              ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
