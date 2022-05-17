import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults? _results;
  int? get exitCode => _results == null
      ? -1
      : _results!['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser.addFlag('help',
        defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage');
    try {
      _results = _parser.parse(args);
      if (_results!['help']) _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run open_prs.dart');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var pullRequests = await github.fetch(
      owner: 'flutter',
      name: 'flutter',
      type: GitHubIssueType.pullRequest,
      state: GitHubIssueState.open);

  for (var pullRequest in pullRequests) {
    print(pullRequest.summary(linebreakAfter: true));
  }
}
