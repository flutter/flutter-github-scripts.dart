import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  /*late*/ ArgResults _results;
  String get login => _results.rest[0];
  int get exitCode => _results['help'] ? 0 : null;
  bool get tsv => _results['tsv'] /*!*/;
  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage');
    //..addFlag('tsv', defaultsTo: false, abbr: 't', negatable: true, help: 'show results as TSV');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results.rest.length != 1) throw ('invalid organization!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: dart bin/organization.dart login');
    print('\te.g., dart run bin/organization.dart flutter');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var org = await github.organization(opts.login);

  print('id:\t${org.id}');
  print('name:\t${org.name}');
  print('c:\t${org.createdAt}');
  print('aUrl:\t${org.avatarUrl}');
  print('email:\t${org.email}');
  print('login:\t${org.login}');
  print('description:\n-----');
  print('${org.description}');
  print('-----\tTeams\n-----');

  var teams = '';
  await for (var team in org.teamsStream) {
    teams = '${teams}${team.name}, ';
  }
  print(teams);
}
