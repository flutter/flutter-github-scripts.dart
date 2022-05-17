import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final ArgParser _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;
  bool? get showClosed => _results['closed'];
  bool? get showMerged => _results['merged'];
  DateTime? get from =>
      _results.rest.isNotEmpty ? DateTime.parse(_results.rest[0]) : null;
  DateTime? get to =>
      _results.rest.length >= 2 ? DateTime.parse(_results.rest[1]) : null;
  bool? get labels => _results['labels'];
  bool? get authors => _results['authors'];
  bool? get assignees => _results['assignees'];
  bool? get reviewers => _results['reviewers'];
  bool? get prs => _results['prs'];
  bool? get issues => _results['issues'];
  bool? get alphabetize => _results['alphabetize'];
  bool? get customers => _results['customers-only'];
  bool? get ranking => _results['ranking'];
  bool? get skipUninteresting => _results['skip-uninteresting-labels'];
  int? get exitCode => _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed',
          defaultsTo: false, negatable: true, help: 'cluster closed issues')
      ..addFlag('labels',
          defaultsTo: false,
          abbr: 'l',
          negatable: false,
          help: 'cluster by label')
      ..addFlag('skip-uninteresting-labels',
          defaultsTo: false,
          abbr: 's',
          negatable: true,
          help: 'skip uninteresting labels (e.g., \'cla: yes\')')
      ..addFlag('authors',
          defaultsTo: false,
          abbr: 'a',
          negatable: false,
          help: 'cluster by authors')
      ..addFlag('assignees',
          defaultsTo: false, negatable: false, help: 'cluster by assignee')
      ..addFlag('merged',
          defaultsTo: false,
          abbr: 'm',
          negatable: false,
          help: 'show merged PRs in date range')
      ..addFlag('prs',
          defaultsTo: false,
          abbr: 'p',
          negatable: false,
          help: 'cluster pull requests')
      ..addFlag('issues',
          defaultsTo: false,
          abbr: 'i',
          negatable: false,
          help: 'cluster issues')
      ..addFlag('alphabetize',
          defaultsTo: false,
          abbr: 'z',
          negatable: true,
          help: 'sort labels alphabetically')
      ..addFlag('customers-only',
          defaultsTo: false,
          abbr: 'c',
          negatable: true,
          help: 'for labels, show only labels with `customer:`')
      ..addFlag('ranking',
          defaultsTo: false,
          abbr: 'r',
          negatable: true,
          help: 'rank-order issues report in addition to clustering')
      ..addFlag('reviewers',
          defaultsTo: false, negatable: true, help: 'cluster by reviewer');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results['labels'] && _results['authors']) {
        throw ('cannot cluster on both labels and authors');
      }
      if (!_results['labels'] &&
          !_results['authors'] &&
          !_results['assignees']) {
        throw (ArgParserException('need to labels, authors, or assignees!'));
      }
      if (_results['prs'] && _results['issues']) {
        throw (ArgParserException(
            'cannot cluster both pull requests and issues at the same time!'));
      }
      if (!_results['prs'] && !_results['issues']) {
        throw (ArgParserException(
            'need to cluster either issues or pull requests!'));
      }
      if (_results['merged'] && _results['closed']) {
        throw ('--merged and --closed are mutually exclusive!');
      }
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print(
        'Usage: pub run clusters.dart [--labels] [--skip-uninteresting-labels] [--authors] [--assignees] [--reviewers] [--prs] [--issues] [--merged fromDate toDate] [--closed fromDate toDate]');
    print('Prints PRs in flutter/flutter, flutter/engine repositories.');
    print('  Dates are in ISO 8601 format');
    print('  --merged and --closed are mutally exclusive');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);
  var keys = <String?>{};

  final repos = opts.prs! ? ['flutter', 'engine', 'plugins'] : ['flutter'];
  final labelsToSkip = ['cla: yes', 'waiting for tree to go green'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  GitHubIssueType? type;
  if (opts.issues!) type = GitHubIssueType.issue;
  if (opts.prs!) type = GitHubIssueType.pullRequest;

  var state = GitHubIssueState.open;
  DateRange? when;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed! || opts.showMerged!) {
    state =
        opts.showClosed! ? GitHubIssueState.closed : GitHubIssueState.merged;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  for (var repo in repos) {
    var items = await github.fetch(
        owner: 'flutter',
        name: repo,
        type: type,
        state: state,
        dateQuery: rangeType,
        dateRange: when);

    late Cluster clusters;
    if (opts.labels!) clusters = Cluster.byLabel(items);
    if (opts.authors!) clusters = Cluster.byAuthor(items);
    if (opts.assignees!) clusters = Cluster.byAssignees(items);
    if (opts.reviewers!) clusters = Cluster.byReviewers(items);

    for (var key in clusters.clusters.keys) {
      keys.add(key);
    }

    var what = '';
    if (opts.authors!) what = 'authors';
    if (opts.labels!) what = 'labels';
    if (opts.assignees!) what = 'owners';

    var reportType = 'Open';
    if (opts.showMerged!) reportType = 'Merged';
    if (opts.showClosed!) reportType = 'Closed';
    print(
        '### $reportType ${opts.issues! ? 'issues' : 'PRs'} by $what for `flutter/$repo` ${opts.showClosed! ? 'from ${opts.from!.toIso8601String()} to ${opts.to!.toIso8601String()}' : ''}\n\n');

    if (opts.customers!) {
      Set<String?> toRemove = <String?>{};
      for (var label in clusters.clusters.keys) {
        if (label.indexOf('customer: ') != 0) toRemove.add(label);
      }
      for (var label in toRemove) {
        clusters.remove(label);
      }
    }

    if (opts.labels! && opts.skipUninteresting!) {
      Set<String?> toRemove = <String?>{};
      for (var label in clusters.clusters.keys) {
        if (labelsToSkip.contains(label)) toRemove.add(label);
      }
      for (var label in toRemove) {
        clusters.remove(label);
      }
    }

    print(clusters.toMarkdown(
        sortType: (opts.alphabetize!
            ? ClusterReportSort.byKey
            : ClusterReportSort.byCount),
        skipEmpty: true,
        showStatistics: false));

    if (opts.authors!) {
      print(
          '${clusters.clusters.keys.length} unique ${opts.labels! ? 'labels.' : 'users'} across this repository.\n\n');
    }

    if (opts.ranking!) {
      print(
          '### Customer ${opts.issues! ? 'issues' : 'PRs'} rank-ordered by label');
      for (var customer in clusters.clusters.keys) {
        var labelCountsByLabel = <String?, int>{};
        for (var item in clusters.clusters[customer]) {
          for (var labelItem in item.labels.labels) {
            var label = labelItem as Label;
            if (!labelCountsByLabel.containsKey(label.label)) {
              labelCountsByLabel[label.label] = 1;
            } else {
              labelCountsByLabel[label.label] =
                  labelCountsByLabel[label.label]! + 1;
            }
          }
        }
        var rankedLabelList = labelCountsByLabel.keys.toList();
        // REVERSE sort, not incremental sort
        rankedLabelList.sort(
            (a, b) => labelCountsByLabel[b]!.compareTo(labelCountsByLabel[a]!));

        print('#### $customer\n\n');
        for (var labelName in rankedLabelList) {
          print('  * $labelName: ${labelCountsByLabel[labelName]}\n');
        }
      }
    }
  }

  if (opts.authors!) {
    print(
        'A total of ${keys.length} unique ${opts.labels! ? 'labels' : 'users'} across all repositories.\n\n');
  }
}
