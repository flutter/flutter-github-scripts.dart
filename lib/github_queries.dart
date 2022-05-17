import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:graphql/client.dart';

enum GitHubIssueType { issue, pullRequest }

enum GitHubIssueState { open, closed, merged }

enum GitHubDateQueryType { created, updated, closed, merged, none }

/// Used to perform queries against GitHub.
class GitHub {
  late HttpLink _httpLink;
  late AuthLink _auth;
  late Link _link;
  late GraphQLClient _client;

  final _maxSearchResponse = 1000;
  final _printQuery = false;

  /// Initialize the interface
  GitHub(String? token) {
    _httpLink = HttpLink(
      'https://api.github.com/graphql',
    );
    _auth = AuthLink(
      getToken: () async => 'Bearer $token',
    );
    _link = _auth.concat(_httpLink);
    _client = GraphQLClient(cache: GraphQLCache(), link: _link);
  }

  /// Fetch a team by its Github id.
  Future<Team> team(String id) async {
    var query = Team.request(id);
    final options = QueryOptions(document: gql(query));
    if (_printQuery) print(query);
    final page = await _client.query(options);
    if (page.hasException) {
      print(query);
      throw (page.exception.toString());
    }
    return Team.fromGraphQL(page.data!['node']);
  }

  /// Fetch an organiation by its login.
  Future<Organization> organization(String login) async {
    var query = Organization.request(login);
    final options = QueryOptions(document: gql(query));
    if (_printQuery) print(query);
    final page = await _client.query(options);
    if (page.hasException) {
      print(query);
      throw (page.exception.toString());
    }
    return Organization.fromGraphQL(page.data!['organization']);
  }

  /// Fetch an organiation by its login.
  Future<Organization> organizationById(String id) async {
    var query = Organization.requestId(id);
    final options = QueryOptions(document: gql(query));
    if (_printQuery) print(query);
    final page = await _client.query(options);
    if (page.hasException) {
      print(query);
      throw (page.exception.toString());
    }
    return Organization.fromGraphQL(page.data!['organization']);
  }

  Future<bool> userInOrganization(Actor user, String orgName) async {
    bool isMember = false;
    await for (var org in user.organizationsStream) {
      if (org.name == orgName) {
        isMember = true;
        break;
      }
    }
    return isMember;
  }

  /// Fetch an organiation by its login.
  Future<Actor?> user(String login) async {
    var query = Actor.request(login);

    final options = QueryOptions(document: gql(query));
    if (_printQuery) print(query);
    final page = await _client.query(options);
    if (page.hasException) {
      if (page.exception
          .toString()
          .contains('Could not resolve to a User with the login')) return null;
      print(query);
      throw (page.exception.toString());
    }
    return Actor.fromGraphQL(page.data!['user']);
  }

