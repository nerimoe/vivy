import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

@immutable
class DaemonHealth {
  const DaemonHealth({
    required this.version,
    required this.platform,
    required this.capabilities,
  });

  factory DaemonHealth.fromJson(Map<String, Object?> json) {
    return DaemonHealth(
      version: json['version']! as String,
      platform: json['platform']! as String,
      capabilities: (json['capabilities']! as List<Object?>).cast<String>(),
    );
  }

  final String version;
  final String platform;
  final List<String> capabilities;
}

@immutable
class DesktopNotification {
  const DesktopNotification({
    required this.sequence,
    required this.id,
    required this.source,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory DesktopNotification.fromJson(Map<String, Object?> json) {
    return DesktopNotification(
      sequence: (json['sequence']! as num).toInt(),
      id: json['id']! as String,
      source: json['source']! as String,
      title: json['title']! as String,
      body: json['body']! as String,
      createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
    );
  }

  final int sequence;
  final String id;
  final String source;
  final String title;
  final String body;
  final DateTime createdAt;
}

@immutable
class NotificationPage {
  const NotificationPage({required this.cursor, required this.items});

  factory NotificationPage.fromJson(Map<String, Object?> json) {
    final rawItems = (json['items']! as List<Object?>)
        .cast<Map<String, Object?>>();
    return NotificationPage(
      cursor: (json['cursor']! as num).toInt(),
      items: rawItems.map(DesktopNotification.fromJson).toList(),
    );
  }

  final int cursor;
  final List<DesktopNotification> items;
}

class DaemonClient {
  DaemonClient({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  Future<DaemonHealth> health() async {
    final response = await _client
        .get(baseUri.resolve('/v1/health'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) {
      throw http.ClientException('Daemon returned ${response.statusCode}');
    }
    return DaemonHealth.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Future<NotificationPage> notifications() async {
    final response = await _client
        .get(baseUri.resolve('/v1/notifications'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Daemon notifications returned ${response.statusCode}',
      );
    }
    return NotificationPage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  void close() => _client.close();
}

final daemonEndpointProvider = Provider<Uri>(
  (_) => Uri.parse('http://127.0.0.1:43821'),
);

final daemonHealthProvider = FutureProvider<DaemonHealth>((ref) async {
  final client = DaemonClient(baseUri: ref.watch(daemonEndpointProvider));
  ref.onDispose(client.close);
  return client.health();
});

final desktopNotificationsProvider =
    FutureProvider.autoDispose<List<DesktopNotification>>((ref) async {
      final client = DaemonClient(baseUri: ref.watch(daemonEndpointProvider));
      ref.onDispose(client.close);
      final refresh = Timer.periodic(
        const Duration(seconds: 20),
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(refresh.cancel);
      final page = await client.notifications();
      return page.items;
    });
