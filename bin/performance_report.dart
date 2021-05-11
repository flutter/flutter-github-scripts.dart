import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;
  DateTime get from => DateTime.parse(_results['from']);
  DateTime get to => DateTime.parse(_results['to']);
  int? get exitCode => _results['help'] ? 0 : null;
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
      exit(-1);
    }
  }

  void _printUsage() {
    print('Usage: pub run performance_report.dart [-f date] [-t date]');
    print(_parser.usage);
  }
}

void printHeader(Options opts, String which) {
  var fromStamp = opts.from.toIso8601String().substring(0, 10);
  var toStamp = opts.to.toIso8601String().substring(0, 10);

  print(
      '\n\nTo: flutter-performanceg@oogle.com, flutter-dart-tpm@google.com\n\n');
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
  if (opts.exitCode != null) exit(opts.exitCode!);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);
  var fromStamp = opts.from.toIso8601String().substring(0, 10);
  var toStamp = opts.to.toIso8601String().substring(0, 10);

  // Now do the same for performance issues.
  var openPerfIssues = await github.deprecated_search(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.open,
    labels: ['severe: performance'],
  );

  var closedPerfIssues = await github.fetch(
    owner: 'flutter',
    name: 'flutter',
    type: GitHubIssueType.issue,
    state: GitHubIssueState.closed,
    labels: ['severe: performance'],
  );

  var open = <Issue>[];
  var openedThisPeriod = <Issue>[];
  var closedThisPeriod = <Issue>[];

  openPerfIssues.forEach((issue) {
    if (issue.state == "OPEN") open.add(issue);
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
  });

  closedPerfIssues.forEach((issue) {
    if (issue.state == "CLOSED" &&
        issue.closedAt.compareTo(opts.from) >= 0 &&
        issue.closedAt.compareTo(opts.to) <= 0) closedThisPeriod.add(issue);
    if (issue.createdAt.compareTo(opts.from) >= 0 &&
        issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
  });

  // Cluster them to get our counts by priority
  var openCluster = Cluster.byLabel(openPerfIssues);
  var closedCluster = Cluster.byLabel(closedPerfIssues);
  final interestingPriorities = ['P0', 'P1', 'P2', 'P3'];

  printHeader(opts, 'Performance');

  print(
      'This shows the number of new, open, and closed `severe: performance` issues over the period from');
  print('${fromStamp} to ${toStamp}.\n\n');

  print('### ${open.length} open `severe: performance` issue(s) in total\n');

  print(
      '### ${openedThisPeriod.length} `severe: performance` issue(s) opened between ${fromStamp} and ${toStamp}');
  openedThisPeriod.forEach((issue) =>
      print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print(
      '### ${closedThisPeriod.length} `severe: performance` issue(s) closed between ${fromStamp} and ${toStamp}');
  closedThisPeriod.forEach((issue) =>
      print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print('### Issues open/closed by priority\n');
  print('| Priority | Open | Closed | Total |');
  print('|----------|------|--------|-------|');
  var totalOpen = 0, totalClosed = 0, total = 0;
  interestingPriorities.forEach((p) {
    int openCount =
        openCluster.clusters[p] == null ? 0 : openCluster.clusters[p].length;
    int closedCount = closedCluster.clusters[p] == null
        ? 0
        : closedCluster.clusters[p].length;
    int totalRow = openCount + closedCount;
    totalOpen += openCount;
    totalClosed += closedCount;
    total += totalRow;
    print('|${p}|${openCount}|${closedCount}|${totalRow}|');
  });
  print('|TOTAL|${totalOpen}|${totalClosed}|${total}|\n');
}
