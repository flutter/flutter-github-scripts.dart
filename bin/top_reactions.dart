import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

/// 14330 has lots of items. 2020 has no items

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get onlyUnprioritized => _results['only-unprioritized'];
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('only-unprioritized',
          defaultsTo: false,
          abbr: 'o',
          negatable: true,
          help: 'only issues without a label P0-P6');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run reactions.dart [-only-unprioritized]');
    print('If only-unprioritize is passed, only show unprioritized issues.');
    print(_parser.usage);
  }
}

var skipLabels = ['P0', 'P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final github = GitHub(token);

/* Replace this with a fetch

  var issue =
      await github.issue(owner: 'flutter', name: 'flutter', number: 14330);
  var issues = [issue];
*/

  var issues = await github.fetch(
      owner: 'flutter',
      name: 'flutter',
      type: GitHubIssueType.issue,
      state: GitHubIssueState.open);

  print('${Issue.tsvHeader}\tPositive\tNegative\tNeutral\tTotal');

  for (var issue in issues) {
    // If we're not interested in issues with priority labels,
    // skip this label if it has a priority.
    if (opts.onlyUnprioritized) {
      bool skip = false;
      for (var label in issue.labels.labels) {
        if (skipLabels.contains(label.name)) {
          skip = true;
          break;
        }
      }
      if (skip) continue;
    }

    var resultTsv = issue.toTsv();

    // Now get all of the reactions from this issue. We do this with two streams:
    //   1. A stream of reactions on the issue.
    //   2. A stream of reactions on each comment.
    var positive = 0, negative = 0, neutral = 0;
    var postReactionStream = issue.reactionStream;
    await for (var reaction in postReactionStream) {
      if (reaction.positive) positive++;
      if (reaction.negative) negative++;
      if (reaction.neutral) neutral++;
    }

    var commentStream = issue.commentStream;
    await for (var comment in commentStream) {
      var reactionStream = comment.reactionStream;
      await for (var reaction in reactionStream) {
        if (reaction.positive) positive++;
        if (reaction.negative) negative++;
        if (reaction.neutral) neutral++;
      }
    }
    var total = positive + negative + neutral;
    print('${resultTsv}\t${positive}\t${negative}\t${neutral}\t${total}');
  }
}
