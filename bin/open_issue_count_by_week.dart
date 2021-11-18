import 'dart:collection';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  DateTime get from => DateTime.parse(_results['from']);
  DateTime get to => DateTime.parse(_results['to']);
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addOption('from',
          defaultsTo:
              DateTime.now().subtract(Duration(hours: 24 * 7)).toString(),
          abbr: 'f',
          help: 'from date, ISO format yyyy-mm-dd')
      ..addOption('to',
          defaultsTo: DateTime.now().toIso8601String(),
          abbr: 't',
          help: 'to date, ISO format yyyy-mm-dd');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run open-issue-count-by-week.dart [-f date] [-t date]');
    print(_parser.usage);
  }
}

DateTime nearestSaturday(DateTime when) {
  var result = when;
  for (int delta = 0; delta < 7; delta++) {
    result = when.add(Duration(days: delta));
    if (result.weekday == DateTime.saturday) return result;
  }
  return null;
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var openIssues = await github.fetch(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.open,
  );

  var closedIssues = await github.fetch(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.closed,
  );

  var counts = SplayTreeMap<String, int>();
  openIssues.forEach((item) {
    var issue = item as Issue;
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) {
      String key = nearestSaturday(issue.createdAt).toString().substring(0, 10);
      if (!counts.containsKey(key)) counts[key] = 0;
      counts[key] = counts[key] + 1;
    }
  });

  closedIssues.forEach((item) {
    var issue = item as Issue;
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) {
      String key = nearestSaturday(issue.createdAt).toString().substring(0, 10);
      if (!counts.containsKey(key)) counts[key] = 0;
      counts[key] = counts[key] + 1;
    }
  });

  var fromStamp = opts.from.toIso8601String().substring(0, 10);
  var toStamp = opts.to.toIso8601String().substring(0, 10);

  print('Open issues per week from ${fromStamp} to ${toStamp}');
  print('Week ending\tCount');

  for (var key in counts.keys) {
    print('${key}\t${counts[key]}');
  }
}
