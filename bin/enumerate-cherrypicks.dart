import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:collection';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  String get release => _results['release'];
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;
  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addOption('release',
          abbr: 'r', help: 'release to scan for cherrypick requests');

    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results['release'] == null)
        throw (ArgParserException('Need a version!'));
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: dart enumerate-cherrypicks.dart -r release-version');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);
  var release = opts.release;
  var flutterCherryPickLabel =
      'label:"cp: ${release}" -label:"cp: ${release} completed"';

  var flutterQuery = 'org:flutter is:issue ${flutterCherryPickLabel}';
  var dartQuery = 'org:dart-lang is:issue label:cherry-pick-review';

  // Now do the same for performance issues.
  var flutterIssues = await github.searchIssuePRs(flutterQuery);
  var dartIssues = await github.searchIssuePRs(dartQuery);

  await for (var issue in flutterIssues) {
    print(issue.summary());
  }
}
