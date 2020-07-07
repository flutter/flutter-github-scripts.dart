import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  bool get tsv => _results['tsv'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show closed PRs in date range')
      ..addFlag('tsv', defaultsTo: false, abbr: 't', negatable: true, help: 'show results as TSV');
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
    print('Usage: pub run prs.dart [--tsv] [--closed fromDate toDate]');
    print('Prints PRs in flutter/flutter, flutter/engine repositories.');
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
    rangeType = GitHubDateQueryType.merged;
  }

  for(var repo in repos) {
    var prs = await github.fetch(owner: 'flutter', 
      name: repo, 
      type: GitHubIssueType.pullRequest,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    );
    

    var headerDelimiter = opts.tsv ? '' : '## ';
    print( opts.showClosed ? 
      "${headerDelimiter}PRs landed in flutter/${repo} from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
      "${headerDelimiter}Open PRs in flutter/${repo}");

    if (opts.tsv) print(PullRequest.tsvHeader);
    for(var pr in prs) {
      var pullRequestString = opts.tsv ? pr.toTsv() : pr.summary(linebreakAfter: true);
      print(pullRequestString);
    }
  }
}
