import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/ui/shell/tabs.dart';
import 'package:spicetify_ui/ui/shell/titlebar.dart';
import 'package:spicetify_ui/ui/widgets/status_dot.dart';

void main() {
  testWidgets('titlebar shows the app version and the CLI version', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Titlebar(appVersion: '0.1.0', cliVersion: '2.45.0', state: DotState.ok),
      ),
    ));

    expect(find.text('Spicetify UI'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('2.45.0'), findsOneWidget);
  });

  testWidgets('titlebar shows a placeholder when the CLI is missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Titlebar(appVersion: '0.1.0', cliVersion: null, state: DotState.missing),
      ),
    ));

    expect(find.text('not found'), findsOneWidget);
  });

  testWidgets('titlebar reflects the given dot state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Titlebar(appVersion: '0.1.0', cliVersion: '2.45.0', state: DotState.warn),
      ),
    ));

    final dot = tester.widget<StatusDot>(find.byType(StatusDot));
    expect(dot.state, DotState.warn);
  });

  testWidgets('tab strip renders both labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TabStrip(index: 0, onChanged: (_) {})),
    ));

    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
  });

  testWidgets('tab strip reports taps', (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TabStrip(index: 0, onChanged: (i) => selected = i)),
    ));

    await tester.tap(find.text('Config'));
    await tester.pump();

    expect(selected, 1);
  });
}
