import 'package:graphql/client.dart';
import 'package:args/args.dart';
import 'dart:io';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  /*late*/ ArgResults _results;
  DateTime get from => DateTime.parse(_results['from']);
  DateTime get to => DateTime.parse(_results['to']);
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addOption('from',
          defaultsTo: '2019-11-01',
          abbr: 'f',
          help: 'from date, ISO format yyyy-mm-dd')
      ..addOption('to',
          defaultsTo: DateTime.now().toIso8601String(),
          abbr: 't',
          help: 'to date, ISO format yyyy-mm-dd');
    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run prs_landed_by_week.dart [-f date] [-t date]');
    print(_parser.usage);
  }
}

String makeQuery(DateTime from, DateTime to) {
  final fromIso = from.toIso8601String().substring(0, 10);
  final toIso = to.toIso8601String().substring(0, 10);

  return """
query { 
  search(query:"org:flutter is:pr is:closed merged:${fromIso}..${toIso}", type: ISSUE, last:100) {
    issueCount,
    nodes {
      ... on PullRequest {
        author {
          login
        }
      }
    } 
	}
}
  """;
}

int extractUniqueUsers(dynamic response) {
  var committers = Set<String>();
  for (var pr in response['search']['nodes']) {
    committers.add(pr['author']['login']);
  }
  return committers.length;
}

int extractPullRequestCountResponse(dynamic response) {
  return response['search']['issueCount'];
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  final token = Platform.environment['GITHUB_TOKEN'];
  final httpLink = HttpLink('https://api.github.com/graphql');
  final auth = AuthLink(getToken: () async => 'Bearer $token');
  final link = auth.concat(httpLink);
  final client = GraphQLClient(cache: GraphQLCache(), link: link);

  var start = opts.from;
  do {
    final until = start.add(Duration(hours: 24 * 7));
    final q = makeQuery(start, until);
    final options = QueryOptions(document: gql(q));
    final result = await client.query(options);
    final timeStampTo = until.toIso8601String().substring(0, 10);

    if (result.hasException) {
      print(result.exception.toString());
      exit(-1);
    }
    print(timeStampTo +
        ',' +
        extractPullRequestCountResponse(result.data).toString() +
        ',' +
        extractUniqueUsers(result.data).toString());
    start = until;
  } while (start.compareTo(opts.to) < 0);
}
