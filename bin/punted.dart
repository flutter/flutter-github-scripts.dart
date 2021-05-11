import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  late ArgResults _results;
  bool get dateRange => _results['date-range'];
  bool get includeMilestones => _results['include-milestones'];
  bool get tsvOutput => _results['tsv-output'];
  bool get markdownOutput => !tsvOutput;
  bool get onlyOpen => _results['only-open'];
  bool get onlyClosed => _results['only-closed'];
  late DateTime _from, _to;
  DateTime get from => _from;
  DateTime get to => _to;
  int? get exitCode => _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('date-range',
          defaultsTo: false,
          abbr: 'd',
          negatable: false,
          help: 'show punted issues in date range')
      ..addFlag('include-milestones',
          defaultsTo: false,
          abbr: 'i',
          negatable: true,
          help: 'show all milestones, too')
      ..addFlag('tsv-output',
          defaultsTo: false,
          abbr: 't',
          negatable: true,
          help: 'output is in tsv format')
      ..addFlag('only-open',
          defaultsTo: false, negatable: false, help: 'only show open issues')
      ..addFlag('only-closed',
          defaultsTo: false, negatable: false, help: 'only show closed issues');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results['date-range'] && _results.rest.length != 2) {
        throw ArgParserException('need start and end dates!');
      } else if (_results['date-range']) {
        _from = DateTime.parse(_results.rest[0]);
        _to = DateTime.parse(_results.rest[1]);
      } else {
        _from = DateTime(2015, 4, 29);
        _to = DateTime.now();
      }
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
      exit(-1);
    }
  }

  void _printUsage() {
    print(
        'Usage: pub run punted.dart [-include-milestones] [-date-range fromDate toDate]');
    print('Prints punted issues in flutter/flutter.');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

bool eventIsMilestoneInMonth(TimelineItem milestone) {
  final monthAbbreviations = {
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  };

  if (milestone.type != 'MilestonedEvent' &&
      milestone.type == 'DemilestonedEvent') return false;
  for (var monthAbbreviation in monthAbbreviations) {
    if (milestone.title != null && milestone.title!.contains(monthAbbreviation))
      return true;
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
  if (opts.exitCode != null) exit(opts.exitCode!);

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var issues = [];

  DateRange? when = null;
  var rangeType = GitHubDateQueryType.none;

  var state = GitHubIssueState.open;
  if (!opts.onlyClosed)
    issues.addAll(await github.fetch(
        owner: 'flutter',
        name: 'flutter',
        type: GitHubIssueType.issue,
        state: state,
        dateQuery: rangeType,
        dateRange: when));
  state = GitHubIssueState.closed;
  if (!opts.onlyOpen)
    issues.addAll(await github.fetch(
        owner: 'flutter',
        name: 'flutter',
        type: GitHubIssueType.issue,
        state: state,
        dateQuery: rangeType,
        dateRange: when));
  issues.sort((a, b) => a.number.compareTo(b.number));

  if (opts.tsvOutput) {
    print(opts.dateRange
        ? "Punted issues from " +
            opts.from.toIso8601String() +
            ' to ' +
            opts.to.toIso8601String()
        : "Punted issues");
    print(
        'Issue number\tIssue summary\tState\tNumber of punts\tOriginal milestone\tLast punt\tCurrent milestone');
  } else {
    print(opts.dateRange
        ? "# Punted issues from " +
            opts.from.toIso8601String() +
            ' to ' +
            opts.to.toIso8601String()
        : "# Punted issues");
  }

  // Lots o' debugging when this is enabled --- flip to true.
  // if (opts.markdownOutput && false) {
  //   print('## All issues\n');
  //   for (var issue in issues) print(issue.summary(linebreakAfter: true));
  //   print('\n');
  // }
  // End debugging

  if (opts.includeMilestones && opts.markdownOutput) {
    print("## Issues by milestone\n");
    print("There were ${issues.length} issues.\n");

    var clusters = Cluster.byMilestone(issues);
    uninterestingMilestones
        .forEach((uninteresting) => clusters.remove(uninteresting));

    print(clusters.toMarkdown(
        sortType: ClusterReportSort.byCount,
        skipEmpty: true,
        showStatistics: false));
  } else if (opts.markdownOutput) {
    print(opts.dateRange
        ? "## Punted issues punted from " +
            opts.from.toIso8601String() +
            ' to ' +
            opts.to.toIso8601String()
        : "## Punted issues");
  }

  var puntedCount = 0;
  for (var item in issues) {
    // typecast so we have easy auto-completion in Visual Studio Code
    var issue = item as Issue;
    var countMilestoned = 0;
    var countDemilestoned = 0;
    if (issue.timeline == null || issue.timeline.length < 2) continue;
    var milestoneEvents = issue.timeline.milestoneTimeline;

    // We're interested in re-milestoning, which means at least two milestone events.
    if (milestoneEvents.length < 2) continue;

    // Walk each milestone/demilestone event
    var lastNotedMilestoneTitle = milestoneEvents[0].title;
    for (var i = 1; i < milestoneEvents.length; i++) {
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
    if (issue.milestone != null && countMilestoned == 0) countMilestoned++;

    if (countMilestoned >= 1 || countDemilestoned > 0) {
      if (opts.markdownOutput) {
        print(
            'Issue [#${issue.number}](${issue.url}) "${issue.title}" punted ${countMilestoned} times, ' +
                'unassigned a milestone ${countDemilestoned} times, now ' +
                (milestoneEvents.last.type == 'DemilestonedEvent'
                    ? 'not assigned a milestone'
                    : 'assigned to ${issue.milestone}\n'));
      } else if (opts.tsvOutput &&
          milestoneEvents.last.type == 'MilestonedEvent') {
        // Issue number Issue summary State Original milestone Last punt Last milestone');
        final separator = '\t';
        String tsv = '';
        var firstMilestone = milestoneEvents[0];
        var lastMilestone = milestoneEvents.last;

        tsv += '=HYPERLINK("${issue.url}","${issue.number}")';
        tsv += '${separator}${issue.title}';
        tsv += '${separator}${issue.state}';
        tsv += '${separator}${countMilestoned}';
        tsv += '${separator}${firstMilestone.title}';
        tsv += '${separator}${lastMilestone.createdAt}';
        if (milestoneEvents.last.type == 'DemilestonedEvent') {
          tsv += '${separator}(milestone removed; no milestone set)';
        } else {
          tsv += '${separator}${issue.milestone.title}';
        }
        print(tsv);
      }
      for (var timelineItem in milestoneEvents) {
        if (opts.markdownOutput) {
          if (timelineItem.type == 'MilestonedEvent') {
            print('  * assigned the ${timelineItem.title} milestone');
          }
        } else {
          // NO TSV OUTPUT for this case; this space left blank.
        }
      }
      if (opts.markdownOutput) print('\n\n');
    }
  }

  if (opts.markdownOutput) {
    print('\n\n${puntedCount} issues were punted from at least one milestone.');
  }
}
