import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  String get login => _results.rest[0];
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;
  bool get tsv => _results['tsv'];
  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage');
      //..addFlag('tsv', defaultsTo: false, abbr: 't', negatable: true, help: 'show results as TSV');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results.rest.length != 1 ) throw('invalid id!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run organization login');
    print('\te.g., dart run bin/team.dart flutter=');
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
  print('-----\nmembers\n-----');

  /*
  var members = '';
  await for (var member in team.membersStream) {
    members = '${members}${member.login}, ';
  }
  print(members);
  */

}
