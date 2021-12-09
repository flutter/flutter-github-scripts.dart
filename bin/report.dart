import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:graphql/client.dart';

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
      'to ${iso8601String(lastReportingDay)}:',
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
