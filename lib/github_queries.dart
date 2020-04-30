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


  Future<List<Issue>> issues(String repositoryOwner, String repositoryName, {String filterSpec = null}) async {
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
      var query = query_issues
        .replaceAll(r'${repositoryOwner}', repositoryOwner)
        .replaceAll(r'${repositoryName}', repositoryName)
        .replaceAll(r'${after}', after)
        .replaceAll(r'${filter}', filter);

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

      final query_issues = 
      r'''
      query { 
        repository(owner:"${repositoryOwner}", name:"${repositoryName}") {
          issues(first: 100, 
            after: ${after}, 
            ${filter}) {
              totalCount,
              pageInfo {
                startCursor, hasNextPage, endCursor
              },
            edges {
              node {
                title,
                id,
                number,
                state,
                author {
                  login,
                  resourcePath,
                  url
                },
                body,
                labels(first:100) {
                  edges {
                    node {
                      name
                    }
                  }
                },
                url,
                createdAt,
                closedAt,
                lastEditedAt,
                updatedAt,
                repository {
                  nameWithOwner
                },
                timelineItems(last: 100, 
                    itemTypes:[CROSS_REFERENCED_EVENT]) {
                    pageInfo{
                      startCursor,
                      hasNextPage,
                      endCursor
                    },
                    nodes {
                      __typename
                      ... on CrossReferencedEvent {
                        source {
                          __typename
                          ...  on PullRequest {
                            title,
                            number,
                          }
                          ... on Issue {
                            title,
                            number,
                          }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      ''';



}