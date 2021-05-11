import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;
  String get query => _results.rest[0];
  int? get exitCode => _results['help'] ? 0 : null;
  bool get tsv => _results['tsv']!;
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
      if (_results.rest.length != 1)
        throw ArgParserException('invalid organization!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print('Usage: dart bin/search.dart [--tsv] githubquery');
    print(
        '\te.g., dart bin/search.dart "org:flutter involves:kf6gpe sort:updated-desc"');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  await for (var item in github.searchIssuePRs(opts.query)) {
    print(opts.tsv ? item.toTsv() : item.summary());
  }
}
