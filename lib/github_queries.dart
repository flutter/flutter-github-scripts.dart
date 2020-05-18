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
      case GitHubIssueState.open: stateString = 'open'; break;
      case GitHubIssueState.closed: stateString = 'closed'; break;
      case GitHubIssueState.merged: stateString = 'merged'; break;
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
        labelFilters.add('label:\\\"${label}\\\"');
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

        var edges = page.data['search']['nodes'];
        edges.forEach((edge) {
          dynamic item = type == GitHubIssueType.issue ? 
            Issue.fromGraphQL(edge) : 
            PullRequest.fromGraphQL(edge);
          result.add(item);
        });
  
        _PageInfo pageInfo = _PageInfo.fromGraphQL(page.data['search']['pageInfo']);

        done = !pageInfo.hasNextPage;
        if (!done) after = '"${pageInfo.endCursor}"';

      } while( !done );
    }

    return result;
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
    search(query:"repo:${repositoryOwner}/${repositoryName} ${label} is:${state} is:${issueOrPr} ${dateTime}", type: ISSUE, first:25, after:${after}) {
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
      return _start.toIso8601String().replaceAll('.000','') + '..' + _end.toIso8601String().replaceAll('.000','');
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

enum ClusterType { byLabel, byAuthor, byAssignee }
enum ClusterReportSort { byKey, byCount }

class Cluster {
  ClusterType _type;
  get type => _type;
  SplayTreeMap<String, dynamic> _clusters;
  get clusters => _clusters;

  void remove(String key) {
    if (_clusters.containsKey(key)) _clusters.remove(key);
  }
  
  static final _unlabeledKey = '__no labels__';
  static final _unassignedKey = '__unassigned__';

  static Cluster byLabel(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_unlabeledKey] = List<dynamic>();

    for(var item in issuesOrPullRequests) {
      if( !(item is Issue) && !(item is PullRequest)) {
        throw('invalid type!');
      }
      if (item.labels != null) {
        for (var label in item.labels.labels) {
          var name = label.label;
          if (!result.containsKey(name)) {
            result[name] = List<dynamic>();
          }
          result[name].add(item);
        }
      } else {
        result[_unlabeledKey].add(item);
      }
    }

    return Cluster._internal(ClusterType.byLabel, result);
  }

  static Cluster byAuthor(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();

    for(var item in issuesOrPullRequests) {
      if( !(item is Issue) && !(item is PullRequest)) {
        throw('invalid type!');
      }
      var name = item.author.login;
      if (!result.containsKey(name)) {
        result[name] = List<dynamic>();
      }
      result[name].add(item);
    }

    return Cluster._internal(ClusterType.byAuthor, result);
  }

  static Cluster byAssignees(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();

    for(var item in issuesOrPullRequests) {
      if( !(item is Issue) && !(item is PullRequest)) {
        throw('invalid type!');
      }
      if (item.assignees == null || item.assignees.length == 0) {
        if (!result.containsKey(_unassignedKey)) {
          result[_unassignedKey] = List<dynamic>();
        }
        result[_unassignedKey].add(item);
      } else for(var assignee in item.assignees) {
        var name = assignee.login;
        if (!result.containsKey(name)) {
          result[name] = List<dynamic>();
        }
        result[name].add(item);
      }
    }

    return Cluster._internal(ClusterType.byAssignee, result);

  }

  String summary() {
    return 'Cluster of ' + 
      (type == ClusterType.byAuthor ? 'authors' : 'labels') + 
      ' has ${this.clusters.keys.length} clusters';
  }

  String toString() => summary();

  String toMarkdown(ClusterReportSort sortType, bool skipEmpty) {
    var result = '';

    if (clusters.keys.length == 0) {
      result = 'no items\n\n';
    }
    else {
      print(clusters.keys);
      print(clusters.keys.first);
      print(clusters[clusters.keys.first]);
      var kind = (clusters[clusters.keys.first].first is Issue ? 'issue(s)' : 'pull request(s)');
      // Sort labels in descending order
      List<String> keys = clusters.keys.toList();
      keys.sort((a,b) => sortType == ClusterReportSort.byCount ? 
        clusters[b].length - clusters[a].length : 
        a.compareTo(b));
      // Remove the unlabled item if it's empty
      if (clusters[_unlabeledKey] != null && clusters[_unlabeledKey].length == 0) keys.remove(_unlabeledKey);
      if (clusters[_unassignedKey] != null && clusters[_unassignedKey].length == 0) keys.remove(_unassignedKey);
      if (skipEmpty) {
        if (keys.contains(_unlabeledKey)) keys.remove(_unlabeledKey);
        if (keys.contains(_unassignedKey)) keys.remove(_unassignedKey);
      }
      // Dump all clusters
      for (var clusterKey in keys) {
        result = '${result}\n\n### ${clusterKey} - ${clusters[clusterKey].length} ${kind}';
        for(var item in clusters[clusterKey]) {
          result = '${result}\n\n' + item.summary(linebreakAfter: true, boldInteresting: false);
        }
      }
    }
    return '${result}\n\n';
  }

  Cluster._internal(this._type, this._clusters);
}