  ///
  /// Search by items or pull requests by query.
  /// Responses limited to first 1,000 items found due to Github
  /// `search` API limits.
  /// Returns a string of PullRequest and Issue items.
  Stream<dynamic> searchIssuePRs(String queryString) async* {
    var after = 'null';
    bool? hasNextPage;
    do {
      var query = _searchIssuesOrPRs
          .replaceAll(r'${query}', queryString.replaceAll('"', '\\"'))
          .replaceAll(r'${after}', after)
          .replaceAll(r'${issueResponse}', Issue.graphQLResponse)
          .replaceAll(r'${pageInfoResponse}', PageInfo.graphQLResponse)
          .replaceAll(r'${pullRequestResponse}', PullRequest.graphQLResponse);
      final options = QueryOptions(document: gql(query));
      if (_printQuery) print(query);
      final page = await _client.query(options);
      if (page.hasException) {
        print(query);
        print(page.exception);
        print(page.data);
        throw (page.exception.toString());
      }
      // Paginate information
      try {
        PageInfo pageInfo =
            PageInfo.fromGraphQL(page.data!['search']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }

      var buffer = [];
      var bufferIndex = 0;
      var edges = page.data!['search']['nodes'];
      edges.forEach((edge) {
        dynamic item = edge['__typename'] == 'Issue'
            ? Issue.fromGraphQL(edge)
            : PullRequest.fromGraphQL(edge);
        buffer.add(item);
      });
      if (buffer.isNotEmpty) {
        do {
          yield buffer[bufferIndex++];
        } while (bufferIndex < buffer.length);
      }
    } while (hasNextPage!);
  }

  /// Search for issues and PRs matching criteria across a date range.
  /// Note that search uses the GitHub GraphQL `search` function.
  /// Searching criteria occurs all on the server side.
  /// Because search returns "relevant" results, it's
  /// possible that large queries may not return all elements,
  /// but only a count.
  /// DEPRECATED
  Future<List<dynamic>> deprecatedSearch(
      {String? owner,
      String? name,
      GitHubIssueType type = GitHubIssueType.issue,
      GitHubIssueState state = GitHubIssueState.open,
      List<String>? labels,
      GitHubDateQueryType dateQuery = GitHubDateQueryType.none,
      DateRange? dateRange}) async {
    var typeString = type == GitHubIssueType.issue ? 'issue' : 'pr';
    var stateString = '';
    switch (state) {
      case GitHubIssueState.open:
        stateString = 'open';
        break;
      case GitHubIssueState.closed:
        stateString = 'closed';
        break;
      case GitHubIssueState.merged:
        stateString = 'merged';
        break;
    }

    if (dateQuery != GitHubDateQueryType.none && dateRange == null) {
      throw ('With a dateQuery you must provide a non-null dateRange!');
    }
    var dateString = DateRange.queryToString(dateQuery, dateRange);

    var startSearchFrom = dateRange;
    var endSearchAt = dateRange;

    var labelFilters = [];
    if (labels != null && labels.isNotEmpty) {
      for (var label in labels) {
        labelFilters.add('label:\\"$label\\"');
      }
    } else {
      // We'll do just one query, with no filter
      labelFilters.add('');
    }

    var fetchAnotherDay = false;
    var splitFetches = false;
    dynamic totalIssueCount;
    var result = [];
    var resultsFetched = <int?>{};
    // For each label, do the query.
    for (var labelFilter in labelFilters) {
      do {
        bool? fetchAnotherPage = false;
        var after = 'null';
        do {
          var query = _deprecatedSearchIssuesOrPRs
              .replaceAll(r'${repositoryOwner}', owner!)
              .replaceAll(r'${repositoryName}', name!)
              .replaceAll(r'${after}', after)
              .replaceAll(r'${label}', labelFilter)
              .replaceAll(r'${state}', stateString)
              .replaceAll(r'${issueOrPr}', typeString)
              .replaceAll(r'${dateTime}', dateString)
              .replaceAll(r'${issueResponse}', Issue.graphQLResponse)
              .replaceAll(r'${pageInfoResponse}', PageInfo.graphQLResponse)
              .replaceAll(
                  r'${pullRequestResponse}', PullRequest.graphQLResponse);
          final options = QueryOptions(document: gql(query));
          if (_printQuery) print(query);
          final page = await _client.query(options);
          if (page.hasException) {
            print(query);
            throw (page.exception.toString());
          }
          var edges = page.data!['search']['nodes'];
          edges.forEach((edge) {
            dynamic item = type == GitHubIssueType.issue
                ? Issue.fromGraphQL(edge)
                : PullRequest.fromGraphQL(edge);
            // Ensure we de-dup across page boundaries.
            if (!resultsFetched.contains(item.number)) {
              resultsFetched.add(item.number);
              result.add(item);
            }
          });

          // Pseudo-paginate by date if we're not already, and there's too many responses.
          if (!splitFetches &&
              page.data!['search']['issueCount'] >= _maxSearchResponse) {
            splitFetches = true;
          }

          // GitHub pagination
          totalIssueCount ??= page.data!['search']['issueCount'];
          var pageInfo = PageInfo.fromGraphQL(page.data!['search']['pageInfo']);
          fetchAnotherPage = pageInfo.hasNextPage;
          if (fetchAnotherPage!) after = '"${pageInfo.endCursor}"';
        } while (fetchAnotherPage);

        // pseudo-pagination -- if this response returns its maximum
        // try again with a more constrained date range

        // If we need to split fetches across days, do so.
        if (splitFetches) {
          fetchAnotherDay = true;
          switch (dateRange!.type) {
            case DateRangeType.at:
              throw ('unsupported DateRangeType.at with maximum number of elements');
            case DateRangeType.range:
              final dayDelta = 4;
              var newEnd = startSearchFrom!.end;
              startSearchFrom = DateRange(DateRangeType.range,
                  start: newEnd!.subtract(Duration(days: 2 * dayDelta)),
                  end: newEnd.subtract(Duration(days: dayDelta)));
              var newDateRange = DateRange(DateRangeType.range,
                  start: newEnd
                          .subtract(Duration(days: dayDelta))
                          .isBefore(endSearchAt!.start!)
                      ? endSearchAt.start
                      : newEnd.subtract(Duration(days: dayDelta)),
                  end: newEnd);
              dateRange = newDateRange;
              dateString = DateRange.queryToString(dateQuery, dateRange);
              if (dateRange.end!.isBefore(endSearchAt.start!)) {
                fetchAnotherDay = false;
              }
              break;
          }
        }
      } while (fetchAnotherDay);
    }

    // There's still a chance we missed some. If it looks like that's the case,
    // fail with an exception.
    if (result.length != totalIssueCount) {
      throw ('We expected $totalIssueCount issues or PRs, and only got ${result.length}');
    }

    result.sort((a, b) => a.number.compareTo(b.number));

    return result;
  }

  /// Fetches issues matching criteria.
  /// This method uses the `issues` and `pullRequests` operations
  /// on GitHub's GraphQL interface. Because of this, it has to
  /// pull all open or closed issues or pull requests as it
  /// filters. This is much slower than `search`, which should
  /// be used when the number of returned values is expected to be
  /// low.
  Future<List<dynamic>> fetch({
    String? owner,
    String? name,
    GitHubIssueType? type = GitHubIssueType.issue,
    GitHubIssueState state = GitHubIssueState.open,
    List<String>? labels,
    GitHubDateQueryType dateQuery = GitHubDateQueryType.none,
    DateRange? dateRange,
  }) async {
    var typeString = type == GitHubIssueType.issue ? 'issues' : 'pullRequests';
    var stateString = '';
    switch (state) {
      case GitHubIssueState.open:
        stateString = 'OPEN';
        break;
      case GitHubIssueState.closed:
        stateString = 'CLOSED';
        break;
      case GitHubIssueState.merged:
        stateString = 'MERGED';
        break;
    }

    if (dateQuery != GitHubDateQueryType.none && dateRange == null) {
      throw ('With a dateQuery you must provide a non-null dateRange!');
    }

    var result = [];
    var done = false;
    var after = 'null';
    do {
      var query = _queryIssuesOrPRs
          .replaceAll(r'${repositoryOwner}', owner!)
          .replaceAll(r'${repositoryName}', name!)
          .replaceAll(r'${type}', typeString)
          .replaceAll(r'${after}', after)
          .replaceAll(r'${state}', stateString)
          .replaceAll(r'${pageInfoResponse}', PageInfo.graphQLResponse)
          .replaceAll(
              r'${response}',
              type == GitHubIssueType.issue
                  ? Issue.graphQLResponse
                  : PullRequest.graphQLResponse);
      if (_printQuery) print(query);

      final options = QueryOptions(document: gql(query));
      final page = await _client.query(options);

      if (page.hasException) {
        print(query);
        print(page.source);
        throw (page.exception.toString());
      }

      var edges = page.data!['repository'][typeString]['nodes'];
      edges.forEach((edge) {
        dynamic item = type == GitHubIssueType.issue
            ? Issue.fromGraphQL(edge)
            : PullRequest.fromGraphQL(edge);
        bool add = true;

        if (dateQuery != GitHubDateQueryType.none) {
          switch (dateQuery) {
            case GitHubDateQueryType.created:
              add = (item.createdAt != null &&
                      item.createdAt.isAfter(dateRange!.start) &&
                      item.createdAt.isBefore(dateRange.end))
                  ? true
                  : false;
              break;
            case GitHubDateQueryType.updated:
              add = (item.updatedAt != null &&
                      item.updatedAt.isAfter(dateRange!.start) &&
                      item.updatedAt.isBefore(dateRange.end))
                  ? true
                  : false;
              break;
            case GitHubDateQueryType.closed:
              add = (item.closedAt != null &&
                      item.closedAt.isAfter(dateRange!.start) &&
                      item.closedAt.isBefore(dateRange.end))
                  ? true
                  : false;
              break;
            case GitHubDateQueryType.merged:
              if (item is! PullRequest) {
                add = false;
              } else {
                add = (item.merged &&
                        item.mergedAt != null &&
                        item.closedAt.isAfter(dateRange!.start) &&
                        item.closedAt.isBefore(dateRange.end))
                    ? true
                    : false;
              }
              break;
            case GitHubDateQueryType.none:
              add = true;
              break;
          }
        }

        if (add) {
          result.add(item);
        }
      });
      PageInfo pageInfo = PageInfo.fromGraphQL(
          page.data!['repository'][typeString]['pageInfo']);

      done = done || !pageInfo.hasNextPage!;
      if (!done) after = '"${pageInfo.endCursor}"';
      // if (false) {
      //   var totalCount = page.data['repository'][typeString]['totalCount'];
      //   print('${count} / ${totalCount}');
      // }
    } while (!done);

    // Filter labels
    if (labels != null && labels.isNotEmpty) {
      var filtered = [];
      for (var item in result) {
        for (var label in labels) {
          if (item.labels.containsString(label)) {
            filtered.add(item);
            break;
          }
        }
      }
      result = filtered;
    }

    return result;
  }

  /// Fetch a single issue.
  Future<Issue> issue(
      {required String owner, required String name, int? number}) async {
    var query = _queryIssue
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${number}', number.toString())
        .replaceAll(r'${issueResponse}', Issue.graphQLResponse);
    if (_printQuery) print(query);
    final options = QueryOptions(document: gql(query));
    final page = await _client.query(options);
    if (page.hasException) {
      throw (page.exception.toString());
    }

    return Issue.fromGraphQL(page.data!['repository']['issue']);
  }

  /// Fetch a single PR.
  Future<PullRequest> pullRequest(
      {required String owner, required String name, int? number}) async {
    var query = _queryPullRequest
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${number}', number.toString())
        .replaceAll(r'${pullRequestResponse}', PullRequest.graphQLResponse);
    if (_printQuery) print(query);
    final options = QueryOptions(document: gql(query));
    final page = await _client.query(options);
    if (page.hasException) {
      throw (page.exception.toString());
    }

    return PullRequest.fromGraphQL(page.data!['repository']['pullRequest']);
  }

  final _queryIssuesOrPRs = r'''
  query {
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      ${type}(first: 15, after: ${after}, states: ${state}) {
        totalCount,
        pageInfo ${pageInfoResponse}
        nodes ${response}
      }
    }
  }
  ''';

  final _searchIssuesOrPRs = r'''
  query { 
    search(query:"${query}", type: ISSUE, first:5, after:${after}) {
      issueCount,
      pageInfo ${pageInfoResponse}
      nodes {
        ... on Issue ${issueResponse}
        ... on PullRequest ${pullRequestResponse}
      } 
    }
  }
  ''';

  final _deprecatedSearchIssuesOrPRs = r'''
  query { 
    search(query:"repo:${repositoryOwner}/${repositoryName} ${label} is:${state} is:${issueOrPr} ${dateTime} sort:created", type: ISSUE, first:20, after:${after}) {
      issueCount,
      pageInfo ${pageInfoResponse}
      nodes {
        ... on Issue ${issueResponse}
        ... on PullRequest ${pullRequestResponse}
      } 
    }
  }
  ''';

  final _queryIssue = r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      issue(
        number:${number}) 
        ${issueResponse}
    }
  }
  ''';

  final _queryPullRequest = r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      pullRequest(number:${number}) 
      ${pullRequestResponse}
    }
  }
  ''';
}

