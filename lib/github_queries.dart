import 'dart:collection';
import 'dart:io';
import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
// Filter by label: 'labels: ["⚠ TODAY"]'


class Github {


  HttpLink _httpLink; 
  AuthLink _auth; 
  Link _link;
  GraphQLClient _client; 

  Github(String token) {
    _httpLink = HttpLink( uri: 'https://api.github.com/graphql', );
    _auth = AuthLink(getToken: () async => 'Bearer ${token}', );
    _link = _auth.concat(_httpLink);
    _client = GraphQLClient(cache: InMemoryCache(), link: _link);
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
   
    List<Issue> result = List<Issue>();
    bool done = false;
    String after = 'null';
    do {
      var query = _query_issues
        .replaceAll(r'${repositoryOwner}', owner)
        .replaceAll(r'${repositoryName}', name)
        .replaceAll(r'${after}', after)
        .replaceAll(r'${filter}', filter)
        .replaceAll(r'${issueResponse}', Issue.jqueryResponse);

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
 
      done = !page.data['repository']['issues']['pageInfo']['hasNextPage'];
      if (!done) after = '"${page.data['repository']['issues']['pageInfo']['endCursor']}"';

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

  
  final _query_pullRequest = 
  r'''
  query { 
    repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
      pullRequest(number:${number}) 
      ${pullRequestResponse}
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
        pageInfo {
          startCursor, hasNextPage, endCursor
        },
        edges {
          node ${issueResponse}
        }
      }
    }
  }
  ''';



}