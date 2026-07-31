import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/voice/domain/voice_tools.dart';

void main() {
  test('parses only whitelisted voice tools', () {
    final call = VoiceToolCall.parse(
      callId: 'call-1',
      name: 'create_alarm',
      argumentsJson: '{"time":"07:30"}',
    );
    expect(call.tool, VivyVoiceTool.createAlarm);
    expect(call.arguments['time'], '07:30');
  });

  test('rejects arbitrary tool names and non-object arguments', () {
    expect(
      () => VoiceToolCall.parse(
        callId: 'call-1',
        name: 'run_shell',
        argumentsJson: '{}',
      ),
      throwsFormatException,
    );
    expect(
      () => VoiceToolCall.parse(
        callId: 'call-1',
        name: 'create_alarm',
        argumentsJson: '[]',
      ),
      throwsFormatException,
    );
  });
}