enum DateRangeType { at, range }

enum DateRangeWhen { onDate, onOrBefore, onOrAfter }

class DateRange {
  DateRangeType _type;
  DateRangeType get type => _type;

  DateRangeWhen? _when;
  DateRangeWhen? get when => _when;

  DateTime? _at, _start, _end;

  DateTime? get at => _at;
  DateTime? get start => _start;
  DateTime? get end => _end;

  @override
  String toString() {
    if (_type == DateRangeType.at) {
      String comparison = '';
      switch (_when) {
        case DateRangeWhen.onDate:
          comparison = '';
          break;
        case DateRangeWhen.onOrBefore:
          comparison = '<=';
          break;
        case DateRangeWhen.onOrAfter:
          comparison = '>=';
          break;
        case null:
          comparison = '';
          break;
      }
      return comparison + _at!.toIso8601String();
    } else {
      return '${_start!.toIso8601String().replaceAll('.000', '')}..${_end!.toIso8601String().replaceAll('.000', '')}';
    }
  }

  static String queryToString(GitHubDateQueryType dateQuery, DateRange? range) {
    var dateString = '';
    switch (dateQuery) {
      case GitHubDateQueryType.created:
        dateString = 'created:$range';
        break;
      case GitHubDateQueryType.updated:
        dateString = 'updated:$range';
        break;
      case GitHubDateQueryType.closed:
        dateString = 'closed:$range';
        break;
      case GitHubDateQueryType.merged:
        dateString = 'merged:$range';
        break;
      case GitHubDateQueryType.none:
        break;
    }
    return dateString;
  }

  factory DateRange(
    type, {
    DateTime? at,
    DateRangeWhen? when = DateRangeWhen.onDate,
    DateTime? start,
    DateTime? end,
  }) {
    if (type == DateRangeType.at &&
        when != null &&
        at != null &&
        start == null &&
        end == null) {
      return DateRange._internal(type, at, when, null, null);
    } else if (type == DateRangeType.range &&
        at == null &&
        when == DateRangeWhen.onDate &&
        start != null &&
        end != null) {
      return DateRange._internal(type, null, null, start, end);
    } else {
      throw ArgumentError("Illegal arguments");
    }
  }
  DateRange._internal(this._type, this._at, this._when, this._start, this._end);
}
