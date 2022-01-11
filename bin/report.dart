import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:graphql/client.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final ReportCommandRunner runner = ReportCommandRunner();
  exit(await runner.run(args) ?? 0);
}

class ReportCommandRunner<int> extends CommandRunner {
  ReportCommandRunner()
      : super(
          'report',
          'Run various reports on the Flutter related GitHub repositories.',
        ) {
    addCommand(ReleaseCommand());
    addCommand(WeeklyCommand());
  }

  late GraphQLClient _client = _initGraphQLClient();

  Future<QueryResult> query(QueryOptions options) {
    return _client.query(options);
  }

  GraphQLClient _initGraphQLClient() {
    final token = Platform.environment['GITHUB_TOKEN'];
    if (token == null) {
      throw 'This tool expects a github access token in the GITHUB_TOKEN '
          'environment variable.';
    }

    final auth = AuthLink(getToken: () async => 'Bearer $token');
    return GraphQLClient(
      cache: GraphQLCache(),
      link: auth.concat(HttpLink('https://api.github.com/graphql')),
    );
  }
}

class WeeklyCommand extends ReportCommand {
  WeeklyCommand()
      : super(
          'weekly',
          'Run a week-based report on issues opened and closed.',
        );

  Future<int> run() async {
    final DateTime now = DateTime.now();
    final int currentDay = now.weekday;
    final DateTime thisWeek = now.subtract(Duration(days: currentDay - 1));
    final DateTime lastWeek = thisWeek.subtract(Duration(days: 7));
    final DateTime lastReportingDay = lastWeek.add(Duration(days: 6));

    const List<String> repos = [
      'dart-lang/sdk',
      'flutter/flutter',
      'flutter/website',
      'FirebaseExtended/flutterfire',
      'googleads/googleads-mobile-flutter',
    ];

    print(
      'Reporting from ${iso8601String(lastWeek)} '
      'to ${iso8601String(lastReportingDay)}...',
    );

    List<RepoInfo> infos = await Future.wait(repos.map((String repo) async {
      return RepoInfo(
        repo,
        issuesOpened: await queryIssuesOpened(
          repo: repo,
          from: lastWeek,
          to: lastReportingDay,
        ),
        issuesClosed: await queryIssuesClosed(
          repo: repo,
          from: lastWeek,
          to: lastReportingDay,
        ),
      );
    }));

    for (RepoInfo info in infos) {
      print(
        '  ${info.repo}: '
        '${info.issuesOpened} opened, '
        '${info.issuesClosed} closed',
      );
    }

    return 0;
  }

  Future<int> queryIssuesOpened({
    required String repo,
    required DateTime from,
    required DateTime to,
  }) async {
    final queryString = '''{
  search(query: "repo:$repo is:issue created:${iso8601String(from)}..${iso8601String(to)}", type: ISSUE, last: 100) {
  issueCount
    edges {
      node {
        ... on Issue {
          title
          url
          createdAt
          number
          state         
        }
      }
    }
  }
}''';
    final result = await query(QueryOptions(document: gql(queryString)));

    if (result.hasException) {
      throw result.exception!;
    }

    return result.data!['search']['issueCount']!;
  }

  Future<int> queryIssuesClosed({
    required String repo,
    required DateTime from,
    required DateTime to,
  }) async {
    final queryString = '''{
  search(query: "repo:$repo is:issue is:closed closed:${iso8601String(from)}..${iso8601String(to)}", type: ISSUE, last: 100) {
  issueCount
    edges {
      node {
        ... on Issue {
          title
          url
          createdAt
          number
          state         
        }
      }
    }
  }
}''';
    final result = await query(QueryOptions(document: gql(queryString)));

    if (result.hasException) {
      throw result.exception!;
    }

    return result.data!['search']['issueCount']!;
  }
}

class ReleaseCommand extends ReportCommand {
  ReleaseCommand()
      : super(
          'release',
          'Generate changelog files for a stable release.',
        ) {
    argParser.addOption(
      'start',
      help: 'The start date (e.g., 2021-11-01T12:43:03-0700).',
      valueHelp: 'date',
    );
    argParser.addOption(
      'end',
      help: 'The end date (e.g., 2021-12-29T11:29:19-0800).',
      valueHelp: 'date',
    );
    argParser.addOption(
      'out',
      help: 'The output directory.',
      valueHelp: 'dir',
      defaultsTo: 'out',
    );
  }

