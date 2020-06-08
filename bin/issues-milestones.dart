import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show punted issues in date range');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results['closed'] && _results.rest.length != 2 ) throw('need start and end dates!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub exploratory prs.dart [-closed fromDate toDate]');
    // TODO
    print('TODO');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  // Find the list of folks we're interested in
  final orgReportsContents = File('org-reports.csv').readAsStringSync();
  final orgReports = const CsvToListConverter().convert(orgReportsContents);
  var interesting = List<String>();
  orgReports.forEach((row) { 
    if (row[1].toString().toUpperCase() == 'Y') interesting.add(row[0].toString()); 
  });

  final repos = ['flutter'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed) {
    state = GitHubIssueState.closed;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  var issues = List<dynamic>();
  for(var repo in repos) {
    issues.addAll(await github.fetch(owner: 'flutter', 
      name: repo, 
      type: GitHubIssueType.issue,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    ));
  }

  print(opts.showClosed ? 
    "# Closed issues from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "# Open issues" );

  if (false) {
    print('## All issues\n');
    for (var pr in issues) print(pr.summary(linebreakAfter: true));
    print('\n');
  }

  print("There were ${issues.length} issues.\n");

  var noMilestones = List<Issue>();
  var noAssigneesYetMilestoned = List<Issue>();
  var interestingOwnedIssues = List<Issue>();
  int processed = 0;
  for(var item in issues) {
    var issue = item as Issue;
    processed++;
    if (issue.assignees != null && issue.assignees.length != 0) {
      for(var assignee in issue.assignees) {
        if (interesting.contains(assignee.login)) {
          interestingOwnedIssues.add(issue);
        }
        if (issue.milestone == null ) {
          noMilestones.add(issue);
        }
      }
    }
    if (issue.milestone != null && (issue.assignees == null || issue.assignees.length == 0)) {
      if (issue.milestone.title == '[DEPRECATED] Goals' || 
         (issue.milestone.title == '[DEPRECATED] Stretch Goals') || 
         (issue.milestone.title == 'No milestone necessary') ||
         (issue.milestone.title == '[DEPRECATED] Near-term Goals') ||
         (issue.milestone.title == 'Old Stretch Goals') ||
         (issue.milestone.title == 'Unassigned customer work') ||
         (issue.milestone.title == 'Declined Customer Request') ||
         (issue.milestone.title == 'Overdue')
         ) continue;
      noAssigneesYetMilestoned.add(issue);
    }
  }


  var clustersNoMlestones = Cluster.byAssignees(noMilestones);
  var clustersInterestingOwned = Cluster.byAssignees(interestingOwnedIssues);
  List<String> noOwnedIssues = List<String>();
  noOwnedIssues.addAll(interesting);
  clustersInterestingOwned.clusters.keys.forEach((interestingUser) => noOwnedIssues.remove(interestingUser));

  print('## Issues owned by core team members at Google (${interestingOwnedIssues.length})\n');
  print('x̄ = ${clustersInterestingOwned.mean()}, σ = ${clustersInterestingOwned.stdev()}');
  print(clustersInterestingOwned.toMarkdown(sortType: ClusterReportSort.byCount, skipEmpty: true, showStatistics: true));

  print('## Core team members not owning any issues\n');
  noOwnedIssues.forEach((user) => print('  * ${user}\n'));

  print('## Owned issues with no milestone by owner (${noMilestones.length})\n');
  print(clustersNoMlestones.toMarkdown(sortType: ClusterReportSort.byKey, skipEmpty: true, showStatistics: false));

  print('## Issues with milestones and no owners (${noAssigneesYetMilestoned.length})');
  for(var issue in noAssigneesYetMilestoned) {
    print(issue.summary(linebreakAfter: true, boldInteresting: false));
  }



}