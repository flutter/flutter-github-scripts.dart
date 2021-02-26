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

enum When { first, last }

findWhen(dynamic item, String login, When w) {
  DateTime result;
  switch (w) {
    case When.first:
      if (item.author?.login == login) {
        result = item.createdAt;
      } else {
        // Maybe they're in the timeline?
        if (item.timeline != null)
          for (var timelineItem in item.timeline.timeline) {
            if (timelineItem.actor != null &&
                timelineItem.actor.login == login) {
              result = timelineItem.createdAt;
              break;
            }
          }
        // The timeline can be incomplete; if so, just use the creation date.
        if (result == null) result = item.createdAt;
      }
      break;

    case When.last:
      // Timelines happen after creation.
      if (item.timeline != null)
        for (var timelineItem in item.timeline.timeline) {
          if (timelineItem.actor != null && timelineItem.actor.login == login) {
            result = timelineItem.createdAt;
            break;
          }
        }
      // The timeline can be incomplete; if so, just use the creation date.
      if (result == null) result = item.createdAt;
      break;
  }
  return result;
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
    var member = allMembers[login];
    var earliestQueryAuthor = 'org:flutter author:${login} sort:updated-asc';
    var earliestQueryCommenter =
        'org:flutter commenter:${login} sort:updated-asc';

    var earliestAuthored;
    try {
      earliestAuthored = await github.searchIssuePRs(earliestQueryAuthor).first;
    } catch (e) {}

    var earliestCommented;
    try {
      earliestCommented =
          await github.searchIssuePRs(earliestQueryCommenter).first;
    } catch (e) {}

    if (earliestAuthored == null && earliestCommented == null) {
      member.firstContributed = null;
      member.firstContribution = null;
    } else if (earliestAuthored == null && earliestCommented != null) {
      member.firstContributed = findWhen(earliestCommented, login, When.first);
      member.firstContribution = earliestCommented;
    } else if (earliestAuthored != null && earliestCommented == null) {
      member.firstContributed = findWhen(earliestAuthored, login, When.first);
      member.firstContribution = earliestAuthored;
    } else if (findWhen(earliestCommented, login, When.first)
        .isBefore(findWhen(earliestAuthored, login, When.first))) {
      member.firstContributed = findWhen(earliestCommented, login, When.first);
      member.firstContribution = earliestCommented;
    } else {
      member.firstContributed = findWhen(earliestAuthored, login, When.first);
      member.firstContribution = earliestAuthored;
    }

    var latestQueryAuthor = 'org:flutter author:${login} ';
    var latestQueryCommenter =
        'org:flutter commenter:${login} sort:updated-asc';

    var latestAuthored;
    try {
      latestAuthored = await github.searchIssuePRs(latestQueryAuthor).first;
    } catch (e) {}

    var latestCommented;
    try {
      latestCommented = await github.searchIssuePRs(latestQueryCommenter).first;
    } catch (e) {}

    if (latestAuthored == null && latestCommented == null) {
      member.firstContributed = null;
      member.firstContribution = null;
    } else if (latestAuthored == null && latestCommented != null) {
      member.lastContributed = findWhen(latestCommented, login, When.last);
      member.lastContribution = latestCommented;
    } else if (latestAuthored != null && latestCommented == null) {
      member.lastContributed = findWhen(latestAuthored, login, When.last);
      member.lastContribution = latestAuthored;
    } else if (findWhen(latestCommented, login, When.last)
        .isAfter(findWhen(latestAuthored, login, When.last))) {
      member.lastContributed = findWhen(latestCommented, login, When.last);
      member.lastContribution = latestCommented;
    } else {
      member.lastContributed = findWhen(latestAuthored, login, When.last);
      member.lastContribution = latestAuthored;
    }
  }

  print('Teams and members in the ${opts.login} organization');
  print(
      'Team\tGithub login\tFirst contributed\tEarliest contribution\tLast contributed\tLatest contribution');
  for (var team in membersByTeam.keys) {
    if (!opts.alwaysIncludeTeam) print('${team}');
    for (var member in membersByTeam[team]) {
      var row = opts.alwaysIncludeTeam ? '${team}\t${member}' : '\t${member}';
      var contributor = allMembers[member];
      if (contributor.firstContribution == null) {
        row += '\t\t';
      } else {
        row += '\t${contributor.firstContributed?.toIso8601String()}';
        row +=
            '\t=HYPERLINK("${contributor.firstContribution?.url}","${contributor.firstContribution?.number}")';
      }
      if (contributor.lastContribution == null) {
        row += '\t\t';
      } else {
        row += '\t${contributor.lastContributed?.toIso8601String()}';
        row +=
            '\t=HYPERLINK("${contributor.lastContribution?.url}","${contributor.lastContribution?.number}")';
      }
      print(row);
    }
  }
}
