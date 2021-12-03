import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults? _results;
  String get id => _results!.rest[0];
  int? get exitCode => _results == null
      ? -1
      : _results!['help']
          ? 0
          : null;
  bool? get tsv => _results!['tsv'];
  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage');
    //..addFlag('tsv', defaultsTo: false, abbr: 't', negatable: true, help: 'show results as TSV');
    try {
      _results = _parser.parse(args);
      if (_results!['help']) _printUsage();
      if (_results!.rest.length != 1) throw ('invalid id!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: dart bin/team.dart teamId');
    print('\te.g., dart run bin/team.dart MDQ6VGVhbTM3MzAzNzU=');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var team = await github.team(opts.id);

  print('id:\t${team.id}');
  print('name:\t${team.name}');
  print('c:\t${team.createdAt}');
  print('u:\t${team.updatedAt}');
  print('aUrl:\t${team.avatarUrl}');
  print('description:\n-----');
  print('${team.description}');
  print('-----\nmembers\n-----');
  var members = '';
  await for (var member in team.membersStream) {
    members = '${members}${member.login}, ';
  }
  print(members);
}
