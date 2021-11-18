import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  DateTime get from => DateTime.parse(_results['from']);
  DateTime get to => DateTime.parse(_results['to']);
  bool get showQueries => _results['queries'];
  int get deltaDays =>
      int.parse(_results['delta'] == null ? '7' : _results['delta']);
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
          help: 'to date, ISO format yyyy-mm-dd')
      ..addFlag('queries',
          abbr: 'q', defaultsTo: false, help: 'Show queries used')
      ..addOption('delta', abbr: 'd', help: 'delta between dates, default = 7');

    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print(
        'Usage: pub run bin/flutterfire_all_closed_over_time.dart [--queries]  --from date --to date');
    print(_parser.usage);
  }
}

class MeanComputer {
  // Running mean of all invocations
  double _totalSumSeconds;
  get totalSum => _totalSumSeconds;
  double _totalCount;
  get totalCount => _totalCount;
  get meanDuration => _totalCount == 0
      ? Duration(seconds: 0)
      : Duration(seconds: _totalSumSeconds ~/ totalCount);

  MeanComputer() {
    _totalSumSeconds = 0.0;
    _totalCount = 0.0;
  }

  Duration computeMean(
    List<dynamic> issues,
  ) {
    bool onlyCustomers = false;
    double sum = 0.0;
    var count = issues == null ? 0 : issues.length;
    if (count == 0) return Duration(seconds: 0);
    bool hasCustomer = false;
    for (var item in issues) {
      var issue = item as Issue;
      if (issue.closedAt == null) continue;
      if (onlyCustomers)
        for (var label in issue.labels.labels) {
          if (label.label.contains('customer:')) {
            hasCustomer = true;
            break;
          }
        }
      if (!onlyCustomers || (onlyCustomers && hasCustomer)) {
        var delta = issue.closedAt.difference(issue.createdAt);
        sum += delta.inSeconds;
      }
    }
    _totalCount += count;
    _totalSumSeconds += sum;

    if (count == 0) {
      return Duration(seconds: 0);
    } else {
      int sumAsInt = sum.toInt();
      int mean = sumAsInt ~/ count;
      return Duration(seconds: mean);
    }
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  DateTime current = opts.from, last = opts.to;

  print(
      'This shows the number of new, open, and closed high priority issues over the period from');
  print('${opts.from} to ${opts.to}.');
  print('Period ending\t' +
      'Mean hours to close all issues closed in this period\tMean hours to close issues opened this period');

  while (current.isBefore(last)) {
    var next = current.add(Duration(days: opts.deltaDays));
    var fromStamp = current.toIso8601String().substring(0, 10);
    var toStamp = next.toIso8601String().substring(0, 10);

    var openQuery =
        'repo:FirebaseExtended/flutterfire is:issue sort:updated-desc created:${fromStamp}..${toStamp}';

    var closedQuery =
        'repo:FirebaseExtended/flutterfire is:issue sort:updated-desc closed:${fromStamp}..${toStamp}';
    if (opts.showQueries) {
      print(openQuery);
      print(closedQuery);
    }
    // Now do the same for performance issues.
    var openIssues = github.searchIssuePRs(openQuery);
    var closedIssues = github.searchIssuePRs(closedQuery);

    List<Issue> openedThisPeriod = [];
    List<Issue> closedThisPeriod = [];

    await for (var issue in openIssues) {
      if (issue.createdAt.compareTo(opts.from) >= 0 &&
          issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
    }

    await for (var issue in closedIssues) {
      if (issue.closedAt.compareTo(opts.from) >= 0 &&
          issue.closedAt.compareTo(opts.to) <= 0) closedThisPeriod.add(issue);
    }

    var meanComputerUntilClosed = MeanComputer();
    var meanComputerOpenClosed = MeanComputer();
    meanComputerUntilClosed.computeMean(openedThisPeriod);
    meanComputerOpenClosed.computeMean(closedThisPeriod);

    // Compute mean over all priorities
    var row = '${toStamp}';
    ;
    row = '${row}\t${meanComputerUntilClosed.meanDuration.inHours}';
    row = '${row}\t${meanComputerOpenClosed.meanDuration.inHours}';
    print(row);

    // Skip to the next period
    current = next;
  }
}
