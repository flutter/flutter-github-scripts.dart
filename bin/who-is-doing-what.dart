import 'dart:collection';

import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get list => _results['list'];
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('list', defaultsTo: true, abbr: 'l', negatable: true, help: 'show results as a list instead of columns');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run who-is-doing-what.dart [--list]');
    print('Prints people on the Flutter team and what they have signed up to do.');
    print(_parser.usage);
  }
}

final _noMilestone = Milestone('No milestone assigned', '', -1, '', null, null, null, DateTime(2099, 12, 31));

Map<Milestone, List<dynamic>> clusterByMilestones(List<dynamic> issues) {
  var result = Map<Milestone, List<dynamic>>();
  result[_noMilestone] = List<dynamic>(); 

  for(var item in issues) {
    if( !(item is Issue) && !(item is PullRequest)) {
      throw('invalid type!');
    }
    if (item.milestone == null) {
      result[_noMilestone].add(item);
    } else  {
      if (!result.containsKey(item.milestone)) {
        result[item.milestone] = List<dynamic>();
      }
      result[item.milestone].add(item);
    }
  }
  return result;
}

void main(List<String> args) async {
  final priorities = {'P0', 'P1', 'P2', 'P3', 'P4 ', 'P5', 'P6' };
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  // Find the list of folks we're interested in
  final orgMembersContents = File('go_flutter_org_members.csv').readAsStringSync();
  final orgMembers = const CsvToListConverter().convert(orgMembersContents);
  var teamMembers = List<String>();
  orgMembers.forEach((row) { 
    if (row[7].toString().toUpperCase().startsWith('Y')) teamMembers.add(row[0].toString()); 
  });

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;


  var issues = await github.fetch(owner: 'flutter', 
    name: 'flutter', 
    type: GitHubIssueType.issue,
    state: state,
    dateQuery: rangeType,
    dateRange: when
  );
  

  // For each team member, show each milestone in turn,
  // with a rank order by priority of issues in that milestone.
  var byAssignee = Cluster.byAssignees(issues);
  for(var teamMember in teamMembers) {
    if (byAssignee.clusters[teamMember] == null || byAssignee.clusters[teamMember].length == 0) {
      if (opts.list) print('## ${teamMember} has not self-assigned any issues.\n');
      continue;
    }
    // else
    if (opts.list) print('## ${teamMember} working ${byAssignee.clusters[teamMember].length} issues\n');

    print(teamMember);

    // Get the issues sorted into milestones, most recent first.
    var issuesByMilestone = clusterByMilestones(byAssignee.clusters[teamMember]);
    var milestones = issuesByMilestone.keys.toList();
    milestones.sort((a, b) {
      if (a.dueOn != null && b.dueOn == null) return -1;
      if (a.dueOn == null && b.dueOn != null) return 1;
      if (a.dueOn == null && b.dueOn == null) return 0;
      return a.dueOn.isBefore(b.dueOn) ? -1 : 1;
    });

    // Show the contents of each milestone, rank-ordered by priority
    for(var milestone in milestones) {
      if (opts.list) print('### ${milestone.title}\n');
      // Now group by label, so we can filter on priority
      var issuesByLabel = Cluster.byLabel(issuesByMilestone[milestone]);

      // First show the prioritized items, by each priority...
      var shown = List<Issue>();
      for(var label in priorities) {
        if(issuesByLabel.clusters.keys.contains(label)) {
          if (opts.list) print('#### ${label}\n');
          for(var item in issuesByLabel.clusters[label]) {
            var issue = item as Issue;
            if (opts.list) print(issue.summary(boldInteresting: false, linebreakAfter: true));
            shown.add(issue);
          }
        }
      }
      // And now show unprioritized items, if there are any.
      if (shown.length != issuesByMilestone[milestone]) {
        if (opts.list) print('#### Unprioritized\n');
        for(var item in issuesByMilestone[milestone]) {
          var issue = item as Issue;
          if (!shown.contains(issue) && opts.list) print(issue.summary(boldInteresting: false, linebreakAfter: true));
        }
      }
    }
  }
}
