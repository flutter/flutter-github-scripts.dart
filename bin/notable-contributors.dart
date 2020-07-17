import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  bool get showMerged => _results['merged'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show punted issues in date range')
      ..addFlag('merged', defaultsTo: false, abbr: 'm', negatable: false, help: 'show merged PRs in date range');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if ((_results['closed'] || _results['merged']) && _results.rest.length != 2 ) throw('need start and end dates!');
      if (_results['merged'] && _results['closed']) throw('--merged and --closed are mutually exclusive!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub notable-contributors.dart [-closed fromDate toDate]');
    print('Prints non-Google contributors by contributor cluster in the specified date range');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  // Find the list of folks we're interested in
  final orgMembersContents = File('go_flutter_org_members.csv').readAsStringSync();
  final orgMembers = const CsvToListConverter().convert(orgMembersContents);
  var googleContributors = List<String>();
  orgMembers.forEach((row) { 
    if (row[3].toString().toUpperCase().contains('GOOGLE')) googleContributors.add(row[0].toString()); 
  });

  final repos = ['flutter', 'engine'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed || opts.showMerged) {
    state = opts.showClosed ?  GitHubIssueState.closed : GitHubIssueState.merged;
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

    var reportType = 'oen';
    if (opts.showMerged) reportType = 'merged';
    if (opts.showClosed) reportType = 'closed';

  print(opts.showClosed || opts.showMerged ? 
    "# Non-Google contributors contributing ${reportType} PRs from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "# Non-Google contributors contributing ${reportType} PRs");

  if (false) {
    print('## All issues\n');
    for (var pr in prs) print(pr.summary(linebreakAfter: true));
    print('\n');
  }

  print("There were ${prs.length} pull requests.\n");

  var nonGoogleContributions = List<PullRequest>();
  int processed = 0;
  for(var item in prs) {
    var pullRequest = item as PullRequest;
    processed++;
      if (!googleContributors.contains(pullRequest.author.login)) {
        nonGoogleContributions.add(pullRequest);
        continue;
      }
      if (pullRequest.assignees != null) {
        for(var assignee in pullRequest.assignees) {
          if (!googleContributors.contains(assignee.login)) {
            nonGoogleContributions.add(pullRequest);
            break;
          }
        }
    }
  }


  var clustersInterestingOwned = Cluster.byAuthor(nonGoogleContributions);
  print(clustersInterestingOwned.toMarkdown(sortType: ClusterReportSort.byCount, skipEmpty: true, showStatistics: false));
}