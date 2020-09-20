// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:core';

import 'package:analysis_server/protocol/protocol.dart';
import 'package:analysis_server/protocol/protocol_constants.dart';
import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analysis_server/src/domain_abstract.dart';
import 'package:analysis_server/src/plugin/result_merger.dart';
import 'package:analysis_server/src/services/kythe/kythe_visitors.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer_plugin/protocol/protocol.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

/// Instances of the class [KytheDomainHandler] implement a [RequestHandler]
/// that handles requests in the `kythe` domain.
class KytheDomainHandler extends AbstractRequestHandler {
  /// Initialize a newly created handler to handle requests for the given
  /// [server].
  KytheDomainHandler(AnalysisServer server) : super(server);

  /// Implement the `kythe.getKytheEntries` request.
  Future<void> getKytheEntries(Request request) async {
    var file = KytheGetKytheEntriesParams.fromRequest(request).file;
    var driver = server.getAnalysisDriver(file);
    if (driver == null) {
      server.sendResponse(Response.getKytheEntriesInvalidFile(request));
    } else {
      //
      // Allow plugins to start computing entries.
      //
      var requestParams = plugin.KytheGetKytheEntriesParams(file);
      var pluginFutures = server.pluginManager
          .broadcastRequest(requestParams, contextRoot: driver.contextRoot);
      //
      // Compute entries generated by server.
      //
      var allResults = <KytheGetKytheEntriesResult>[];
      var result = await server.getResolvedUnit(file);
      if (result?.state == ResultState.VALID) {
        var entries = <KytheEntry>[];
        // TODO(brianwilkerson) Figure out how to get the list of files.
        var files = <String>[];
        result.unit.accept(KytheDartVisitor(server.resourceProvider, entries,
            file, InheritanceManager3(), result.content));
        allResults.add(KytheGetKytheEntriesResult(entries, files));
      }
      //
      // Add the entries produced by plugins to the server-generated entries.
      //
      if (pluginFutures != null) {
        var responses = await waitForResponses(pluginFutures,
            requestParameters: requestParams);
        for (var response in responses) {
          var result = plugin.KytheGetKytheEntriesResult.fromResponse(response);
          allResults
              .add(KytheGetKytheEntriesResult(result.entries, result.files));
        }
      }
      //
      // Return the result.
      //
      var merger = ResultMerger();
      var mergedResults = merger.mergeKytheEntries(allResults);
      if (mergedResults == null) {
        server.sendResponse(
            KytheGetKytheEntriesResult(<KytheEntry>[], <String>[])
                .toResponse(request.id));
      } else {
        server.sendResponse(KytheGetKytheEntriesResult(
                mergedResults.entries, mergedResults.files)
            .toResponse(request.id));
      }
    }
  }

  @override
  Response handleRequest(Request request) {
    try {
      var requestName = request.method;
      if (requestName == KYTHE_REQUEST_GET_KYTHE_ENTRIES) {
        getKytheEntries(request);
        return Response.DELAYED_RESPONSE;
      }
    } on RequestFailure catch (exception) {
      return exception.response;
    }
    return null;
  }
}
