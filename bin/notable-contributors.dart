import 'dart:io';

import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  bool get showMerged => _results['merged'];
  bool get onlyNotable => !_results['all-contributors'];
  bool get authors => _results['authors'];
  bool get reviewers => _results['reviewers'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed',
          defaultsTo: false,
          abbr: 'c',
          negatable: false,
          help: 'show punted issues in date range')
      ..addFlag('merged',
          defaultsTo: false,
          abbr: 'm',
          negatable: false,
          help: 'show merged PRs in date range')
      ..addFlag("all-contributors",
          defaultsTo: false,
          abbr: 'a',
          negatable: true,
          help: 'show all instead of community contributors')
      ..addFlag('authors',
          defaultsTo: false, negatable: false, help: 'report for authors')
      ..addFlag('reviewers',
          defaultsTo: false, negatable: false, help: 'report for reviewers');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if ((_results['closed'] || _results['merged']) &&
          _results.rest.length != 2) throw ('need start and end dates!');
      if (_results['merged'] && _results['closed'])
        throw ('--merged and --closed are mutually exclusive!');
      if (!_results['authors'] && !_results['reviewers'])
        throw ('must pass one of --authors or --reviewers!');
      if (_results['authors'] && _results['reviewers'])
        throw ('must pass only one of --authors or --reviewers!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub notable-contributors.dart [-closed fromDate toDate]');
    print(
        'Prints non-Google contributors by contributor cluster in the specified date range');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  // Find the list of folks we're interested in
  final orgMembersContents =
      File('go_flutter_org_members.csv').readAsStringSync();
  final orgMembers = const CsvToListConverter().convert(orgMembersContents);
  var paidContributors = <String>[];
  orgMembers.forEach((row) {
    if (opts.onlyNotable &&
            (row[3].toString().toUpperCase().contains('GOOGLE')) ||
        (row[3].toString().toUpperCase().contains('CANONICAL')))
      paidContributors.add(row[0].toString());
  });

  final repos = ['flutter', 'engine', 'plugins'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed || opts.showMerged) {
    state = opts.showClosed ? GitHubIssueState.closed : GitHubIssueState.merged;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  var prs = [];
  for (var repo in repos) {
    prs.addAll(await github.deprecated_search(
        owner: 'flutter',
        name: repo,
        type: GitHubIssueType.pullRequest,
        state: state,
        dateQuery: rangeType,
        dateRange: when));
  }

  var reportType = 'open';
  if (opts.showMerged) reportType = 'merged';
  if (opts.showClosed) reportType = 'closed';

  var kind = opts.authors ? 'contributing' : 'reviewing';
  var kindPastTense = opts.authors ? 'contributed' : 'reviewed';
  var people = opts.authors ? 'contributors' : 'reviewers';
  var paidUnpaid = opts.onlyNotable ? 'unpaid' : 'all';
  var paidUnPaidPeople = opts.onlyNotable ? 'unpaid ' : '';

  print(opts.showClosed || opts.showMerged
      ? "# ${paidUnpaid[0].toUpperCase()}${paidUnpaid.substring(1)} contributors ${kind} ${reportType} PRs from " +
          opts.from.toIso8601String() +
          ' to ' +
          opts.to.toIso8601String()
      : "# ${paidUnpaid[0].toUpperCase()}${paidUnpaid.substring(1)} contributors ${kind} ${reportType} PRs");

  // if (false) {
  //   print('## All issues\n');
  //   for (var pr in prs) print(pr.summary(linebreakAfter: true));
  //   print('\n');
  // }

  print('There were ${prs.length} pull requests.\n\n');
  var allParticipants = Set<String>();
  var unpaidContributions = <PullRequest>[];
  var paidContributions = <PullRequest>[];
  for (var item in prs) {
    var pullRequest = item as PullRequest;
    if (opts.authors &&
        pullRequest.author != null &&
        pullRequest.author.login != null) {
      allParticipants.add(pullRequest.author.login);
    } else {
      if (pullRequest.reviewers != null)
        for (var reviewer in pullRequest.reviewers) {
          allParticipants.add(reviewer.login);
        }
    }
    var wasUnpaid = false;
    if (opts.authors &&
        pullRequest.author != null &&
        !paidContributors.contains(pullRequest.author.login)) {
      wasUnpaid = true;
    } else if (opts.reviewers) {
      wasUnpaid = true;
      if (opts.reviewers) {
        if (pullRequest.reviewers != null &&
            pullRequest.reviewers.length != 0) {
          for (var reviewer in pullRequest.reviewers) {
            if (paidContributors.contains(reviewer.login)) {
              wasUnpaid = false;
              break;
            }
          }
        } else {
          wasUnpaid = false;
        }
      }
    }

    if (wasUnpaid) {
      unpaidContributions.add(pullRequest);
      continue;
    } else {
      paidContributions.add(pullRequest);
      continue;
    }
  }

  List<PullRequest> prsOfInterest = opts.onlyNotable
      ? unpaidContributions
      : (new List.from(unpaidContributions)..addAll(paidContributions));

  var clusters = opts.authors
      ? Cluster.byAuthor(prsOfInterest)
      : Cluster.byReviewers(prsOfInterest);

  clusters.clusters.remove('__unassigned__');

  print(
      '${prsOfInterest.length} PRs were ${kindPastTense} by ${paidUnpaid} members.\n\n');
  print(
      'There were ${clusters.keys.length} unique ${paidUnPaidPeople}s${people}.\n\n');

  print(clusters.toMarkdown(
      sortType: ClusterReportSort.byCount,
      skipEmpty: true,
      showStatistics: false));
}
