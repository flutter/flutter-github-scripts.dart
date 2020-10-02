import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

/// 14330 has lots of items. 2020 has no items

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  int get number => int.parse(_results.rest[0]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;
  bool get tsv => _results['tsv'];

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('tsv',
          defaultsTo: false,
          abbr: 't',
          negatable: true,
          help: 'show results as TSV');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results.rest.length != 1) throw ('invalid issue number!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run issue.dart issue_number');
    print(_parser.usage);
  }
}

final _reactionQuery = r'''
query {
  repository(owner:"flutter", name:"flutter") {
		issue(number: ${issue}) {
        	reactions(first: 100, after: ${after}) {
          	totalCount,
            pageInfo {
              endCursor,
              hasNextPage,
            }
          	nodes {
            	content
            },
          },
        },
      },
    }
''';

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final github = GitHub(token);

  var issue = await github.issue(
      owner: 'flutter', name: 'flutter', number: opts.number);

  var result = opts.tsv
      ? Issue.tsvHeader + '\n' + issue.toTsv()
      : issue.summary(boldInteresting: true, linebreakAfter: true);
  print(result);

  // Now get all of the reactions from this issue. We do this with two streams:
  //   1. A stream of reactions on the issue.
  //   2. A stream of reactions on each comment.
  int sanity = 0;
  var stream = issue.reactionStream;
  await for (var reaction in stream) {
    sanity++;
    print('\t${reaction.content}');
  }
  print('${sanity} reactions.');
}
