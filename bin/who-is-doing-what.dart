import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'package:columnar_output/columnar.dart' as columnar;
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  /*late*/ ArgResults _results;
  bool get list => _results['list'] /*!*/;
  bool get markdown => _results['markdown'] /*!*/;
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('list',
          defaultsTo: false,
          abbr: 'l',
          negatable: true,
          help: 'show results as a list instead of columns')
      ..addFlag('markdown',
          defaultsTo: false,
          abbr: 'm',
          negatable: true,
          help: 'show results in Markdown instead of HTML');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (list && !markdown) {
        print('Cannot output a list in HTML!');
        _printUsage();
        exit(-1);
      }
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run who-is-doing-what.dart [--list] [--html]');
    print(
        'Prints people on the Flutter team and what they have signed up to do.');
    print('HTML output only works for the default, not for list output.');
    print(_parser.usage);
  }
}

final _noMilestone = Milestone('No milestone assigned', '', -1, '', null, null,
    null, DateTime(2099, 12, 31));

Map<Milestone, List<dynamic>> clusterByMilestones(List<dynamic> issues) {
  var result = Map<Milestone, List<dynamic>>();
  result[_noMilestone] = [];

  for (var item in issues) {
    if (!(item is Issue) && !(item is PullRequest)) {
      throw ('invalid type!');
    }
    if (item.milestone == null) {
      result[_noMilestone].add(item);
    } else {
      if (!result.containsKey(item.milestone)) {
        result[item.milestone] = [];
      }
      result[item.milestone].add(item);
    }
  }
  return result;
}

columnar.Paragraph summary(Issue issue, String style) {
  final priorities = {'P0', 'P1', 'P2', 'P3', 'P4 ', 'P5', 'P6'};
  String priority;
  String resultText = '';
  priorities.forEach((label) {
    if (issue.labels.containsString(label)) priority = label;
  });
  priority = priority ?? '--';
  resultText = '<a href="${issue.url}">${issue.title}</a>';
  return columnar.Paragraph(text: resultText, styleClass: style);
}

var when = DateTime.now().toIso8601String();
var htmlHeader = '''
<!DOCTYPE HTML>
<html>
<head>
<style>
 :root { font-family: sans-serif; }
 * { padding: 0; margin: 0; text-align: left; }
 *:link, *:visited { color: inherit; font: inherit; text-decoration: underline; }
 h1 { margin: 0 0 0 1em; }
 table { display: inline-table; margin: 1em; border-collapse: collapse; table-layout: fixed; border: solid; vertical-align: top; width: 25em; }
 th, td { white-space: nowrap; overflow: hidden; padding: 0 0.1em 0.25em; }
 th { background: black; color: white; padding-top: 0.25em; }
 .milestone { background: gray; color: white; font-style: italic; padding-top: 0.2em; }
 .P0 { background: #FF0000; color: #FFFF00; }
 .P1 { background: #FF0000; color: #FFFFFF; }
 .P2 { background: #7F0000; color: #FFFFFF; }
 .P3 { background: #007F00; color: #FFFFFF; }
 .P4 { background: #003000; color: #FFFFFF; }
 .P5 { background: #003030; color: #7F7F7F; }
 .P6 { background: #001717; color: #7F7F7F; }
 .unprioritized { background: #0000FF; color: #FFFF00; }

 .demo { float: left; margin: 1em; padding: 1em; }
 .demo ~ :not(.demo) { clear: both; }
</style>
</head>

<body>
<h1>Who is doing what on Flutter ${when}</h1>
<p class="demo P0">P0</p>
<p class="demo P1">P1</p>
<p class="demo P2">P2</p>
<p class="demo P3">P3</p>
<p class="demo P4">P4</p>
<p class="demo P5">P5</p>
<p class="demo P6">P6</p>
<p class="demo unprioritized">unprioritized</p>
<hr>
''';

void main(List<String> args) async {
  final priorities = {'P0', 'P1', 'P2', 'P3', 'P4 ', 'P5', 'P6'};
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  // Find the list of folks we're interested in
  final orgMembersContents =
      File('go_flutter_org_members.csv').readAsStringSync();
  final orgMembers = const CsvToListConverter().convert(orgMembersContents);
  var teamMembers = <String>[];
  orgMembers.forEach((row) {
    if (row[7].toString().toUpperCase().startsWith('Y'))
      teamMembers.add(row[0].toString());
  });

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;

  var report = new columnar.Document();
  int column = -1;

  var issues = await github.fetch(
      owner: 'flutter',
      name: 'flutter',
      type: GitHubIssueType.issue,
      state: state,
      dateQuery: rangeType,
      dateRange: when);

  // For each team member, show each milestone in turn,
  // with a rank order by priority of issues in that milestone.
  var byAssignee = Cluster.byAssignees(issues);
  for (var teamMember in teamMembers) {
    column++;
    report.appendColumn();
    report[column].header = teamMember;

    if (byAssignee.clusters[teamMember] == null ||
        byAssignee.clusters[teamMember].length == 0) {
      if (opts.list)
        print('## ${teamMember} has not self-assigned any issues.\n');
      report[column].append(columnar.Paragraph(text: 'no issues'));
      continue;
    }

    // else
    if (opts.list)
      print(
          '## ${teamMember} working ${byAssignee.clusters[teamMember].length} issues\n');

    // Get the issues sorted into milestones, most recent first.
    var issuesByMilestone =
        clusterByMilestones(byAssignee.clusters[teamMember]);
    var milestones = issuesByMilestone.keys.toList();
    milestones.sort((a, b) {
      if (a.dueOn != null && b.dueOn == null) return -1;
      if (a.dueOn == null && b.dueOn != null) return 1;
      if (a.dueOn == null && b.dueOn == null) return 0;
      return a.dueOn.isBefore(b.dueOn) ? -1 : 1;
    });

    // Show the contents of each milestone, rank-ordered by priority
    for (var milestone in milestones) {
      if (opts.list) print('### ${milestone.title}\n');
      report[column].append(
          columnar.Paragraph(text: milestone.title, styleClass: 'milestone'));
      // Now group by label, so we can filter on priority
      var issuesByLabel = Cluster.byLabel(issuesByMilestone[milestone]);

      // First show the prioritized items, by each priority...
      var shown = <Issue>[];
      for (var label in priorities) {
        if (issuesByLabel.clusters.keys.contains(label)) {
          if (opts.list) print('#### ${label}\n');
          for (var item in issuesByLabel.clusters[label]) {
            var issue = item as Issue;
            if (opts.list)
              print(issue.summary(
                  boldInteresting: false,
                  linebreakAfter: true,
                  includeLabels: false));
            report[column].append(summary(issue, label));
            shown.add(issue);
          }
        }
      }
      // And now show unprioritized items, if there are any.
      if (shown.length != issuesByMilestone[milestone]) {
        if (opts.list) print('#### Unprioritized\n');
        for (var item in issuesByMilestone[milestone]) {
          var issue = item as Issue;
          if (!shown.contains(issue)) {
            if (opts.list)
              print(issue.summary(
                  boldInteresting: false,
                  linebreakAfter: true,
                  includeLabels: false));
            report[column].append(summary(issue, 'unprioritized'));
          }
        }
      }
    }
  }

  if (!opts.list) {
    if (opts.markdown) {
      print(report.toMarkdown(4));
    } else {
      print(htmlHeader);
      print(report.toHtml(1));
      print('</body>');
      print('</html>');
    }
  }
}
