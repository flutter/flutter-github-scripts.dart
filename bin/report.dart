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
    addCommand(CommitActivityCommand());
  }

  late final GraphQLClient _client = _initGraphQLClient();

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
        ) {
    argParser.addFlag(
      'dart-core',
      negatable: false,
      help: 'Query the Dart Ecosystem core packages.',
    );
    argParser.addFlag(
      'dart-tools',
      negatable: false,
      help: 'Query the Dart Ecosystem tools packages.',
    );
    argParser.addOption(
      'date',
      valueHelp: '2022-01-26',
      help:
          'Specify the date to pull data from (defaults to the last full week).',
    );
    argParser.addFlag(
      'month',
      negatable: false,
      help: 'Return stats based on calendar months (instead of weeks).',
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    final bool byMonth = args['month'];

    late final DateTime firstReportingDay;
    late final DateTime lastReportingDay;

    if (byMonth) {
      if (args.wasParsed('date')) {
        final DateTime day = DateTime.parse(args['date']);
        firstReportingDay = DateTime(day.year, day.month, 1);
      } else {
        final DateTime now = DateTime.now();
        firstReportingDay = DateTime(now.year, now.month - 1, 1);
      }

      lastReportingDay =
          DateTime(firstReportingDay.year, firstReportingDay.month + 1, 1);
    } else {
      // by week
      if (args.wasParsed('date')) {
        final DateTime day = DateTime.parse(args['date']);
        firstReportingDay = day.subtract(Duration(days: day.weekday - 1));
      } else {
        final DateTime now = DateTime.now();
        final int currentDay = now.weekday;
        final DateTime thisWeek = now.subtract(Duration(days: currentDay - 1));
        firstReportingDay = thisWeek.subtract(Duration(days: 7));
      }

      lastReportingDay = firstReportingDay.add(Duration(days: 6));
    }

    List<String> repos = [
      'dart-lang/sdk',
      'flutter/flutter',
      'flutter/website',
      'FirebaseExtended/flutterfire',
      'googleads/googleads-mobile-flutter',
    ];

    if (args['dart-core']) {
      repos = dartCoreRepos;
    } else if (args['dart-tools']) {
      repos = dartToolRepos;
    }

    print(
      'Reporting from ${iso8601String(firstReportingDay)} '
      'to ${iso8601String(lastReportingDay)}...',
    );

    List<RepoInfo> infos = await Future.wait(repos.map((String repo) async {
      return RepoInfo(
        repo,
        issuesOpened: await queryIssuesOpened(
          repo: repo,
          from: firstReportingDay,
          to: lastReportingDay,
        ),
        issuesClosed: await queryIssuesClosed(
          repo: repo,
          from: firstReportingDay,
          to: lastReportingDay,
        ),
      );
    }));

    final padding = 22;

    for (RepoInfo info in infos) {
      print(
        '  ${info.repo.padRight(padding)}: '
        '${info.issuesOpened} opened, '
        '${info.issuesClosed} closed',
      );
    }

    print('  ---');

    print(
      '  ${'all'.padRight(padding)}: '
      '${infos.fold(0, (int count, info) => count + info.issuesOpened)} opened, '
      '${infos.fold(0, (int count, info) => count + info.issuesClosed)} closed',
    );

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

class CommitActivityCommand extends ReportCommand {
  CommitActivityCommand()
      : super(
          'commit-activity',
          'Report on the average weekly commit counts for many Dart repos.',
        ) {
    argParser.addOption(
      'date',
      valueHelp: '2022-01-26',
      help:
          'Specify the date to pull data from (defaults to the last 26 weeks).',
    );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    late DateTime firstReportingDay;

    if (args.wasParsed('date')) {
      firstReportingDay = DateTime.parse(args['date']);
    } else {
      // Report on the last 26 weeks.
      final DateTime now = DateTime.now();
      firstReportingDay = now.subtract(Duration(days: 26 * 7));
      firstReportingDay = DateTime(firstReportingDay.year,
          firstReportingDay.month, firstReportingDay.day);
    }

    List<String> repos = sdkDepsRepos;

    print('Reporting since ${iso8601String(firstReportingDay)}...');

    List<CommitInfo> infos = [];

    await Future.forEach(repos, (String repo) async {
      final commitCount =
          await queryCommitsSince(repo: repo, since: firstReportingDay);
      infos.add(CommitInfo(repo, commitCount));
    });

    print('');
    print('Repo, Weekly average, 26 week commit count');
    for (CommitInfo info in infos) {
      final average = info.commitCount / 26.0;
      print(
        '${info.repo}, '
        '${average.toStringAsFixed(1)}, '
        '${info.commitCount}',
      );
    }

    return 0;
  }

  Future<int> queryCommitsSince({
    required String repo,
    required DateTime since,
  }) async {
    List<String> segments = repo.split('/');
    final queryString = '''{
      repository(owner: "${segments[0]}", name: "${segments[1]}") {
        object(expression: "master") {
          ... on Commit {
            history(since: "${since.toIso8601String()}") {
              totalCount
            }
          }
        }
      }
    }''';

    final result = await query(QueryOptions(document: gql(queryString)));
    if (result.hasException) {
      throw result.exception!;
    }
    var object = result.data!['repository']['object'];
    if (object == null) {
      print('no repo history available for $repo');
      return 0;
    }
    return object['history']['totalCount'];
  }
}

class CommitInfo {
  final String repo;
  final int commitCount;

  CommitInfo(this.repo, this.commitCount);
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

  @override
  Future<int> run() async {
    final args = argResults!;

    // validate the args
    if (!args.wasParsed('start')) {
      usageException("The option '--start' is required.");
    }
    if (!args.wasParsed('end')) {
      usageException("The option '--end' is required.");
    }

    final DateTime startDate = DateTime.parse(args['start']);
    final DateTime endDate = DateTime.parse(args['end']);
    final String outDir = args['out'];

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
    List<String> labelsCopy = labels;

    String str = '[$number]($url) $title (${labelsCopy.join(', ')})';
    if (interestingLabels.intersection(labelsCopy.toSet()).isNotEmpty) {
      str = '**$str**';
    }
    return str;
  }

  @override
  String toString() => markdown();
}

abstract class ReportCommand<int> extends Command {
  @override
  final String name;
  @override
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

final dartCoreRepos = [
  'dart-lang/args',
  'dart-lang/async',
  'dart-lang/build',
  'dart-lang/characters',
  'dart-lang/collection',
  'dart-lang/convert',
  'dart-lang/crypto',
  'dart-lang/fake_async',
  'dart-lang/ffi',
  'dart-lang/fixnum',
  'dart-lang/http',
  'dart-lang/http2',
  'dart-lang/http_parser',
  'dart-lang/intl',
  'dart-lang/intl_translation',
  'dart-lang/logging',
  'dart-lang/matcher',
  'dart-lang/mockito',
  'dart-lang/os_detect',
  'dart-lang/path',
  'dart-lang/js',
  'dart-lang/meta',
  'dart-lang/test',
  'dart-lang/typed_data',
  'grpc/grpc-dart',
];

final dartToolRepos = [
  'dart-lang/bazel_worker',
  'dart-lang/benchmark_harness',
  'dart-lang/boolean_selector',
  'dart-lang/browser_launcher',
  'dart-lang/build',
  'dart-lang/cli_util',
  'dart-lang/clock',
  'dart-lang/code_builder',
  'dart-lang/coverage',
  'dart-lang/csslib',
  'dart-lang/dart_style',
  'dart-lang/dartdoc',
  'dart-lang/ffigen',
  'dart-lang/glob',
  'dart-lang/graphs',
  'dart-lang/html',
  'dart-lang/http_multi_server',
  'dart-lang/http_retry',
  'dart-lang/io',
  'dart-lang/json_rpc_2',
  'dart-lang/linter',
  'dart-lang/lints',
  'dart-lang/markdown',
  'dart-lang/mime',
  'dart-lang/oauth2',
  'dart-lang/package_config',
  'dart-lang/pana',
  'dart-lang/pool',
  'dart-lang/pub_semver',
  'dart-lang/pubspec_parse',
  //'dart-lang/sdk',
  'dart-lang/shelf',
  'dart-lang/shelf_packages_handler',
  'dart-lang/shelf_proxy',
  'dart-lang/shelf_static',
  'dart-lang/shelf_test_handler',
  'dart-lang/shelf_web_socket',
  'dart-lang/source_gen',
  'dart-lang/source_map_stack_trace',
  'dart-lang/source_maps',
  'dart-lang/source_span',
  'dart-lang/sse',
  'dart-lang/stack_trace',
  'dart-lang/stream_channel',
  'dart-lang/stream_transform',
  'dart-lang/string_scanner',
  'dart-lang/term_glyph',
  'dart-lang/test',
  'dart-lang/test_descriptor',
  'dart-lang/test_process',
  'dart-lang/test_reflective_loader',
  'dart-lang/timing',
  'dart-lang/usage',
  'dart-lang/watcher',
  'dart-lang/web_socket_channel',
  'dart-lang/webdev',
  'dart-lang/yaml',
  'dart-lang/yaml_edit',
];

final sdkDepsRepos = [
  'dart-lang/sdk',

  //
  'dart-lang/args',
  'dart-lang/async',
  'dart-lang/bazel_worker',
  'dart-lang/benchmark_harness',
  'dart-lang/boolean_selector',
  'dart-lang/browser_launcher',
  'dart-lang/characters',
  'dart-lang/charcode',
  'dart-lang/cli_util',
  'dart-lang/clock',
  'dart-lang/collection',
  'dart-lang/convert',
  'dart-lang/crypto',
  'dart-lang/csslib',
  'dart-lang/dart_style',
  'dart-lang/dartdoc',
  'dart-lang/ffi',
  'dart-lang/fixnum',
  'dart-lang/glob',
  'dart-lang/html',
  'dart-lang/http_io',
  'dart-lang/http_multi_server',
  'dart-lang/http_parser',
  'dart-lang/http',
  'dart-lang/intl',
  'dart-lang/json_rpc_2',
  'dart-lang/linter',
  'dart-lang/lints',
  'dart-lang/logging',
  'dart-lang/markdown',
  'dart-lang/matcher',
  'dart-lang/mime',
  'dart-lang/mockito',
  'dart-lang/oauth2',
  'dart-lang/package_config',
  'dart-lang/path',
  'dart-lang/pedantic',
  'dart-lang/pool',
  'dart-lang/protobuf',
  'dart-lang/pub_semver',
  'dart-lang/pub',
  'dart-lang/shelf_packages_handler',
  'dart-lang/shelf_proxy',
  'dart-lang/shelf_static',
  'dart-lang/shelf_web_socket',
  'dart-lang/shelf',
  'dart-lang/source_map_stack_trace',
  'dart-lang/source_maps',
  'dart-lang/source_span',
  'dart-lang/sse',
  'dart-lang/stack_trace',
  'dart-lang/stream_channel',
  'dart-lang/string_scanner',
  'dart-lang/sync_http',
  'dart-lang/term_glyph',
  'dart-lang/test_descriptor',
  'dart-lang/test_process',
  'dart-lang/test_reflective_loader',
  'dart-lang/test',
  'dart-lang/typed_data',
  'dart-lang/usage',
  'dart-lang/watcher',
  'dart-lang/web_socket_channel',
  'dart-lang/web-components',
  'dart-lang/webdev',
  'dart-lang/yaml_edit',
  'dart-lang/yaml',
  'google/file.dart',
  'google/platform.dart',
  'google/process.dart',
  'google/vector_math.dart',
  'google/webdriver.dart',
  'google/webkit_inspection_protocol.dart',
];
