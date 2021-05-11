import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  /*late*/ ArgResults _results;
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
    print('Usage: pub run today_report.dart [-f date] [-t date]');
    print(_parser.usage);
  }
}

void printHeader(Options opts, String which) {
  var fromStamp = opts.from.toIso8601String().substring(0, 10);
  var toStamp = opts.to.toIso8601String().substring(0, 10);

  print('\n\nTo: flutter-team@google.com, flutter-dart-tpm@google.com\n\n');
  if (DateTime.now().weekday == DateTime.tuesday)
    print('Subject: Flutter ${which} Tuesday report!\n');
  if (DateTime.now().weekday == DateTime.thursday)
    print('Subject: Flutter ${which} Thursday report!\n');
  if (DateTime.now().weekday != DateTime.tuesday &&
      DateTime.now().weekday != DateTime.thursday) {
    print('Subject: ${which} issues from ${fromStamp} to ${toStamp}\n\n');
  }
  print('\n\n---\n\n');
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var openIssues = await github.deprecated_search(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.open,
    labels: ['P0'],
  );

  var closedIssues = await github.deprecated_search(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.closed,
    labels: ['P0'],
  );

  var open = <Issue>[];
  var openedThisPeriod = <Issue>[];
  var closedThisPeriod = <Issue>[];

  openIssues.forEach((issue) {
    if (issue.state == "OPEN") open.add(issue);
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
  });

  closedIssues.forEach((issue) {
    if (issue.state == "CLOSED" &&
        issue.closedAt.compareTo(opts.from) >= 0 &&
        issue.closedAt.compareTo(opts.to) <= 0) closedThisPeriod.add(issue);
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
  });

  var fromStamp = opts.from.toIso8601String().substring(0, 10);
  var toStamp = opts.to.toIso8601String().substring(0, 10);

  printHeader(opts, 'TODAY');

  print(
      'This shows the number of new, open, and closed `P0` issues over the period from');
  print('${fromStamp} to ${toStamp}.\n\n');

  print('### ${open.length} open `P0` issue(s)');
  open.forEach((issue) =>
      print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print(
      '### ${openedThisPeriod.length} `P0` issue(s) opened between ${fromStamp} and ${toStamp}');
  openedThisPeriod.forEach((issue) =>
      print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print(
      '### ${closedThisPeriod.length} `P0` issue(s) closed between ${fromStamp} and ${toStamp}');
  closedThisPeriod.forEach((issue) =>
      print(issue.summary(boldInteresting: false, linebreakAfter: true)));
}
