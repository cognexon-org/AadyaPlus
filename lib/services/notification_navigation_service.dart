import 'package:aadya_plus/screens/appointments/appointments_screen.dart';
import 'package:aadya_plus/screens/chat/chat_list_screen.dart';
import 'package:aadya_plus/screens/notifications/notifications_screen.dart';
import 'package:aadya_plus/screens/pathology/pathology_screen.dart';
import 'package:aadya_plus/screens/payments/payments_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_order_details_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_orders_screen.dart';
import 'package:aadya_plus/screens/prescriptions/prescriptions_screen.dart';
import 'package:aadya_plus/screens/physiotherapy/physio_exercise_plan_detail_screen.dart';
import 'package:flutter/material.dart';

/// Central deep-link router for in-app and push notifications.
///
/// The backend can send `type`, `relatedEntity`, `relatedEntityId` and/or
/// domain IDs in the notification data payload. We intentionally route to a
/// safe authenticated screen instead of trusting an arbitrary URL from push.
class NotificationNavigationService {
  NotificationNavigationService._();

  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Map<String, dynamic>? _pending;
  bool _authenticatedReady = false;

  void setAuthenticatedReady(bool value) {
    if (_authenticatedReady == value) return;
    _authenticatedReady = value;
    if (value) {
      Future.microtask(drainPending);
    }
  }

  Future<void> open(Map<String, dynamic> data) async {
    final state = navigatorKey.currentState;
    if (!_authenticatedReady || state == null) {
      _pending = Map<String, dynamic>.from(data);
      return;
    }

    _pending = null;
    final type = (data['type'] ?? '').toString().toLowerCase();
    final relatedEntity =
        (data['relatedEntity'] ?? '').toString().toLowerCase();
    final relatedId = _firstNonEmpty([
      data['relatedEntityId'],
      data['orderId'],
      data['entityId'],
    ]);
    final exercisePlanId = _firstNonEmpty([data['exercisePlanId']]);
    final screenHint = (data['screen'] ?? '').toString().toLowerCase();

    Widget screen;
    if (exercisePlanId.isNotEmpty || screenHint == 'physio_exercise_plan') {
      screen = PhysioExercisePlanDetailScreen(planId: exercisePlanId);
    } else if (type == 'appointment' || relatedEntity.contains('appointment')) {
      screen = const AppointmentsScreen();
    } else if (type == 'prescription' ||
        relatedEntity.contains('prescription')) {
      screen = const PrescriptionsScreen();
    } else if (type == 'lab_report' ||
        type == 'diagnostic' ||
        relatedEntity.contains('lab') ||
        relatedEntity.contains('diagnostic')) {
      screen = const PathologyScreen();
    } else if (type == 'order' ||
        type == 'pharmacy' ||
        relatedEntity.contains('pharmacy') ||
        relatedEntity.contains('order')) {
      screen = relatedId.isNotEmpty
          ? PharmacyOrderDetailsScreen(orderId: relatedId)
          : const PharmacyOrdersScreen();
    } else if (type == 'chat' || relatedEntity.contains('chat')) {
      screen = const ChatListScreen();
    } else if (type == 'payment' || relatedEntity.contains('payment')) {
      screen = const PaymentsScreen();
    } else {
      screen = const NotificationsScreen();
    }

    await state.push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> drainPending() async {
    final pending = _pending;
    if (pending == null || !_authenticatedReady || navigatorKey.currentState == null) return;
    _pending = null;
    await open(pending);
  }

  String _firstNonEmpty(List<dynamic> candidates) {
    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }
}
