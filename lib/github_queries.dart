import 'dart:collection';
import 'dart:io';
import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:quiver/core.dart' show hash2;
// Filter by label: 'labels: ["⚠ TODAY"]'


enum GitHubIssueType { issue, pullRequest }
enum GitHubIssueState { open, closed, merged }

enum GitHubDateQueryType { created, updated, closed, merged, none }



class GitHub {
  HttpLink _httpLink; 
  AuthLink _auth; 
  Link _link;
  GraphQLClient _client; 

  GitHub(String token) {
    _httpLink = HttpLink( uri: 'https://api.github.com/graphql', );
    _auth = AuthLink(getToken: () async => 'Bearer ${token}', );
    _link = _auth.concat(_httpLink);
    _client = GraphQLClient(cache: InMemoryCache(), link: _link);
  }


Future<List<dynamic>> fetch( {String owner, String name,
  GitHubIssueType type = GitHubIssueType.issue,
  GitHubIssueState state = GitHubIssueState.open,
  List<String> labels = null,
  GitHubDateQueryType dateQuery = GitHubDateQueryType.none,
  DateRange dateRange = null
  }) async {
    var typeString = type == GitHubIssueType.issue ? 'issue' : 'pr';
    var stateString = '';
    switch(state) {
      case GitHubIssueState.open: stateString = 'is:open'; break;
      case GitHubIssueState.closed: stateString = 'is:closed'; break;
      case GitHubIssueState.merged: stateString = 'is:merged'; break;
    }
    
    if (dateQuery!=GitHubDateQueryType.none && dateRange == null) {
      throw('With a dateQuery you must provide a non-null dateRange!');
    }

    var dateString = '';
    switch(dateQuery) {
      case GitHubDateQueryType.created: dateString = 'created:' + dateRange.toString(); break;
      case GitHubDateQueryType.updated: dateString = 'updated:' + dateRange.toString(); break;
      case GitHubDateQueryType.closed: dateString = 'closed:' + dateRange.toString(); break;
      case GitHubDateQueryType.merged: dateString = 'merged:' + dateRange.toString(); break;
      case GitHubDateQueryType.none: break;
    }

    var labelFilters = [];
    if (labels != null && !labels.isEmpty) {
      for(var label in labels) {
        labelFilters.add('label:\"${label}\"');
      }
    } else {
      // We'll do just one query, with no filter
      labelFilters.add('');
    }

   var result = List<dynamic>();
    // For each label, do the query.
    for(var labelFilter in labelFilters) {
      var done = false;
      var after = 'null';
      do {
        var query = _queryIssuesOrPRs
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

        var edges = page.data['repository']['issues']['edges'];
        edges.forEach((edge) {
          dynamic item = type == GitHubIssueType.issue ? 
            Issue.fromGraphQL(edge['node']) : 
            PullRequest.fromGraphQL(edge['node']);
          result.add(issue);
        });
  
        _PageInfo pageInfo = _PageInfo.fromGraphQL(page.data['repository']['issues']['pageInfo']);

        done = !pageInfo.hasNextPage;
        if (!done) after = '"${pageInfo.endCursor}"';

      } while( !done );
    }
  }



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

  Future<List<Issue>> issues({String owner, String name, String filterSpec = null}) async {
    var filter = filterSpec == null ? '' : 
    '''
    filterBy: {
              ${filterSpec}
            }
    ''';
   
    var result = List<Issue>();
    var done = false;
    var after = 'null';
    do {
      var query = _query_issues
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${after}', after)
        .replaceAll(r'${filter}', filter)
        .replaceAll(r'${issueResponse}', Issue.jqueryResponse)
        .replaceAll(r'${pageInfoResponse}', _PageInfo.jqueryResponse);

      final options = QueryOptions(document: query);

      final page = await _client.query(options);

      if (page.hasErrors) {
        throw(page.errors.toString());
      }

      var edges = page.data['repository']['issues']['edges'];
      edges.forEach((edge) {
        var issue = Issue.fromGraphQL(edge['node']);
        result.add(issue);
      });
 
      _PageInfo pageInfo = _PageInfo.fromGraphQL(page.data['repository']['issues']['pageInfo']);

      done = !pageInfo.hasNextPage;
      if (!done) after = '"${pageInfo.endCursor}"';

    } while( !done );

    return result;
  }
  

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

// TODO: Generalize this and the next method into one method
Future<List<PullRequest>> pullRequests({String owner, String name, List<String> states = null}) async {
    var stateList = states == null ? '' : 
    '''
    states: ${states}
    ''';
   
    var result = List<PullRequest>();
    var done = false;
    var after = 'null';
    do {
      var query = _query_pullRequests
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${after}', after)
        .replaceAll(r'${states}', stateList)
        .replaceAll(r'${pullRequestResponse}', PullRequest.jqueryResponse)
        .replaceAll(r'${pageInfoResponse}', _PageInfo.jqueryResponse);

      final options = QueryOptions(document: query);

      final page = await _client.query(options);
      if (page.hasErrors) {
        throw(page.errors.toString());
      }

      var edges = page.data['repository']['pullRequests']['edges'];
      edges.forEach((edge) {
        var pullRequest = PullRequest.fromGraphQL(edge['node']);
        result.add(pullRequest);
      });
 
      _PageInfo pageInfo = _PageInfo.fromGraphQL(page.data['repository']['pullRequests']['pageInfo']);

      done = !pageInfo.hasNextPage;
      if (!done) after = '"${pageInfo.endCursor}"';
    } while( !done );

    return result;
  }

  final _queryIssuesOrPRs = 
  r'''
  query { 
    search(query:"repo:${repositoryOwner}/${repositoryName} ${label} is:${state} is:${issueOrPr} ${dateTime}", type: ISSUE, first:25) {
      issueCount,
      pageinfo ${pageInfoResponse}
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

  final _query_issues = 
  r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      issues(first: 25, 
        after: ${after}, 
        ${filter})
      {
        totalCount,
        pageInfo ${pageInfoResponse}
        edges {
          node ${issueResponse}
        }
      }
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

  final _query_pullRequests = 
  r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      pullRequests(first: 25, 
        after: ${after}, 
        ${states})
      {
        totalCount,
        pageInfo ${pageInfoResponse}
        edges {
          node ${pullRequestResponse}
        }
      }
    }
  }
  ''';

}

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
      return _start.toIso8601String() + '..' + _end.toIso8601String();
    }
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

/*
Generic query
query { 
  search(query:"repo:${repositoryOwner}/${repositoryName} label:\"a: accessibility\" is:issue is:${state} is:${issueOrPr} closed:2019-11-25T18:05..2020-04-02T18:26", type: ISSUE, first:25) {
    issueCount,
    pageinfo ${pageInfoResponse}
    nodes {
      ... on Issue ${issueResponse}
      ... on PullRequest ${pullRequestResponse}
    } 
	}
}

Need to insert:
issueOrPr - "is: issue" | "is:pr"
for single label:
- Insert "label: \"${label}\"" into string.
for multiple labels:
- do each search sequentially, union results.
state is one of "OPEN", "CLOSED", or "MERGED"
labels: ${labels} - label:\"a: accessibility\"
datetimerange: ${dateTime} --- closed:2019-11-25T18:05..2020-04-02T18:26
Dates: can be one or a range
created
updated
closed
merged




 */