  Future<int> run() async {
    // validate the args
    if (!argResults!.wasParsed('start')) {
      usageException("The option '--start' is required.");
    }
    if (!argResults!.wasParsed('end')) {
      usageException("The option '--end' is required.");
    }

    final DateTime startDate = DateTime.parse(argResults!['start']);
    final DateTime endDate = DateTime.parse(argResults!['end']);
    final String outDir = argResults!['out'];

    const List<String> repos = [
      'flutter/flutter',
    ];

    print(
      'Reporting from ${startDate.toIso8601String()} '
      'to ${endDate.toIso8601String()}...',
    );
    print('');

    List<GitHubIssue> issues = await queryClosedIssues(
      repo: repos.first,
      from: startDate,
      to: endDate,
    );

    print('There were ${issues.length} closed issues.');

    File outFile = File(path.join(outDir, 'issues_closed.md'));
    outFile.parent.createSync();
    outFile.writeAsStringSync('''
## Issues closed in ${repos.first} from ${iso8601String(startDate)} to ${iso8601String(endDate)}

There were ${issues.length} closed issues.

${issues.map((issue) => issue.markdown()).join('\n')}
''');

    print('Wrote closed issue data to ${outFile.path}.');

    return 0;
  }

  Future<List<GitHubIssue>> queryClosedIssues({
    required String repo,
    required DateTime from,
    required DateTime to,
  }) async {
    // We slice the time range here as the github graphql search implementation
    // doesn't return more than 1000 records.

    List<GitHubIssue> issues = [];

    DateTime start = from;
    DateTime next = from.add(Duration(days: 7));
    if (next.isAfter(to)) {
      next = to;
    }

    while (start.isBefore(to)) {
      List<GitHubIssue> nextIssues =
          await _queryClosedIssues(repo: repo, from: start, to: next);

      issues.addAll(nextIssues);
      start = next;

      next = next.add(Duration(days: 7));
      if (next.isAfter(to)) {
        next = to;
      }
    }

    return issues;
  }

  Future<List<GitHubIssue>> _queryClosedIssues({
    required String repo,
    required DateTime from,
    required DateTime to,
  }) async {
    final queryString = '''{
search(query: "repo:$repo is:issue is:closed closed:${from.toIso8601String()}..${to.toIso8601String()}", type: ISSUE, first: 100, , after: \${after}) {
  issueCount
  pageInfo {
    startCursor
    hasNextPage
    endCursor
  }
  edges {
    node {
      ... on Issue {
        title
        url
        number
        createdAt
        state
        labels(first:100) {
          edges {
            node { name }
          }
        }
      }
    }
  }
}}''';

    print('${iso8601String(from)}:');

    String afterCursor = 'null';
    List<GitHubIssue> issues = [];

    do {
      final result = await query(QueryOptions(
          document: gql(queryString.replaceAll('\${after}', afterCursor))));

      if (result.hasException) {
        throw result.exception!;
      }

      List<GitHubIssue> pageIssues = (result.data!['search']['edges'] as List)
          .cast<Map<String, dynamic>>()
          .map(GitHubIssue.build)
          .toList();
      issues.addAll(pageIssues);

      PageInfo pageInfo =
          PageInfo.fromGraphQL(result.data!['search']['pageInfo']);

      if (pageInfo.hasNextPage!) {
        afterCursor = '"${pageInfo.endCursor}"';
      } else {
        print('  ${issues.length} closed issues.');
        return issues;
      }
    } while (true);
  }
}

class GitHubIssue {
  static Set interestingLabels = {
    'prod: API break',
    'severe: API break',
    'severe: new feature',
    'severe: performance',
  };

  // number, url, title, labels
  static GitHubIssue build(Map<String, dynamic> data) {
    return GitHubIssue(data['node']);
  }

  final Map<String, dynamic> data;

  GitHubIssue(this.data);

  int? get number => data['number'];
  String? get url => data['url'];
  String? get title => data['title'];

  List<String> get labels {
    // {edges: [ {__typename: LabelEdge, node: {__typename: Label, name: r: duplicate}} ]}}
    return (data['labels']['edges'] as List).map((edge) {
      return edge['node']['name'] as String;
    }).toList();
  }

  String markdown() {
    // [5792](https://github.com/flut...) enable only_throw_erro... (team, framework, ...)
    List<String> _labels = labels;

    String str = '[$number]($url) $title (${_labels.join(', ')})';
    if (interestingLabels.intersection(_labels.toSet()).isNotEmpty) {
      str = '**$str**';
    }
    return str;
  }

  String toString() => markdown();
}

abstract class ReportCommand<int> extends Command {
  final String name;
  final String description;

  ReportCommand(this.name, this.description);

  Future<QueryResult> query(QueryOptions options) {
    return (runner as ReportCommandRunner).query(options);
  }
}

String iso8601String(DateTime date) {
  return date.toIso8601String().substring(0, 10);
}

class RepoInfo {
  final String repo;
  final int issuesOpened;
  final int issuesClosed;

  RepoInfo(
    this.repo, {
    required this.issuesOpened,
    required this.issuesClosed,
  });
}
