import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:collection';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  DateTime get from => DateTime.parse(_results['from']);
  DateTime get to => DateTime.parse(_results['to']);
  bool get summarize => _results['summarize'];
  bool get showQueries => _results['queries'];
  bool get onlyCustomers => _results['customers'];
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
      ..addFlag('summarize',
          abbr: 's',
          defaultsTo: false,
          help: 'Show only summary tables in markdown format.')
      ..addFlag('queries',
          abbr: 'q', defaultsTo: false, help: 'Show queries used')
      ..addFlag('customers',
          abbr: 'c',
          defaultsTo: false,
          help: 'Only show issues with customer labels');
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
        'Usage: pub run priority_over_time.dart [--queries]  [--customers] [--summarize] --from date --to date');
    print(_parser.usage);
  }
}

int countWithOrWithoutCustomers(List<dynamic> issues, {bool onlyCustomers}) {
  var count = issues.length;
  if (onlyCustomers) {
    bool hasCustomer = false;
    for (var item in issues) {
      var issue = item as Issue;
      for (var label in issue.labels.labels) {
        if (label.label.contains('customer:')) {
          hasCustomer = true;
          break;
        }
      }
      if (!hasCustomer) {
        count--;
      }
    }
  }
  return count;
}

Duration meanDurationWithOrWithoutCustomers(List<dynamic> issues,
    {bool onlyCustomers}) {
  double sum = 0.0;
  var count = issues == null ? 0 : issues.length;
  if (count == 0) return Duration(seconds: 0);
  bool hasCustomer = false;
  for (var item in issues) {
    var issue = item as Issue;
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
  if (count == 0)
    return Duration(seconds: 0);
  else {
    int sumAsInt = sum.toInt();
    int mean = sumAsInt ~/ count;
    return Duration(seconds: mean);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  DateTime current = opts.from, last = opts.to;

  if (opts.summarize) {
    print(
        'This shows the number of new, open, and closed `P0`, `P1`, and `P2` issues over the period from');
    print('${opts.from} to ${opts.to}.');
    if (opts.onlyCustomers)
      print('Only issues with at least one `customer` label are presented.');
    print(
        'Period ending\tCreated P0s\tCreated P1s\tCreated P2s\tClosed P0s\tClosed P1s\tClosed P2s\tMean hours to close P1\tMean hours to close P2\tMean hours to close P3');
  }
  while (current.isBefore(last)) {
    var next = current.add(Duration(days: 7));
    var fromStamp = current.toIso8601String().substring(0, 10);
    var toStamp = next.toIso8601String().substring(0, 10);

    var openQuery =
        'org:flutter is:issue sort:updated-desc created:${fromStamp}..${toStamp}';

    var closedQuery =
        'org:flutter is:issue sort:updated-desc closed:${fromStamp}..${toStamp}';
    if (opts.showQueries) {
      print(openQuery);
      print(closedQuery);
    }
    // Now do the same for performance issues.
    var openIssues = await github.searchIssuePRs(openQuery);
    var closedIssues = await github.searchIssuePRs(closedQuery);

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

    // Cluster them to get our counts by priority
    var openCluster = Cluster.byLabel(openedThisPeriod);
    var closedCluster = Cluster.byLabel(closedThisPeriod);
    final interestingPriorities = ['P0', 'P1', 'P2'];
    interestingPriorities.sort();

    if (opts.summarize) {
      var openCount = HashMap<String, int>();
      var closeCount = HashMap<String, int>();
      var mean = HashMap<String, Duration>();
      interestingPriorities.forEach((p) {
        var highPrioritizedIssuesOpened = openCluster[p];
        var highPrioritizedIssuesClosed = closedCluster[p];
        openCount[p] = highPrioritizedIssuesOpened == null
            ? 0
            : countWithOrWithoutCustomers(highPrioritizedIssuesOpened,
                onlyCustomers: opts.onlyCustomers);
        closeCount[p] = highPrioritizedIssuesClosed == null
            ? 0
            : countWithOrWithoutCustomers(highPrioritizedIssuesClosed,
                onlyCustomers: opts.onlyCustomers);
        mean[p] = meanDurationWithOrWithoutCustomers(
            highPrioritizedIssuesClosed,
            onlyCustomers: opts.onlyCustomers);
      });
      var row = '${toStamp}';
      interestingPriorities.forEach((p) => row = '${row}\t${openCount[p]}');
      interestingPriorities.forEach((p) => row = '${row}\t${closeCount[p]}');
      interestingPriorities.forEach((p) => row = '${row}\t${mean[p].inHours}');
      print(row);
    } else {
      print(
          'This shows the number of new, open, and closed `P0`, `P1`, and `P2` issues over the period from');
      print('${fromStamp} to ${toStamp}.\n\n');
      if (opts.onlyCustomers)
        print('Only issues with at least one `customer` label are presented.');

      print('### Issues open/closed by priority\n');
      print('| Priority | Opened | Closed | Total |');
      print('|----------|--------|--------|-------|');
      var totalOpen = 0, totalClosed = 0, total = 0;
      interestingPriorities.forEach((p) {
        var highPrioritizedIssuesOpened = openCluster[p];
        var highPrioritizedIssuesClosed = closedCluster[p];

        var openCount = highPrioritizedIssuesOpened == null
            ? 0
            : countWithOrWithoutCustomers(highPrioritizedIssuesOpened,
                onlyCustomers: opts.onlyCustomers);
        var closedCount = highPrioritizedIssuesClosed == null
            ? 0
            : countWithOrWithoutCustomers(highPrioritizedIssuesClosed,
                onlyCustomers: opts.onlyCustomers);
        var totalRow = openCount + closedCount;
        totalOpen += openCount;
        totalClosed += closedCount;
        total += totalRow;
        print('|${p}|${openCount}|${closedCount}|${totalRow}|');
      });
      print('|TOTAL|${totalOpen}|${totalClosed}|${total}|\n');
    }

    // Skip to the next period
    current = current.add(Duration(days: 7));
  }
}
