// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/diagnostics/tree_builder.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/variable_utils.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late MockScriptManager scriptManager;

  const windowSize = Size(4000, 4000);

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManager();

    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isProfileBuild: false,
      isFlutterApp: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, scriptManager);
    setGlobal(NotificationService, NotificationService());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
    setGlobal(PreferencesController, PreferencesController());
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = createMockDebuggerControllerWithDefaults();

    resetRef();
    resetRoot();
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  Future<void> verifyGroupings(
    WidgetTester tester, {
    required Finder parentFinder,
  }) async {
    final group0To9999Finder = find.selectableTextContaining('[0 - 9999]');
    final group10000To19999Finder =
        find.selectableTextContaining('[10000 - 19999]');
    final group230000To239999Finder =
        find.selectableTextContaining('[230000 - 239999]');
    final group240000To243620Finder =
        find.selectableTextContaining('[240000 - 243620]');

    final group0To99Finder = find.selectableTextContaining('[0 - 99]');
    final group100To199Finder = find.selectableTextContaining('[100 - 199]');
    final group200To299Finder = find.selectableTextContaining('[200 - 299]');

    // Initially the parent variable is not expanded.
    expect(parentFinder, findsOneWidget);
    expect(group0To9999Finder, findsNothing);
    expect(group10000To19999Finder, findsNothing);
    expect(group230000To239999Finder, findsNothing);
    expect(group240000To243620Finder, findsNothing);

    // Expand the parent variable.
    await tester.tap(parentFinder);
    await tester.pump();
    expect(group0To9999Finder, findsOneWidget);
    expect(group10000To19999Finder, findsOneWidget);
    expect(group230000To239999Finder, findsOneWidget);
    expect(group240000To243620Finder, findsOneWidget);

    // Initially group [0 - 9999] is not expanded.
    expect(group0To99Finder, findsNothing);
    expect(group100To199Finder, findsNothing);
    expect(group200To299Finder, findsNothing);

    // Expand group [0 - 9999].
    await tester.tap(group0To9999Finder);
    await tester.pump();
    expect(group0To99Finder, findsOneWidget);
    expect(group100To199Finder, findsOneWidget);
    expect(group200To299Finder, findsOneWidget);
  }

  testWidgetsWithWindowSize(
    'Variables shows items',
    windowSize,
    (WidgetTester tester) async {
      fakeServiceManager.appState.setVariables(
        [
          buildListVariable(),
          buildMapVariable(),
          buildStringVariable('test str'),
          buildBooleanVariable(true),
          buildSetVariable(),
        ],
      );
      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.text('Variables'), findsOneWidget);

      final listFinder = find.selectableText('Root 1: List (2 items)');

      // expect a tooltip for the list value
      expect(
        find.byTooltip('List (2 items)'),
        findsOneWidget,
      );

      final mapFinder = find.selectableTextContaining(
        'Root 2: Map (2 items)',
      );
      final mapElement1Finder = find.selectableTextContaining("['key1']: 1.0");
      final mapElement2Finder = find.selectableTextContaining("['key2']: 2.0");

      expect(listFinder, findsOneWidget);
      expect(mapFinder, findsOneWidget);
      expect(
        find.selectableTextContaining("Root 3: 'test str...'"),
        findsOneWidget,
      );
      expect(
        find.selectableTextContaining('Root 4: true'),
        findsOneWidget,
      );

      // Initially list is not expanded.
      expect(find.selectableTextContaining('0: 3'), findsNothing);
      expect(find.selectableTextContaining('1: 4'), findsNothing);

      // Expand list.
      await tester.tap(listFinder);
      await tester.pump();
      expect(find.selectableTextContaining('0: 0'), findsOneWidget);
      expect(find.selectableTextContaining('1: 1'), findsOneWidget);

      // Initially map is not expanded.
      expect(mapElement1Finder, findsNothing);
      expect(mapElement2Finder, findsNothing);

      // Expand map.
      await tester.tap(mapFinder);
      await tester.pump();
      expect(mapElement1Finder, findsOneWidget);
      expect(mapElement2Finder, findsOneWidget);

      // Expect a tooltip for the set instance.
      final setFinder = find.selectableText('Root 5: Set (2 items)');
      expect(setFinder, findsOneWidget);

      // Initially set is not expanded.
      expect(find.selectableTextContaining('set value 0'), findsNothing);
      expect(find.selectableTextContaining('set value 1'), findsNothing);

      // Expand set
      await tester.tap(setFinder);
      await tester.pump();
      expect(find.selectableTextContaining('set value 0'), findsOneWidget);
      expect(find.selectableTextContaining('set value 1'), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large list variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final list = buildParentListVariable(length: 243621);
      await buildVariablesTree(list);

      final appState = serviceManager.appState;
      appState.setVariables([list]);

      await pumpDebuggerScreen(tester, debuggerController);

      final listFinder = find.selectableText('Root 1: List (243,621 items)');
      await verifyGroupings(tester, parentFinder: listFinder);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large map variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final map = buildParentMapVariable(length: 243621);
      await buildVariablesTree(map);

      final appState = serviceManager.appState;
      appState.setVariables([map]);

      await pumpDebuggerScreen(tester, debuggerController);

      final mapFinder = find.selectableText('Root 1: Map (243,621 items)');
      await verifyGroupings(tester, parentFinder: mapFinder);
    },
  );

  testWidgetsWithWindowSize(
    'Children in large set variables are grouped',
    windowSize,
    (WidgetTester tester) async {
      final set = buildParentSetVariable(length: 243621);
      await buildVariablesTree(set);

      final appState = serviceManager.appState;
      appState.setVariables([set]);

      await pumpDebuggerScreen(tester, debuggerController);

      final setFinder = find.selectableText('Root 1: Set (243,621 items)');
      await verifyGroupings(tester, parentFinder: setFinder);
    },
  );
}
