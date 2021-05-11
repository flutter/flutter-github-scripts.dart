import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  /*late*/ ArgResults _results;
  int get number => int.parse(_results.rest[0]);
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;
  bool get tsv => _results['tsv'] /*!*/;
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
      if (_results.rest.length != 1) throw ('invalid pr number!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run pr.dart [--tsv] pr_number');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var pr = await github.pullRequest(
      owner: 'flutter', name: 'flutter', number: opts.number);

  var result = opts.tsv
      ? PullRequest.tsvHeader + '\n' + pr.toTsv()
      : pr.summary(linebreakAfter: true);
  print(result);
}
