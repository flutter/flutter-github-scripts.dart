import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

import 'package:test/test.dart';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  bool get labels => _results['labels'];
  bool get authors => _results['authors'];
  bool get prs => _results['prs'];
  bool get issues => _results['issues'];
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'o', negatable: true, help: 'cluster open issues')
      ..addOption('from', defaultsTo: '2019-11-01', abbr: 'f', help: 'from date, ISO format yyyy-mm-dd')
      ..addOption('to', defaultsTo: DateTime.now().toIso8601String(), abbr: 't', help: 'to date, ISO format yyyy-mm-dd')
      ..addFlag('labels', defaultsTo: false, abbr: 'l', negatable: false, help: 'cluster by label')
      ..addFlag('authors', defaultsTo: false, abbr: 'a', negatable: false, help: 'cluster by authors')
      ..addFlag('prs', defaultsTo: false, abbr: 'p', negatable: false, help: 'cluster pull requests')
      ..addFlag('issues', defaultsTo: false, abbr: 'i', negatable: false, help: 'cluster issues');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results['labels'] && _results['authors']) { 
        throw('cannot cluster on both labels and authors');
      }
      if (!_results['labels'] && !_results['authors']) { 
        throw(ArgParserException('need to cluster on either labels or pull requests!'));
      }
      if (_results['prs'] && _results['issues']) { 
        throw(ArgParserException('cannot cluster both pull requests and issues at the same time!'));
      }
      if (!_results['prs'] && !_results['issues']) { 
        throw(ArgParserException('need to cluster either issues or pull requests!'));
      }
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print('Usage: pub run clusters.dart [-closed fromDate toDate] [-labels] [-authors] [-prs] [-issues]');
    print('Prints PRs in flutter/flutter, flutter/engine repositories.');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  var repos = opts.prs ? ['flutter', 'engine'] : ['flutter'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  GitHubIssueType type;
  if (opts.issues) type = GitHubIssueType.issue;
  if (opts.prs) type = GitHubIssueType.pullRequest;

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed) {
    state = GitHubIssueState.closed;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  for(var repo in repos) {
    var items = await github.fetch(owner: 'flutter', 
      name: repo, 
      type: type,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    );
      
    Cluster clusters;
    if (opts.labels) clusters = Cluster.byLabel(items);
    if (opts.authors) clusters = Cluster.byAuthor(items);

    print('## ' + (opts.issues ? 'Issues' : 'PRs' ) + ' by ' + (opts.authors ? 'author' : 'label') + 
      ' for `flutter/${repo} ' + 
      (opts.showClosed ? 'from ${opts.from.toIso8601String()} to ${opts.to.toIso8601String()}' : '') + '\n\n');

    print(clusters.toMarkdown());

    print('${clusters.clusters.keys.length} unique ' + (opts.labels ? 'labels.' : 'users.' ) );
  }
}
