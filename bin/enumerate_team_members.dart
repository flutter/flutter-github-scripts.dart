import 'dart:collection';

import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  String get login => _results.rest[0];
  bool get alwaysIncludeTeam => _results['always-include-team'];
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;
  bool get tsv => _results['tsv'];
  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('always-include-team',
          defaultsTo: false,
          abbr: 'a',
          negatable: false,
          help: 'include team name in each row.');
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
    print(
        'Usage: dart bin/enumerate_team_members.dart [-always-include-team] login');
    print('\te.g., dart bin/enumerate_team_members.dart flutter=');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var org = await github.organization(opts.login);
  var allMembers = Set<String>();
  var membersByTeam = SplayTreeMap<String, List<String>>();
  await for (var team in org.teamsStream) {
    var membersThisTeam = List<String>();
    await for (var member in team.membersStream) {
      membersThisTeam.add(member.login);
      allMembers.add(member.login);
    }
    membersThisTeam.sort();
    membersByTeam[team.name] = membersThisTeam;
  }

  print('Teams and members in the ${opts.login} organization');
  print('Team\tGithub login');
  for (var team in membersByTeam.keys) {
    if (!opts.alwaysIncludeTeam) print('${team}');
    for (var member in membersByTeam[team]) {
      print(opts.alwaysIncludeTeam ? '${team}\t${member}' : '\t${member}');
    }
  }
}
