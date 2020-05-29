import 'dart:io';
import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:path/path.dart';
import 'package:quiver/core.dart' show hash2;
// Filter by label: 'labels: ["⚠ TODAY"]'


enum GitHubIssueType { issue, pullRequest }
enum GitHubIssueState { open, closed, merged }
enum GitHubDateQueryType { created, updated, closed, merged, none }

/// Used to perform queries against GitHub.
class GitHub {
  HttpLink _httpLink; 
  AuthLink _auth; 
  Link _link;
  GraphQLClient _client; 

  int _maxSearchResponse = 1000;

  /// Initialize the interface
  GitHub(String token) {
    _httpLink = HttpLink( uri: 'https://api.github.com/graphql', );
    _auth = AuthLink(getToken: () async => 'Bearer ${token}', );
    _link = _auth.concat(_httpLink);
    _client = GraphQLClient(cache: InMemoryCache(), link: _link);
  }

/// Search for issues and PRs matching criteria
/// Note that search uses the GitHub GraphQL `search` function. 
/// Searching criteria occurs all on the server side.
Future<List<dynamic>> search( {String owner, String name,
  GitHubIssueType type = GitHubIssueType.issue,
  GitHubIssueState state = GitHubIssueState.open,
  List<String> labels = null,
  GitHubDateQueryType dateQuery = GitHubDateQueryType.created,
  DateRange dateRange = null
  }) async {
    var typeString = type == GitHubIssueType.issue ? 'issue' : 'pr';
    var stateString = '';
    switch(state) {
      case GitHubIssueState.open: stateString = 'open'; break;
      case GitHubIssueState.closed: stateString = 'closed'; break;
      case GitHubIssueState.merged: stateString = 'merged'; break;
    }
    
    if (dateQuery!=GitHubDateQueryType.none && dateRange == null) {
      throw('With a dateQuery you must provide a non-null dateRange!');
    }
    var dateString = DateRange.queryToString(dateQuery, dateRange);

    var startSearchFrom = dateRange;
    var endSearchAt = dateRange;

    var labelFilters = [];
    if (labels != null && !labels.isEmpty) {
      for(var label in labels) {
        labelFilters.add('label:\\\"${label}\\\"');
      }
    } else {
      // We'll do just one query, with no filter
      labelFilters.add('');
    }

    var fetchAnotherDay = false;
    var splitFetches = false;
    var result = List<dynamic>();
    var resultsFetched = Set<int>();
    // For each label, do the query.
    for(var labelFilter in labelFilters) {
      do {
        var fetchAnotherPage = false;
        var after = 'null';
        do {
          var query = _searchIssuesOrPRs
            .replaceAll(r'${repositoryOwner}', owner)
            .replaceAll(r'${repositoryName}', name)
            .replaceAll(r'${after}', after)
            .replaceAll(r'${label}', labelFilter)
            .replaceAll(r'${state}', stateString)
            .replaceAll(r'${issueOrPr}', typeString)
            .replaceAll(r'${dateTime}', dateString)          
            .replaceAll(r'${issueResponse}', Issue.jqueryResponse)
            .replaceAll(r'${pageInfoResponse}', _PageInfo.jqueryResponse)
            .replaceAll(r'${pullRequestResponse}',PullRequest.jqueryResponse);
          final options = QueryOptions(document: query);

          final page = await _client.query(options);
          if (page.hasErrors) {
            throw(page.errors.toString());
          }
          var edges = page.data['search']['nodes'];
          edges.forEach((edge) {
            dynamic item = type == GitHubIssueType.issue ? 
              Issue.fromGraphQL(edge) : 
              PullRequest.fromGraphQL(edge);
            // Ensure we de-dup across page boundaries.
            if (!resultsFetched.contains(item.number)) { 
              resultsFetched.add(item.number);
              result.add(item);
            }
          });

          // Pseudo-paginate by date if we're not already, and there's too many responses.
          if (!splitFetches && page.data['search']['issueCount'] >= _maxSearchResponse) {
            splitFetches = true;
          }

          // GitHub pagination
          var pageInfo = _PageInfo.fromGraphQL(page.data['search']['pageInfo']);
          fetchAnotherPage = pageInfo.hasNextPage;
          if (fetchAnotherPage) after = '"${pageInfo.endCursor}"';

        } while(fetchAnotherPage);
        
        // pseudo-pagination -- if this response returns its maximum
        // try again with a more constrained date range

        // If we get the maxmimum number of results and we're already splitting
        // we're missing something.


        // If we're 
        if (splitFetches) {
          fetchAnotherDay = true;
          switch(dateRange.type) {
            case DateRangeType.at:
              throw('unsupported DateRangeType.at with maximum number of elements');
              break;
            case DateRangeType.range:
              var newEnd = startSearchFrom.end;
              startSearchFrom = DateRange(DateRangeType.range,start: newEnd.subtract(Duration(days:4)), end: newEnd.subtract(Duration(days:2)));
              var newDateRange = DateRange(DateRangeType.range, start: newEnd.subtract(Duration(days:2)).isBefore(endSearchAt.start) ? endSearchAt.start : newEnd.subtract(Duration(days:2)), end: newEnd);
              dateRange = newDateRange;
              dateString = DateRange.queryToString(dateQuery, dateRange);
              if (dateRange.end.isBefore(endSearchAt.start)) fetchAnotherDay = false;
            break;
          }
        }
        print('${splitFetches} ${fetchAnotherDay} ${dateRange}');
      } while(fetchAnotherDay);
    }

    print(result.length);

    result.sort((a,b) => a.number.compareTo(b.number));
    exit(-1);
    return result;
  }

/// Fetches issues matching criteria.
/// This method uses the `issues` and `pullRequests` operations
/// on GitHub's GraphQL interface. Because of this, it has to
/// pull all open or closed issues or pull requests as it
/// filters. This is much slower than `search`, which should
/// be used when the number of returned values is expected to be
/// low.
Future<List<dynamic>> fetch( {String owner, String name,
  GitHubIssueType type = GitHubIssueType.issue,
  GitHubIssueState state = GitHubIssueState.open,
  List<String> labels = null,
  GitHubDateQueryType dateQuery = GitHubDateQueryType.none,
  DateRange dateRange = null
  }) async {
    var typeString = type == GitHubIssueType.issue ? 'issues' : 'pullRequests';
    var stateString = '';
    switch(state) {
      case GitHubIssueState.open: stateString = 'OPEN'; break;
      case GitHubIssueState.closed: stateString = 'CLOSED'; break;
      case GitHubIssueState.merged: stateString = 'MERGED'; break;
    }
    
    if (dateQuery!=GitHubDateQueryType.none && dateRange == null) {
      throw('With a dateQuery you must provide a non-null dateRange!');
    }

    var result = List<dynamic>();
    var done = false;
    var after = 'null';
    do {
      var query = _queryIssuesOrPRs
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${type}', typeString)
        .replaceAll(r'${after}', after)
        .replaceAll(r'${state}', stateString)
        .replaceAll(r'${pageInfoResponse}', _PageInfo.jqueryResponse)
        .replaceAll(r'${response}', type == GitHubIssueType.issue ? Issue.jqueryResponse : PullRequest.jqueryResponse);

      final options = QueryOptions(document: query);
      final page = await _client.query(options);

      if (page.hasErrors) {
        throw(page.errors.toString());
      }

      var edges = page.data['repository'][typeString]['nodes'];
      edges.forEach((edge) {
        dynamic item = type == GitHubIssueType.issue ? 
          Issue.fromGraphQL(edge) : 
          PullRequest.fromGraphQL(edge);
        bool add = true;
        if (dateQuery!=GitHubDateQueryType.none) {
          switch(dateQuery) {
            case GitHubDateQueryType.created: 
              add = item.createdAt.isAfter(dateRange.start) && item.createdAt.isBefore(dateRange.end) ?  true : false;
              break;
            case GitHubDateQueryType.updated: 
              add = item.updatedAt.isAfter(dateRange.start) && item.updatedAt.isBefore(dateRange.end) ?  true : false;
              break;
            case GitHubDateQueryType.closed: 
              add = item.closedAt.isAfter(dateRange.start) && item.closedAt.isBefore(dateRange.end) ?  true : false;
              break;
            case GitHubDateQueryType.merged: 
              add = item.mergedAt.isAfter(dateRange.start) && item.mergedAt.isBefore(dateRange.end) ?  true : false;
              break;
            case GitHubDateQueryType.none: add = true; break;
          }
        } 

        if (add) {
          result.add(item);
        }
      });
      _PageInfo pageInfo = _PageInfo.fromGraphQL(page.data['repository'][typeString]['pageInfo']);

      done = done || !pageInfo.hasNextPage;
      if (!done) after = '"${pageInfo.endCursor}"';
    } while( !done );

    // Filter labels
    if (labels != null && labels.length > 0) {
      var filtered = List<dynamic>();
      for(var item in result) {
        for(var label in labels) {
          if(item.labels.containsString(label)) {
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
  Future<Issue> issue({String owner, String name, int number}) async {
    var query = _query_issue
      .replaceAll(r'${repositoryOwner}', owner)
      .replaceAll(r'${repositoryName}', name)
      .replaceAll(r'${number}', number.toString())
      .replaceAll(r'${issueResponse}', Issue.jqueryResponse);

      final options = QueryOptions(document: query);
      final page = await _client.query(options);
      if (page.hasErrors) {
        throw(page.errors.toString());
      }

      return Issue.fromGraphQL(page.data['repository']['issue']);
  }
  
  /// Fetch a single PR.
  Future<PullRequest> pullRequest({String owner, String name, int number}) async {
    var query = _query_pullRequest
      .replaceAll(r'${repositoryOwner}', owner)
      .replaceAll(r'${repositoryName}', name)
      .replaceAll(r'${number}', number.toString())
      .replaceAll(r'${pullRequestResponse}', PullRequest.jqueryResponse);

      final options = QueryOptions(document: query);
      final page = await _client.query(options);
      if (page.hasErrors) {
        throw(page.errors.toString());
      }

      return PullRequest.fromGraphQL(page.data['repository']['pullRequest']);
  }

  final _queryIssuesOrPRs = 
  r'''
  query {
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      ${type}(first: 25, after: ${after}, states: ${state}) {
        totalCount,
        pageInfo ${pageInfoResponse}
        nodes ${response}
      }
    }
  }
  ''';

  final _searchIssuesOrPRs = 
  r'''
  query { 
    search(query:"repo:${repositoryOwner}/${repositoryName} ${label} is:${state} is:${issueOrPr} ${dateTime} sort:created", type: ISSUE, first:25, after:${after}) {
      issueCount,
      pageInfo ${pageInfoResponse}
      nodes {
        ... on Issue ${issueResponse}
        ... on PullRequest ${pullRequestResponse}
      } 
    }
  }
  ''';

  final _query_issue = 
  r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      issue(
        number:${number}) 
        ${issueResponse}
    }
  }
  ''';

  final _query_pullRequest = 
  r'''
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
  get type => _type;
  DateRangeWhen _when;
  get when => _when;
  DateTime _at, _start, _end;
  get at => _at;
  get start => _start;
  get end => _end; 
  
  String toString() {
    if(_type == DateRangeType.at) {
      String comparison = '';
      switch(_when) {
        case DateRangeWhen.onDate: comparison = ''; break;
        case DateRangeWhen.onOrBefore: comparison = '<='; break;
        case DateRangeWhen.onOrAfter: comparison = '>='; break;
      }
      return comparison + _at.toIso8601String();
    } else {
      return _start.toIso8601String().replaceAll('.000','') + '..' + _end.toIso8601String().replaceAll('.000','');
    }
  }

  static String queryToString(GitHubDateQueryType dateQuery, DateRange range) {
    var dateString = '';
    switch(dateQuery) {
      case GitHubDateQueryType.created: dateString = 'created:' + range.toString(); break;
      case GitHubDateQueryType.updated: dateString = 'updated:' + range.toString(); break;
      case GitHubDateQueryType.closed: dateString = 'closed:' + range.toString(); break;
      case GitHubDateQueryType.merged: dateString = 'merged:' + range.toString(); break;
      case GitHubDateQueryType.none: break;
    }
    return dateString;
  }

  factory DateRange(type, {DateTime at, DateRangeWhen when = DateRangeWhen.onDate, DateTime start, DateTime end}) {
    if (type == DateRangeType.at && when != null && at != null && start == null && end == null) {
      return DateRange._internal(type, at, when, null, null);
    }
    else if (type == DateRangeType.range && at == null && when == DateRangeWhen.onDate && start != null && end != null) {
      return DateRange._internal(type, null, null, start, end);
    }
    else {
      throw("Illegal arguments");
    } 
  }
  DateRange._internal(this._type, this._at, this._when, this._start, this._end);
}


/// Represents a page of information from GitHub.
class _PageInfo {
  String _startCursor;
  get startCursor => _startCursor;
  bool _hasNextPage;
  get hasNextPage => _hasNextPage;
  String _endCursor;
  get endCursor => _endCursor;
  _PageInfo(this._startCursor, this._endCursor, this._hasNextPage);
  static _PageInfo fromGraphQL(dynamic node) {
    return _PageInfo(node['startCursor'], node['endCursor'], node['hasNextPage']);
  }

  String toString() {
    return 'start: ${startCursor}, end: ${endCursor}, more? ${hasNextPage}';
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is _PageInfo &&
    runtimeType == other.runtimeType &&
    _startCursor == other._startCursor &&
    _endCursor == other._endCursor &&
    _hasNextPage == other._hasNextPage;

  @override 
  int get hashCode =>  hash2(
      hash2(_startCursor.hashCode, _endCursor.hashCode),
        _hasNextPage.hashCode);


  static final jqueryResponse = 
  r'''
  {
    startCursor, hasNextPage, endCursor
  },
  ''';
}


