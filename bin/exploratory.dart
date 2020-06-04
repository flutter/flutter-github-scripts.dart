import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
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

  var repos = ['flutter', 'engine'];

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

  var prs = List<dynamic>();
  for(var repo in repos) {
    prs.addAll(await github.search(owner: 'flutter', 
      name: repo, 
      type: GitHubIssueType.pullRequest,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    ));
  }

  print(opts.showClosed ? 
    "# Closed PRs from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "# Open PRs from" );

  if (false) {
    print('## All prs\n');
    for (var pr in prs) print(pr.summary(linebreakAfter: true));
    print('\n');
  }

  print("There were ${prs.length} prs.\n");

  var countNoXref = 0;
  var countNoOwner = 0;
  var countNoMilestone = 0;
  for(var item in prs) {
    var pr = item as PullRequest;
    bool hasIssueXref = false;
    bool hasIssueOwner = false;
    bool hasIssueMilestone = false;
    if (pr.timeline != null) for(var timelineEntry in pr.timeline) {
        if (timelineEntry.type == 'CrossReferencedEvent') {
            hasIssueXref = true;
            var issue = await github.issue(owner:'flutter', name:'repo', number: timelineEntry.number);
            if (issue.assignees && issue.assignees.length) hasIssueOwner = true;
            if (issue.milestone != null) hasIssueMilestone = true;
        }
    }
    if (!hasIssueXref) { 
      print('! ' + pr.summary(linebreakAfter: true));
      countNoXref++;
    }
    if (hasIssueXref) {
      if (!hasIssueOwner) { 
        print('-O '+ pr.summary(linebreakAfter: true));
        countNoOwner++;
      }
      if (!hasIssueMilestone) {
        print('-M ' + pr.summary(linebreakAfter: true));
        countNoMilestone++;
      }
    }
  }

  print('${countNoXref} PRs did not have cross-references.\n');
  print('${countNoOwner} PRs did not have owners.\n');
  print('${countNoMilestone} PRs did not have milestones.\n');
}