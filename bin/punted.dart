import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  bool get includeMilestones => _results['include-milestones'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show punted issues in date range')
      ..addFlag('include-milestones', defaultsTo: false, abbr: 'i', negatable: true, help: 'show all milestones, too');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results['closed'] && _results.rest.length != 2 ) throw('need start and end dates!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run punted.dart [-include-milestones] [-closed fromDate toDate]');
    print('Prints punted issues in flutter/flutter.');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

bool eventIsMilestoneInMonth(TimelineItem milestone) {
  final monthAbbreviations = {
    'Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec',
  };

  if (milestone.type != 'MilestonedEvent' && milestone.type == 'DemilestonedEvent') return false;
  for(var monthAbbreviation in monthAbbreviations) {
    if (milestone.title != null && milestone.title.contains(monthAbbreviation)) return true;
  }
  return false;
}

void main(List<String> args) async {
  final uninterestingMilestones = {
    '__no milestone__', 
    '[DEPRECATED] Goals', 
    '[DEPRECATED] Near-term Goals', 
    '[DEPRECATED] Stretch Goals'
  };

  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed) {
    state = GitHubIssueState.closed;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  var issues = await github.fetch(owner: 'flutter', 
    name: 'flutter', 
    type: GitHubIssueType.issue,
    state: state,
    dateQuery: rangeType,
    dateRange: when
  );

  print(opts.showClosed ? 
    "# Closed issues from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "# Open issues" );

  if (false) {
    print('## All issues\n');
    for (var issue in issues) print(issue.summary(linebreakAfter: true));
    print('\n');
  }

  if (opts.includeMilestones) {
    print("## Issues by milestone\n");
    print("There were ${issues.length} issues.\n");

    var clusters = Cluster.byMilestone(issues);
    uninterestingMilestones.forEach((uninteresting) => clusters.remove(uninteresting)); 

    print(clusters.toMarkdown(sortType: ClusterReportSort.byCount, skipEmpty: true, showStatistics: false));
  }

  print((opts.showClosed ? 
    "## Closed issues punted from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "## Open issues punted"));

  var puntedCount = 0;
  for(var item in issues) {
    // typecast so we have easy auto-completion in Visual Studio Code
    var issue = item as Issue;
    var countMilestoned = 0;
    var countDemilestoned = 0;
    if (issue.timeline == null || issue.timeline.length < 2) continue;
    var milestoneEvents = List<TimelineItem>();
    for(var timelineItem in issue.timeline.timeline) {
      if (timelineItem.type == 'MilestonedEvent' || timelineItem.type == 'DemilestonedEvent') 
        milestoneEvents.add(timelineItem);
    }
    // We're interested in re-milestoning, which means at least two milestone events.
    if (milestoneEvents.length < 2 ) continue;

    // Walk each milestone/demilestone event
    var lastNotedMilestoneTitle = milestoneEvents[0].title;
    for(var i = 1; i < milestoneEvents.length; i++) {
      var timelineItem = milestoneEvents[i];

      // Check the month of the milestone.
      // If it's not the first event, compare it to the
      // monthtly milestone. If it's different, it's
      // been punted.
      bool punted = false;
      if (eventIsMilestoneInMonth(timelineItem) &&
        lastNotedMilestoneTitle != '' && 
        lastNotedMilestoneTitle != timelineItem.title) {
        punted = true;
        puntedCount++;
        lastNotedMilestoneTitle = milestoneEvents[i].title;
      }
      // If it was punted, update our counts.
      if (punted) {
        if (timelineItem.type == 'MilestonedEvent') {
          countMilestoned--;
        } else if (timelineItem.type == 'DemilestonedEvent') {
          countDemilestoned--;
        }
      }
    }
    // Was it initially assigned a milestone on creation and didn't get an event?
    // I'm not sure if this can happen with GitHub, but we don't want to miss it.
    if(issue.milestone != null && countMilestoned == 0) countMilestoned++;

    if (countMilestoned >= 1 || countDemilestoned > 0) {
      print('Issue [#${issue.number}](${issue.url}) "${issue.title}" punted ${countMilestoned} times, ' + 
        'unassigned a milestone ${countDemilestoned} times, now ' + 
        (issue.milestone == null ? 'not assigned a milestone' 
          : 'assigned to ${issue.milestone}\n'));
      for(var timelineItem in milestoneEvents) {
        if (timelineItem.type == 'MilestonedEvent') {
          print('  * assigned the ${timelineItem.title} milestone');
        } 
      }
      print('\n\n');
    }
  }

  print('\n\n${puntedCount} issues were punted from at least one milestone.');

}
