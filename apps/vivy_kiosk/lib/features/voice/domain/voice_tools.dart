import 'dart:convert';

enum VivyVoiceTool {
  createAlarm,
  snoozeAlarm,
  createReminder,
  listTodayEvents,
  launchAppOnComputer,
  sendComputerShortcut,
  startVideoStream,
  stopVideoStream,
}

class VoiceToolCall {
  const VoiceToolCall({
    required this.callId,
    required this.tool,
    required this.arguments,
  });

  factory VoiceToolCall.parse({
    required String callId,
    required String name,
    required String argumentsJson,
  }) {
    final tool = VivyVoiceTool.values.where(
      (value) => _wireName(value) == name,
    );
    if (tool.isEmpty) throw FormatException('Unsupported Vivy tool: $name');
    final decoded = jsonDecode(argumentsJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Tool arguments must be a JSON object');
    }
    return VoiceToolCall(callId: callId, tool: tool.single, arguments: decoded);
  }

  final String callId;
  final VivyVoiceTool tool;
  final Map<String, dynamic> arguments;

  static String wireName(VivyVoiceTool value) => _wireName(value);

  static String _wireName(VivyVoiceTool value) => switch (value) {
    VivyVoiceTool.createAlarm => 'create_alarm',
    VivyVoiceTool.snoozeAlarm => 'snooze_alarm',
    VivyVoiceTool.createReminder => 'create_reminder',
    VivyVoiceTool.listTodayEvents => 'list_today_events',
    VivyVoiceTool.launchAppOnComputer => 'launch_app_on_computer',
    VivyVoiceTool.sendComputerShortcut => 'send_computer_shortcut',
    VivyVoiceTool.startVideoStream => 'start_video_stream',
    VivyVoiceTool.stopVideoStream => 'stop_video_stream',
  };
}

abstract interface class VoiceToolExecutor {
  Future<Map<String, Object?>> execute(VoiceToolCall call);
}

const vivyRealtimeTools = <Map<String, Object?>>[
  {
    'type': 'function',
    'name': 'create_alarm',
    'description': 'Create a local Vivy alarm.',
    'parameters': {
      'type': 'object',
      'properties': {
        'time': {'type': 'string'},
        'label': {'type': 'string'},
      },
      'required': ['time'],
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'snooze_alarm',
    'description': 'Snooze the currently active alarm.',
    'parameters': {
      'type': 'object',
      'properties': {
        'minutes': {'type': 'integer', 'minimum': 1, 'maximum': 120},
      },
      'required': ['minutes'],
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'create_reminder',
    'description': 'Create a local reminder.',
    'parameters': {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'time': {'type': 'string'},
      },
      'required': ['title', 'time'],
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'list_today_events',
    'description': 'List calendar events scheduled for today.',
    'parameters': {
      'type': 'object',
      'properties': <String, Object?>{},
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'launch_app_on_computer',
    'description': 'Launch a configured application on a household computer.',
    'parameters': {
      'type': 'object',
      'properties': {
        'computer': {'type': 'string'},
        'app': {'type': 'string'},
      },
      'required': ['computer', 'app'],
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'send_computer_shortcut',
    'description': 'Send a configured shortcut to a household computer.',
    'parameters': {
      'type': 'object',
      'properties': {
        'computer': {'type': 'string'},
        'shortcut': {'type': 'string'},
      },
      'required': ['computer', 'shortcut'],
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'start_video_stream',
    'description': 'Start publishing the Kiosk camera stream.',
    'parameters': {
      'type': 'object',
      'properties': <String, Object?>{},
      'additionalProperties': false,
    },
  },
  {
    'type': 'function',
    'name': 'stop_video_stream',
    'description': 'Stop publishing the Kiosk camera stream.',
    'parameters': {
      'type': 'object',
      'properties': <String, Object?>{},
      'additionalProperties': false,
    },
  },
];
