// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'server_abstract.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FoldingTest);
  });
}

@reflectiveTest
class FoldingTest extends AbstractLspAnalysisServerTest {
  Future<void> test_class() async {
    final content = '''
    class MyClass2 {[[
      // Class content
    ]]}
    ''';

    final range1 = rangeFromMarkers(content);
    final expectedRegions = [
      FoldingRange(
        range1.start.line,
        range1.start.character,
        range1.end.line,
        range1.end.character,
        null,
      )
    ];

    await initialize();
    await openFile(mainFileUri, withoutMarkers(content));

    final regions = await getFoldingRegions(mainFileUri);
    expect(regions, unorderedEquals(expectedRegions));
  }

  Future<void> test_comments() async {
    final content = '''
    [[/// This is a comment
    /// that spans many lines]]
    class MyClass2 {}
    ''';

    final range1 = rangeFromMarkers(content);
    final expectedRegions = [
      FoldingRange(
        range1.start.line,
        range1.start.character,
        range1.end.line,
        range1.end.character,
        FoldingRangeKind.Comment,
      )
    ];

    await initialize();
    await openFile(mainFileUri, withoutMarkers(content));

    final regions = await getFoldingRegions(mainFileUri);
    expect(regions, unorderedEquals(expectedRegions));
  }

  Future<void> test_fromPlugins_dartFile() async {
    final pluginAnalyzedFilePath = join(projectFolderPath, 'lib', 'foo.dart');
    final pluginAnalyzedUri = Uri.file(pluginAnalyzedFilePath);

    const content = '''
    // [[contributed by fake plugin]]

    class AnnotatedDartClass {[[
      // content of dart class, contributed by server
    ]]}
    ''';
    final ranges = rangesFromMarkers(content);
    final withoutMarkers = withoutRangeMarkers(content);
    newFile(pluginAnalyzedFilePath);

    await initialize();
    await openFile(pluginAnalyzedUri, withoutMarkers);

    final pluginResult = plugin.AnalysisFoldingParams(
      pluginAnalyzedFilePath,
      [plugin.FoldingRegion(plugin.FoldingKind.DIRECTIVES, 7, 26)],
    );
    configureTestPlugin(notification: pluginResult.toNotification());

    final res = await getFoldingRegions(pluginAnalyzedUri);
    expect(
      res,
      unorderedEquals([
        _toFoldingRange(ranges[0], FoldingRangeKind.Imports),
        _toFoldingRange(ranges[1], null),
      ]),
    );
  }

  Future<void> test_fromPlugins_nonDartFile() async {
    final pluginAnalyzedFilePath = join(projectFolderPath, 'lib', 'foo.sql');
    final pluginAnalyzedUri = Uri.file(pluginAnalyzedFilePath);
    const content = '''
      CREATE TABLE foo(
         [[-- some columns]]
      );
    ''';
    final withoutMarkers = withoutRangeMarkers(content);
    newFile(pluginAnalyzedFilePath, content: withoutMarkers);

    await initialize();
    await openFile(pluginAnalyzedUri, withoutMarkers);

    final pluginResult = plugin.AnalysisFoldingParams(
      pluginAnalyzedFilePath,
      [plugin.FoldingRegion(plugin.FoldingKind.CLASS_BODY, 33, 15)],
    );
    configureTestPlugin(notification: pluginResult.toNotification());

    final res = await getFoldingRegions(pluginAnalyzedUri);
    final expectedRange = rangeFromMarkers(content);
    expect(res, [_toFoldingRange(expectedRange, null)]);
  }

  Future<void> test_headersImportsComments() async {
    // TODO(dantup): Review why the file header and the method comment ranges
    // are different... one spans only the range to collapse, but the other
    // just starts at the logical block.
    // The LSP spec doesn't give any guidance on whether the first part of
    // the surrounded content should be visible or not after folding
    // so we'll need to revisit this once there's clarification:
    // https://github.com/Microsoft/language-server-protocol/issues/659
    final content = '''
    // Copyright some year by some people[[
    // See LICENCE etc.]]

    import[[ 'dart:io';
    import 'dart:async';]]

    [[/// This is not the file header
    /// It's just a comment]]
    main() {}
    ''';

    final ranges = rangesFromMarkers(content);

    final expectedRegions = [
      _toFoldingRange(ranges[0], FoldingRangeKind.Comment),
      _toFoldingRange(ranges[1], FoldingRangeKind.Imports),
      _toFoldingRange(ranges[2], FoldingRangeKind.Comment),
    ];

    await initialize();
    await openFile(mainFileUri, withoutMarkers(content));

    final regions = await getFoldingRegions(mainFileUri);
    expect(regions, unorderedEquals(expectedRegions));
  }

  Future<void> test_nonDartFile() async {
    await initialize();
    await openFile(pubspecFileUri, simplePubspecContent);

    final regions = await getFoldingRegions(pubspecFileUri);
    expect(regions, isEmpty);
  }

  FoldingRange _toFoldingRange(Range range, FoldingRangeKind kind) {
    return FoldingRange(
      range.start.line,
      range.start.character,
      range.end.line,
      range.end.character,
      kind,
    );
  }
}
