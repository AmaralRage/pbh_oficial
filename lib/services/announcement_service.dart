import 'package:supabase_flutter/supabase_flutter.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.audience,
    required this.destinationUrl,
    required this.soundEnabled,
    required this.pushAttempted,
    required this.pushAccepted,
    required this.readCount,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String audience;
  final String? destinationUrl;
  final bool soundEnabled;
  final int pushAttempted;
  final int pushAccepted;
  final int readCount;
  final bool isRead;
}

class AnnouncementDraft {
  const AnnouncementDraft({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.destinationUrl,
    required this.soundEnabled,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String message;
  final String audience;
  final String? destinationUrl;
  final bool soundEnabled;
  final DateTime updatedAt;
}

class AnnouncementMetrics {
  const AnnouncementMetrics({
    required this.sent,
    required this.readReceipts,
    required this.pushAttempted,
    required this.pushAccepted,
    required this.registeredUsers,
    required this.memberUsers,
    required this.adminUsers,
    required this.pushDeliveryRate,
    required this.readRate,
  });

  final int sent;
  final int readReceipts;
  final int pushAttempted;
  final int pushAccepted;
  final int registeredUsers;
  final int memberUsers;
  final int adminUsers;
  final double? pushDeliveryRate;
  final double? readRate;

  factory AnnouncementMetrics.fromMap(Map<String, dynamic> map) => AnnouncementMetrics(
        sent: (map['sent'] as num? ?? 0).toInt(),
        readReceipts: (map['read_receipts'] as num? ?? 0).toInt(),
        pushAttempted: (map['push_attempted'] as num? ?? 0).toInt(),
        pushAccepted: (map['push_accepted'] as num? ?? 0).toInt(),
        registeredUsers: (map['registered_users'] as num? ?? 0).toInt(),
        memberUsers: (map['member_users'] as num? ?? 0).toInt(),
        adminUsers: (map['admin_users'] as num? ?? 0).toInt(),
        pushDeliveryRate: (map['push_delivery_rate'] as num?)?.toDouble(),
        readRate: (map['read_rate'] as num?)?.toDouble(),
      );
}

class AnnouncementService {
  AnnouncementService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String get _userId => _client.auth.currentUser!.id;

  Future<List<Announcement>> fetchAnnouncements({int limit = 1000, bool includeAudienceMetrics = false}) async {
    final rows = await _client
        .from('announcements')
        .select('id, title, message, created_at, audience, destination_url, sound_enabled, push_attempted_count, push_accepted_count')
        .order('created_at', ascending: false)
        .limit(limit);
    final receiptCounts = <String, int>{};
    if (includeAudienceMetrics) {
      final receiptRows = await _client.rpc('admin_announcement_read_counts') as List<dynamic>;
      for (final row in receiptRows) {
        final id = row['announcement_id'] as String;
        receiptCounts[id] = (row['read_count'] as num).toInt();
      }
    }
    final ownRows = await _client
        .from('announcement_reads')
        .select('announcement_id')
        .eq('user_id', _userId);
    final ownReadIds = ownRows.map((row) => row['announcement_id'] as String).toSet();
    return rows.map((row) => Announcement(
          id: row['id'] as String,
          title: row['title'] as String,
          message: row['message'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          audience: row['audience'] as String? ?? 'all',
          destinationUrl: row['destination_url'] as String?,
          soundEnabled: row['sound_enabled'] as bool? ?? true,
          pushAttempted: (row['push_attempted_count'] as num? ?? 0).toInt(),
          pushAccepted: (row['push_accepted_count'] as num? ?? 0).toInt(),
          readCount: receiptCounts[row['id'] as String] ?? 0,
          isRead: ownReadIds.contains(row['id']),
        )).toList();
  }

  Future<int> unreadCount() async =>
      (await fetchAnnouncements()).where((item) => !item.isRead).length;

  Future<List<AnnouncementDraft>> fetchDrafts() async {
    final rows = await _client.from('announcement_drafts')
        .select('id, title, message, audience, destination_url, sound_enabled, updated_at')
        .order('updated_at', ascending: false);
    return rows.map((row) => AnnouncementDraft(
          id: row['id'] as String,
          title: row['title'] as String,
          message: row['message'] as String,
          audience: row['audience'] as String,
          destinationUrl: row['destination_url'] as String?,
          soundEnabled: row['sound_enabled'] as bool? ?? true,
          updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        )).toList();
  }

  Future<AnnouncementMetrics> fetchMetrics() async {
    final data = await _client.rpc('admin_announcement_metrics');
    return AnnouncementMetrics.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<void> saveDraft({
    String? id,
    required String title,
    required String message,
    required String audience,
    String? destinationUrl,
    required bool soundEnabled,
  }) async {
    final values = <String, dynamic>{
      'title': title.trim(),
      'message': message.trim(),
      'audience': audience,
      'destination_url': destinationUrl?.trim().isEmpty == true ? null : destinationUrl?.trim(),
      'sound_enabled': soundEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id != null) {
      await _client.from('announcement_drafts').update(values).eq('id', id);
    } else {
      values['created_by'] = _userId;
      await _client.from('announcement_drafts').insert(values);
    }
  }

  Future<void> deleteDraft(String id) async {
    await _client.from('announcement_drafts').delete().eq('id', id);
  }

  Future<String> publish({
    required String title,
    required String message,
    required String audience,
    String? destinationUrl,
    required bool soundEnabled,
  }) async {
    final row = await _client.from('announcements').insert({
      'title': title.trim(),
      'message': message.trim(),
      'audience': audience,
      'destination_url': destinationUrl?.trim().isEmpty == true ? null : destinationUrl?.trim(),
      'sound_enabled': soundEnabled,
      'created_by': _userId,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<int> sendPush({required String announcementId}) async {
    final result = await _client.functions.invoke('send-announcement', body: {
      'announcementId': announcementId,
    });
    final data = result.data as Map<String, dynamic>?;
    return data?['sent'] as int? ?? 0;
  }

  Future<void> markRead(String announcementId) async {
    await _client.from('announcement_reads').upsert({
      'announcement_id': announcementId,
      'user_id': _userId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'announcement_id,user_id');
  }
}
