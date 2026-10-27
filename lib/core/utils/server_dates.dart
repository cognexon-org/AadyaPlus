/// Reading the dates the backend sends for bookings.
///
/// A booked day (`appointmentDate`, `scheduledDate`) is stored as midnight in
/// the *server's* timezone and arrives as UTC — 00:00Z on a UTC server, but
/// 18:30Z the previous day on an IST server. Parsing it directly showed the
/// wrong day. Shifting by 14h before taking the UTC date lands on the intended
/// day for any server zone from UTC to UTC+14. Times (`startTime`) are
/// "HH:mm" in the clinic's local time.
library;

/// The booked calendar day (local midnight), or null.
DateTime? serverDay(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}');
  if (d == null) return null;
  final u = (d.isUtc ? d : d.toUtc()).add(const Duration(hours: 14));
  return DateTime(u.year, u.month, u.day);
}

/// The booked day at [hhmm] ("09:30"); the day itself if no time is given.
DateTime? serverDayAt(dynamic rawDay, String? hhmm) {
  final day = serverDay(rawDay);
  if (day == null) return null;
  final parts = (hhmm ?? '').split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '');
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return h == null ? day : DateTime(day.year, day.month, day.day, h, m);
}

/// A real instant (createdAt, paidAt…) in the phone's local time.
DateTime? instant(dynamic raw) => DateTime.tryParse('${raw ?? ''}')?.toLocal();

/// "2026-10-26" for sending a picked day to the server.
String dayParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
