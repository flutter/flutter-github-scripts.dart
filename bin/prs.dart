import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;
  bool get showClosed => _results['closed']!;
  bool get showMerged => _results['merged']!;
  bool get tsv => _results['tsv']!;
  bool get skipAutorollers => _results['skip-autorollers'];
  String? get label => _results['label'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int? get exitCode => _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed',
          defaultsTo: false,
          abbr: 'c',
          negatable: false,
          help: 'show closed PRs in date range')
      ..addFlag('merged',
          defaultsTo: false,
          abbr: 'm',
          negatable: false,
          help: 'show merged PRs in date range')
      ..addFlag('tsv',
          defaultsTo: false,
          abbr: 't',
          negatable: true,
          help: 'show results as TSV')
      ..addFlag('skip-autorollers',
          defaultsTo: false,
          abbr: 's',
          negatable: true,
          help: 'skip autorollers')
      ..addOption('label',
          defaultsTo: null, abbr: 'l', help: 'only issues with this label');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if ((_results['closed'] || _results['merged']) &&
          _results.rest.length != 2)
        throw ArgParserException('need start and end dates!');
      if (_results['merged'] && _results['closed'])
        throw ArgParserException(
            '--merged and --closed are mutually exclusive!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print(
        'Usage: pub run prs.dart [--tsv] [--label] [--closed fromDate toDate] [--merged fromDate toDate] [--closed fromDate toDate]');
    print('Prints PRs in flutter/flutter, flutter/engine repositories.');
    print('  --merged and --closed are mutually exclusive');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);

  final repos = ['flutter', 'engine', 'plugins'];

  final rollers = [
    'engine-flutter-autoroll',
    'skia-flutter-autoroll',
  ];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange? when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed || opts.showMerged) {
    state = opts.showClosed ? GitHubIssueState.closed : GitHubIssueState.merged;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = opts.showClosed
        ? GitHubDateQueryType.closed
        : GitHubDateQueryType.merged;
  }

  for (var repo in repos) {
    var prs = await github.fetch(
        owner: 'flutter',
        name: repo,
        type: GitHubIssueType.pullRequest,
        state: state,
        dateQuery: rangeType,
        dateRange: when);

    var headerDelimiter = opts.tsv ? '' : '### ';
    var type = 'Open';
    if (opts.showMerged) type = 'Merged';
    if (opts.showClosed) type = 'Closed';
    print("${headerDelimiter}${type} PRs in `flutter/${repo}` from " +
        opts.from.toIso8601String() +
        ' to ' +
        opts.to.toIso8601String());
    print("There were ${prs.length} pull requests.\n");

    if (opts.tsv) print(PullRequest.tsvHeader);
    for (var pr in prs) {
      if (opts.label != null && !pr.labels.containsString(opts.label)) continue;
      var pullRequestString =
          opts.tsv ? pr.toTsv() : pr.summary(linebreakAfter: true);
      var printIt = true;
      for (var roller in rollers) {
        if ((pr as PullRequest).author.toString() == roller) {
          printIt = false || !opts.skipAutorollers;
          break;
        }
      }
      if (printIt) print(pullRequestString);
    }
  }
}
