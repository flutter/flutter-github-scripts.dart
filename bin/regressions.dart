import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;

  bool? get between => _results['between'];
  bool? get tsv => _results['tsv'];
  DateTime? get from => DateTime.parse(_results.rest[0]);
  DateTime? get to => DateTime.parse(_results.rest[1]);
  int? get exitCode => _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('between',
          defaultsTo: false,
          abbr: 'b',
          negatable: false,
          help: 'do only for a date range')
      ..addFlag('tsv',
          defaultsTo: false, abbr: 't', negatable: true, help: 'output TSV');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results['between'] && _results.rest.length != 2) {
        throw ('--between requires two dates in ISO format');
      }
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print(
        'Usage: pub run regressions.dart [--tsv] [--between fromDate toDate]');
    print('Prints regressions found in specific releases by release.');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  GitHubIssueType type = GitHubIssueType.issue;

  final states = [GitHubIssueState.open, GitHubIssueState.closed];
  var items = [];

  for (var state in states) {
    items.addAll(await github.fetch(
      owner: 'flutter',
      name: 'flutter',
      type: type,
      state: state,
    ));
  }

  Cluster byLabel;
  byLabel = Cluster.byLabel(items);
  final foundInKeyword = 'found in release:';
  final severeKeyword = 'severe: regression';

  // Strip all but the found-in labels.
  var allLabels = <String>[...byLabel.keys];
  for (var label in allLabels) {
    if (!label.startsWith(foundInKeyword)) byLabel.remove(label);
  }

  var sectionHeader = opts.tsv! ? '' : '# ';
  var subsectionHeader = opts.tsv! ? '' : '## ';
  var trailing = opts.tsv! ? '' : '\n';
  print(
      '${sectionHeader}Open and closed regressions in flutter/flutter by release$trailing');

  // For each label in sorted order, print only those that are
  // marked with the 'severe: regression' label.
  var releaseLabels = [...byLabel.keys];
  releaseLabels.sort((a, b) => a.compareTo(b));
  for (var label in releaseLabels) {
    print('$subsectionHeader$label$trailing');
    if (opts.tsv!) print(Issue.tsvHeader);
    for (var item in byLabel[label]) {
      var issue = item as Issue;
      if (!issue.labels.containsString(severeKeyword)) continue;
      if (opts.tsv!) {
        print(issue.toTsv());
      } else {
        print(issue.summary(
            boldInteresting: true, linebreakAfter: true, includeLabels: true));
      }
    }
  }
}
