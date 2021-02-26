import 'dart:collection';
import 'dart:math';

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
        'Usage: dart bin/enumerate_team_members.dart [-always-include-team] org-login');
    print('\te.g., dart bin/enumerate_team_members.dart flutter');
    print(_parser.usage);
  }
}

class MemberInfo {
  String _login;
  get login => _login;
  bool _googler;
  DateTime firstContributed;
  dynamic firstContribution;
  DateTime lastContributed;
  dynamic lastContribution;

  MemberInfo(this._login);
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  // Enumerate all of the teams and get all of the members of all of the teams.
  var org = await github.organization(opts.login);
  var allMembers = Map<String, MemberInfo>();
  var membersByTeam = SplayTreeMap<String, List<String>>();
  await for (var team in org.teamsStream) {
    var membersThisTeam = List<String>();
    await for (var member in team.membersStream) {
      membersThisTeam.add(member.login);
      allMembers[member.login] = MemberInfo(member.login);
    }
    membersThisTeam.sort();
    membersByTeam[team.name] = membersThisTeam;
  }

  // Now go back and find out when they contributed
  for (var login in allMembers.keys) {
    var earliestQuery = 'org:flutter involves:${login} sort:updated-asc';
    var earlistItem = await github.searchIssuePRs(earliestQuery).isEmpty
        ? null
        : await github.searchIssuePRs(earliestQuery).first;
    allMembers[login].firstContribution = earlistItem;
    var latestQuery = 'org:flutter involves:${login} sort:updated-desc';
    var latestItem = await github.searchIssuePRs(latestQuery).isEmpty
        ? null
        : await github.searchIssuePRs(latestQuery).first;
    allMembers[login].lastContribution = latestItem;
  }

  print('Teams and members in the ${opts.login} organization');
  print('Team\tGithub login\tEarliest contribution\tLatest contribution');
  for (var team in membersByTeam.keys) {
    if (!opts.alwaysIncludeTeam) print('${team}');
    for (var member in membersByTeam[team]) {
      var row = opts.alwaysIncludeTeam ? '${team}\t${member}' : '\t${member}';
      var contributor = allMembers[member];
      row +=
          '\t${contributor.firstContribution?.url}\t${contributor.lastContribution?.url}';
      print(row);
    }
  }
}
