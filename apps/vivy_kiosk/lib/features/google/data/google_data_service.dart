import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/tasks/v1.dart' as tasks;

@immutable
class GoogleEventItem {
  const GoogleEventItem({required this.id, required this.title, this.startsAt});

  final String id;
  final String title;
  final DateTime? startsAt;
}

@immutable
class GoogleTaskItem {
  const GoogleTaskItem({
    required this.id,
    required this.title,
    required this.taskListId,
    required this.completed,
    this.dueAt,
  });

  final String id;
  final String title;
  final String taskListId;
  final bool completed;
  final DateTime? dueAt;
}

@immutable
class GoogleSnapshot {
  const GoogleSnapshot({required this.events, required this.tasks});

  final List<GoogleEventItem> events;
  final List<GoogleTaskItem> tasks;
}

class VivyGoogleDataService {
  static const scopes = [
    calendar.CalendarApi.calendarReadonlyScope,
    tasks.TasksApi.tasksScope,
  ];

  GoogleSignInAccount? _user;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authentication;

  Future<void> initialize({String? clientId}) async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(clientId: clientId);
    _authentication = signIn.authenticationEvents.listen((event) {
      _user = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
      };
    });
    await signIn.attemptLightweightAuthentication();
  }

  Future<void> authorize() async {
    final signIn = GoogleSignIn.instance;
    if (_user == null) {
      if (!signIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Web sign-in must be initiated with the Google Identity Services button',
        );
      }
      _user = await signIn.authenticate();
    }
    await _user!.authorizationClient.authorizeScopes(scopes);
  }

  Future<GoogleSnapshot> refresh({DateTime? now}) async {
    final user = _user;
    if (user == null) throw StateError('Google account is not signed in');
    final authorization = await user.authorizationClient.authorizationForScopes(
      scopes,
    );
    if (authorization == null) {
      throw StateError('Calendar and Tasks scopes have not been authorized');
    }
    final client = authorization.authClient(scopes: scopes);
    try {
      final current = now ?? DateTime.now();
      final calendarApi = calendar.CalendarApi(client);
      final eventPage = await calendarApi.events.list(
        'primary',
        timeMin: DateTime(current.year, current.month, current.day),
        timeMax: DateTime(current.year, current.month, current.day + 2),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 30,
      );
      final taskApi = tasks.TasksApi(client);
      final taskLists = await taskApi.tasklists.list(maxResults: 20);
      final taskItems = <GoogleTaskItem>[];
      for (final list in taskLists.items ?? const <tasks.TaskList>[]) {
        if (list.id == null) continue;
        final page = await taskApi.tasks.list(
          list.id!,
          showCompleted: false,
          showDeleted: false,
          maxResults: 100,
        );
        taskItems.addAll(
          (page.items ?? const <tasks.Task>[])
              .where((item) => item.id != null)
              .map(
                (item) => GoogleTaskItem(
                  id: item.id!,
                  title: item.title ?? 'Untitled task',
                  taskListId: list.id!,
                  completed: item.status == 'completed',
                  dueAt: item.due == null ? null : DateTime.tryParse(item.due!),
                ),
              ),
        );
      }
      return GoogleSnapshot(
        events: (eventPage.items ?? const <calendar.Event>[])
            .where((event) => event.id != null)
            .map(
              (event) => GoogleEventItem(
                id: event.id!,
                title: event.summary ?? 'Untitled event',
                startsAt: event.start?.dateTime ?? event.start?.date,
              ),
            )
            .toList(),
        tasks: taskItems,
      );
    } finally {
      client.close();
    }
  }

  Future<void> completeTask(GoogleTaskItem item) async {
    final user = _user;
    if (user == null) throw StateError('Google account is not signed in');
    final authorization = await user.authorizationClient.authorizationForScopes(
      scopes,
    );
    if (authorization == null) {
      throw StateError('Tasks scope is not authorized');
    }
    final client = authorization.authClient(scopes: scopes);
    try {
      final api = tasks.TasksApi(client);
      final task = await api.tasks.get(item.taskListId, item.id);
      task.status = 'completed';
      task.completed = DateTime.now().toUtc().toIso8601String();
      await api.tasks.update(task, item.taskListId, item.id);
    } finally {
      client.close();
    }
  }

  Future<void> dispose() async {
    await _authentication?.cancel();
  }
}
