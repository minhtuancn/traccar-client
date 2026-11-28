import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:traccar_client/status_refresh_gate.dart';

void main() {
  test('coalesces periodic and manual refresh', () async {
    final gate = StatusRefreshGate();
    final pending = Completer<void>();
    final first = gate.run(() => pending.future);
    expect(await gate.run(() async => fail('overlap')), isFalse);
    pending.complete();
    expect(await first, isTrue);
    expect(await gate.run(() async {}), isTrue);
  });
  test('an error releases the gate and disposal prevents future calls', () async {
    final gate = StatusRefreshGate();
    await expectLater(gate.run(() async => throw StateError('test')), throwsStateError);
    expect(await gate.run(() async {}), isTrue);
    gate.dispose();
    expect(await gate.run(() async => fail('disposed')), isFalse);
  });
}
