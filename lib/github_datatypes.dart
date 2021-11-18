import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:graphql/client.dart';
import 'package:quiver/core.dart' show hash2;

final token = Platform.environment['GITHUB_TOKEN'];
final _httpLink = HttpLink(
  'https://api.github.com/graphql',
);
final _auth = AuthLink(
  getToken: () async => 'Bearer ${token}',
);
final _link = _auth.concat(_httpLink);
final _client = GraphQLClient(cache: GraphQLCache(), link: _link);

// TODO:
// - Migrate json definitions into smaller object classes, the way
//   Milestone is now, to decouple the object defintion from the
//   Item and PullRequest classes.
// - Generalize clustering. There's a lot of repeated code that
//   could be cleaned up with a lambda as a clustering function.

/// Represents a page of information from GitHub.
class PageInfo {
  String _startCursor;
  get startCursor => _startCursor;
  bool _hasNextPage;
  get hasNextPage => _hasNextPage;
  String _endCursor;
  get endCursor => _endCursor;
  PageInfo(this._startCursor, this._endCursor, this._hasNextPage);
  static PageInfo fromGraphQL(dynamic node) {
    return PageInfo(
        node['startCursor'], node['endCursor'], node['hasNextPage']);
  }

  String toString() {
    return 'startCursor: ${startCursor}, endCursor: ${endCursor}, hasNextPage: ${hasNextPage}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageInfo &&
          runtimeType == other.runtimeType &&
          _startCursor == other._startCursor &&
          _endCursor == other._endCursor &&
          _hasNextPage == other._hasNextPage;

  @override
  int get hashCode => hash2(
      hash2(_startCursor.hashCode, _endCursor.hashCode), _hasNextPage.hashCode);

  static final graphQLResponse = '''
  {
    startCursor, hasNextPage, endCursor
  }
  ''';
}

class Reaction {
  static final kinds = [
    "CONFUSED",
    "EYES",
    "HEART",
    "HOORAY",
    "LAUGH",
    "ROCKET",
    "THUMBS_DOWN",
    "THUMBS_UP"
  ];

  String _content;
  get content => _content;
  bool get positive =>
      _content == "HEART" || _content == "HOORAY" || _content == "THUMBS_UP";
  bool get negative => _content == "CONFUSED" || _content == "THUMBS_DOWN";
  bool get neutral =>
      _content == "EYES" || _content == "LAUGH" || _content == "ROCKET";

  Reaction(this._content);
  static Reaction fromGraphQL(dynamic node) {
    return Reaction(node['content']);
  }

  String toString() {
    return _content;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reaction &&
          runtimeType == other.runtimeType &&
          _content == other._content;

  @override
  int get hashCode => _content.hashCode;

  static var graphQLResponse = '''
  {
    content
  }
  ''';
}

class Comment {
  Actor _author;
  get author => _author;
  DateTime _createdAt;
  get createdAt => _createdAt;
  String _body;
  get body => _body;
  String _id;
  get id => _id;
  get reactionStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = _reactionQuery
          .replaceAll(r'${id}', this._id)
          .replaceAll(r'${after}', after);
      final options = QueryOptions(document: gql(query));

      final page = await _client.query(options);
      if (page.data == [] || page.data == null) {
        print(page.exception);
        print(page.data);
        exit(-1);
      }
      try {
        PageInfo pageInfo =
            PageInfo.fromGraphQL(page.data['node']['reactions']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var bufferReactions = <Reaction>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['node']['reactions']['nodes']) {
        bufferReactions.add(Reaction.fromGraphQL(jsonSub));
      }

      // Yield each item in our buffer
      if (bufferReactions.length > 0)
        do {
          yield bufferReactions[bufferIndex++];
        } while (bufferIndex < bufferReactions.length);
    } while (hasNextPage);
  }

  Comment(this._author, this._id, this._createdAt, this._body);
  static Comment fromGraphQL(dynamic node) {
    return Comment(
        Actor.fromGraphQL(node['author']),
        node['id'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['body']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && _id == other._id;

  @override
  int get hashCode => _id.hashCode;

  String _reactionQuery = r'''
    query { 
      node(id: "${id}") {
      ... on IssueComment {
            reactions(first: 100, after: ${after}) {
              totalCount,
              pageInfo {
                endCursor,
                hasNextPage,
              }
              nodes {
                content
              },
            },
          },
        ... on CommitComment {
          reactions(first: 100, after:${after}) {
            totalCount,
            pageInfo {
              endCursor,
              hasNextPage,
            }
            nodes {
              content
            },
          },
        },
    }
  }
''';
}

class Label {
  String _label;
  get label => _label;
  Label(this._label);
  static Label fromGraphQL(dynamic node) {
    return Label(node['name']);
  }

  String toString() {
    return _label;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label &&
          runtimeType == other.runtimeType &&
          _label == other._label;

  @override
  int get hashCode => _label.hashCode;

  static var graphQLResponse = '''
  {
    name
  }
  ''';
}

class Labels {
  Set<Label> _labels;
  get labels => _labels;
  get length => _labels.length;
  void append(l) => _labels.add(l);
  bool contains(l) => _labels.contains(l);
  bool containsString(s) => labels.contains(Label(s));
  bool intersect(List<Label> list) {
    for (var l in list) if (_labels.contains(l)) return true;
    return false;
  }

  String summary() {
    String markdown = '(';
    _labels.forEach((label) {
      markdown = '${markdown}${label.label}';
      if (label != _labels.last) markdown = '${markdown}, ';
    });
    markdown = '${markdown})';
    return markdown;
  }

  String toCsv() {
    String csv = '';
    labels.forEach((label) {
      csv += '${csv}${label.label}';
      if (label != labels.last) csv = '${csv},';
    });
    return csv;
  }

  String toString() {
    return summary();
  }

  String priority() {
    final priorities = {'P0', 'P1', 'P2', 'P3', 'P4', 'P5', 'P6'};
    String result = '';
    priorities.forEach((p) {
      if (containsString(p)) {
        result = p;
        return;
      }
    });
    return result;
  }

  Labels(this._labels);
  static Labels fromGraphQL(dynamic node) {
    var result = Labels(Set<Label>());
    for (dynamic n in node['edges']) {
      result.append(Label(n['node']['name']));
    }
    return result;
  }
}

class TimelineItem {
  String _type;
  String get type => _type;
  String _title;
  String get title => _title;
  int _number;
  int get number => _number;
  Actor _actor;
  Actor get actor => _actor;
  DateTime _createdAt;
  DateTime get createdAt => _createdAt;

  TimelineItem(
      this._type, this._title, this._number, this._actor, this._createdAt);

  static TimelineItem fromGraphQL(dynamic node) {
    String title = null;
    int number = null;
    Actor actor = null;

    if (node['__typename'] == 'MilestonedEvent' ||
        node['__typename'] == 'DemilestonedEvent') {
      title = node['milestoneTitle'];
      actor = Actor.fromGraphQL(node['actor']);
    } else if (node['__typename'] == 'CrossReferencedEvent') {
      title = node['source']['title'];
      number = node['source']['number'];
    } else if (node['__typename'] == 'AssignedEvent' ||
        node['__typename'] == 'UnassignedEvent') {
      actor =
          node['assignee'] != null ? Actor.fromGraphQL(node['assignee']) : null;
    }

    return TimelineItem(node['__typename'], title, number, actor,
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']));
  }

  String toString() {
    var result = '${_type} (' + _createdAt.toIso8601String() + ')';
    result = '${result}' + (_actor != null ? ' by ${actor.login}' : '');

    if (type == 'CrossReferencedEvent') {
      result =
          '${result} [${_number}](https://github.com/flutter/flutter/issues/${_number}) ${_title}';
    } else if (_type == 'MilestonedEvent') {
      result = '${result} > ${title}';
    } else if (_type == 'DemilestonedEvent') {
      result = '${result} < ${title}';
    } else if (_type == 'AssignedEvent') {
      result = '${result} > ${actor.login}';
    } else if (_type == 'UnassignedEvent') {
      result = '${result} < ${actor.login}';
    }

    return result;
  }

  // TODO Probably need something better here.
  String toCsv() {
    return toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineItem &&
          runtimeType == other.runtimeType &&
          _type == other._type &&
          _title == other._title &&
          _number == other._number;

  @override
  int get hashCode =>
      hash2(hash2(_type.hashCode, _title.hashCode), _number.hashCode);
}

class Timeline {
  List<TimelineItem> _timeline;
  get timeline => _timeline;
  get length => _timeline.length;
  get originalMilestone {
    for (var item in _timeline) {
      if (item.type == 'MilestonedEvent') {
        return item;
      }
    }
    return null;
  }

  List<TimelineItem> get milestoneTimeline {
    var result = <TimelineItem>[];
    _timeline.forEach((item) {
      if (item.type == 'MilestonedEvent' || item.type == 'DemilestonedEvent') {
        result.add(item);
      }
    });
    return result;
  }

  void append(l) => _timeline.add(l);
  bool contains(l) => _timeline.contains(l);

  String summary() {
    String markdown = '';
    _timeline.forEach((entry) => markdown = '${markdown}${entry}\n\n');
    return markdown.length > 2
        ? markdown.substring(0, markdown.length - 2)
        : markdown;
  }

  String toString() {
    return summary();
  }

  String toCsv() {
    String csv = '';
    _timeline.forEach((entry) => csv = '${csv}${entry},');
    return csv.length > 1 ? csv.substring(0, csv.length - 1) : csv;
  }

  TimelineItem operator [](int index) => _timeline[index];

  Timeline(this._timeline);
  static Timeline fromGraphQL(dynamic node) {
    assert(node['pageInfo']['hasNextPage'] == false);
    var result = Timeline([]);
    for (dynamic n in node['nodes']) {
      if (n == null) continue;
      result.append(TimelineItem.fromGraphQL(n));
    }
    return result;
  }

  static var graphQLResponse = '''
  {
    pageInfo ${PageInfo.graphQLResponse},
    nodes {
      __typename
      ... on CrossReferencedEvent {
        createdAt,
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
      ... on MilestonedEvent {
        createdAt,
        actor {
          login,
          resourcePath,
          url
        }, 
        id,
        milestoneTitle
      }
      ... on DemilestonedEvent {
        createdAt,          
        actor {
          login,
          resourcePath,
          url
        }, 
        id, 
        milestoneTitle
      }
      ... on AssignedEvent {
        createdAt,          
        assignee {
          ... on User {
            login,
            resourcePath,
            url
          }
          ... on Bot {
            login,
            resourcePath,
            url            
          }
        }
      }
      ... on UnassignedEvent {
        createdAt,          
        assignee {
          ... on User {
            login,
            resourcePath,
            url
          }
        }          
      }
    }
  }
  ''';
}

class Milestone {
  String _title;
  get title => _title;
  String _id;
  get id => _id;
  int _number;
  get number => _number;
  String _url;
  get url => _url;
  bool _closed;
  get closed => _closed;
  DateTime _createdAt;
  get createdAt => _createdAt;
  DateTime _closedAt;
  get closedAt => _closedAt;
  DateTime _dueOn;
  get dueOn => _dueOn;

  Milestone(this._title, this._id, this._number, this._url, this._closed,
      this._createdAt, this._closedAt, this._dueOn);

  static Milestone fromGraphQL(dynamic node) {
    return Milestone(
        node['title'],
        node['id'],
        node['number'],
        node['url'],
        node['closed'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
        node['dueOn'] == null ? null : DateTime.parse(node['dueOn']));
  }

  String toString() {
    return 'due on ${dueOn} (${title})';
  }

  String toCsv() {
    return '${title},${dueOn}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Milestone &&
          runtimeType == other.runtimeType &&
          _title == other._title &&
          _number == other._number;

  @override
  int get hashCode => _number.hashCode;

  static final graphQLResponse = '''
  milestone {
    title,
    id,
    number,
    url,
    closed,
    createdAt,
    closedAt,
    dueOn,
  }
  ''';
}

class Repository {
  String _organization;
  get organization => _organization;
  String _repository;
  get repository => _repository;

  Repository(String slug) {
    _organization = slug.split('/')[0];
    _repository = slug.split('/')[1];
  }
  static Repository fromGraphQL(dynamic node) {
    return Repository(node['nameWithOwner']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Repository &&
          runtimeType == other.runtimeType &&
          _organization == other._organization &&
          _repository == other._repository;

  @override
  int get hashCode => '${_organization}/${_repository}'.hashCode;
}

class Actor {
  String _id;
  get id => _id;
  String _login;
  get login => _login;
  String _url;
  get url => _url;
  List<String> _organizationIds;
  get organizationIds => _organizationIds;

  get organizationsStream async* {
    for (var id in _organizationIds) {
      var query = Organization.requestId(id);
      print(query);
      final options = QueryOptions(document: gql(query));
      final page = await _client.query(options);
      if (page.exception != null && page.exception != '') {
        print(page.exception);
        return;
      }
      yield Organization.fromGraphQL(page.data['node']);
    }
  }

  static String request(String login,
      {String organizationsAfter = null, String repositoriesAfter = null}) {
    return _childQuery
        .replaceAll(r'${login}', login)
        .replaceAll(r'${organizationsAfter}',
            organizationsAfter == null ? '' : ', after: ${organizationsAfter}')
        .replaceAll(r'${repositoriesAfter}',
            repositoriesAfter == null ? '' : 'after: ${repositoriesAfter}');
  }

  Actor(this._id, this._login, this._url, this._organizationIds);
  static Actor fromGraphQL(dynamic node) {
    if (node == null || node['login'] == null) return null;
    List<String> orgIds = [];
    if (node['organizations'] != null &&
        node['organizations']['edges'] != null) {
      for (var org in node['organizations']['edges']) {
        orgIds.add(org['node']['id']);
      }
    }
    return Actor(node['id'], node['login'], node['url'], orgIds);
  }

  String toString() => this._login;
  String toCsv() => this._login;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Actor && runtimeType == other.runtimeType && _id == other._id;

  @override
  int get hashCode => _id.hashCode;
  static var graphQLResponse = '''
  {
    id,
    login,
    resourcePath,
    url,
    avatarUrl,
    organizations {
      edges {
        node {
          id, 
          name,
        }
      }
    }
  }
  ''';

  static var abbreviatedGraphQLResponse = '''
  {
    login,
    resourcePath,
    url,
  }
  ''';

  static var _childQuery = r'''
  query {
    user(login: "${login}") {
      id,
      login,
      resourcePath,
      url,
      avatarUrl,
    	organizations(first:10${organizationsAfter}) {
      	edges {
          node {
            id,
            name
          }
        }
    	}
    }
  }
  ''';
}

class Organization {
  String _id;
  get id => _id;
  String _avatarUrl;
  get avatarUrl => _avatarUrl;
  DateTime _createdAt;
  get createdAt => _createdAt;
  String _description;
  get description => _description;
  String _email;
  get email => _email;
  String _login;
  get login => _login;
  String _name;
  get name => _name;

  get pendingMembersStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = Organization.request(id, pendingMembersAfter: after);
      final options = QueryOptions(document: gql(query));

      final page = await _client.query(options);
      try {
        PageInfo pageInfo = PageInfo.fromGraphQL(
            page.data['organization']['pendingMembers']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var membersBuffer = <Actor>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['organization']['pendingMembers']
          ['edges']) {
        membersBuffer.add(Actor.fromGraphQL(jsonSub['node']));
      }

      // Yield each item in our buffer
      if (membersBuffer.length > 0)
        do {
          yield membersBuffer[bufferIndex++];
        } while (bufferIndex < membersBuffer.length);
    } while (hasNextPage);
  }

  get teamsStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = Organization.request(_login, teamsAfter: after);
      final options = QueryOptions(document: gql(query));
      final page = await _client.query(options);
      try {
        PageInfo pageInfo = PageInfo.fromGraphQL(
            page.data['organization']['teams']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var teamsBuffer = <Team>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['organization']['teams']['edges']) {
        teamsBuffer.add(Team.fromGraphQL(jsonSub['node']));
      }

      // Yield each item in our buffer
      if (teamsBuffer.length > 0)
        do {
          yield teamsBuffer[bufferIndex++];
        } while (bufferIndex < teamsBuffer.length);
    } while (hasNextPage);
  }

  Organization(this._id, this._avatarUrl, this._createdAt, this._description,
      this._email, this._login, this._name);

  static Organization fromGraphQL(dynamic node) {
    return Organization(
        node['id'],
        node['avatarUrl'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['description'],
        node['email'],
        node['login'],
        node['name']);
  }

  static String request(String login,
      {String pendingMembersAfter = null,
      String repositoriesAfter = null,
      String teamsAfter = null}) {
    return Organization._childQueryLogin
        .replaceAll(r'${data}', _queryData)
        .replaceAll(r'${login}', login)
        .replaceAll(
            r'${pendingMembersAfter}',
            pendingMembersAfter == null
                ? ''
                : ', after: ${pendingMembersAfter}')
        .replaceAll(r'${repositoriesAfter}',
            repositoriesAfter == null ? '' : 'after: ${repositoriesAfter}')
        .replaceAll(
            r'${teamsAfter}', teamsAfter == null ? '' : 'after: ${teamsAfter}');
  }

  static String requestId(String id,
      {String pendingMembersAfter = null,
      String repositoriesAfter = null,
      String teamsAfter = null}) {
    return Organization._childQueryId
        .replaceAll(r'${data}', _queryData)
        .replaceAll(r'${id}', id)
        .replaceAll(
            r'${pendingMembersAfter}',
            pendingMembersAfter == null
                ? ''
                : ', after: ${pendingMembersAfter}')
        .replaceAll(r'${repositoriesAfter}',
            repositoriesAfter == null ? '' : 'after: ${repositoriesAfter}')
        .replaceAll(
            r'${teamsAfter}', teamsAfter == null ? '' : 'after: ${teamsAfter}');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team && runtimeType == other.runtimeType && _id == other._id;

  @override
  int get hashCode => _id.hashCode;

  static String _childQueryLogin = r'''
  query {
    organization(login:"${login}") {
      ${data}
  }
  ''';

  static String _childQueryId = r'''
  query {
    node(id:"${id}") {
      ... on Organization {
        ${data}
      }
    }
  ''';

  static String _queryData = r'''
      id,
      avatarUrl,
      createdAt, 
      description,
      email,
      login,
      name,
      pendingMembers(first: 10${pendingMembersAfter}) {
        totalCount,
        pageInfo {
          hasNextPage,
          endCursor,
        },
        edges {
          node {
            login,
            resourcePath,
            url
          }
        }
      },
      repositories(first: 10${repositoriesAfter}) {
        totalCount, 
          pageInfo {
          hasNextPage,
          endCursor,
        },
      }
      teams(first: 10${teamsAfter}) {
        totalCount,
        pageInfo {
          hasNextPage,
          endCursor,
        },
        edges {
          node {
            id,
            name,
            description,
            avatarUrl,
            createdAt,
            updatedAt,
          }
        }
      }
    }
  ''';
}

class Team {
  String _id;
  get id => _id;
  String _avatarUrl;
  get avatarUrl => _avatarUrl;
  String _name;
  get name => _name;
  String _description;
  get description => _description;
  DateTime _createdAt;
  get createdAt => _createdAt;
  DateTime _updatedAt;
  get updatedAt => _updatedAt;

  get membersStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = Team.request(id, membersAfter: after);
      final options = QueryOptions(document: gql(query));

      final page = await _client.query(options);
      try {
        PageInfo pageInfo =
            PageInfo.fromGraphQL(page.data['node']['members']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var membersBuffer = <Actor>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['node']['members']['edges']) {
        membersBuffer.add(Actor.fromGraphQL(jsonSub['node']));
      }

      // Yield each item in our buffer
      if (membersBuffer.length > 0)
        do {
          yield membersBuffer[bufferIndex++];
        } while (bufferIndex < membersBuffer.length);
    } while (hasNextPage);
  }

  get childTeamsStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = Team.request(id, childTeamsAfter: after);
      final options = QueryOptions(document: gql(query));

      final page = await _client.query(options);
      try {
        PageInfo pageInfo =
            PageInfo.fromGraphQL(page.data['node']['childTeams']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var teamBuffer = <Team>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['node']['childTeams']['edges']) {
        teamBuffer.add(Team.fromGraphQL(jsonSub));
      }

      // Yield each item in our buffer
      if (teamBuffer.length > 0)
        do {
          yield teamBuffer[bufferIndex++];
        } while (bufferIndex < teamBuffer.length);
    } while (hasNextPage);
  }

  Team(this._id, this._avatarUrl, this._createdAt, this._description,
      this._name, this._updatedAt);

  static Team fromGraphQL(dynamic node) {
    return Team(
        node['id'],
        node['avatarUrl'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['description'],
        node['name'],
        node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']));
  }

  static String request(String id,
      {String childTeamsAfter = null, String membersAfter = null}) {
    return Team._childQuery
        .replaceAll(r'${ownerId}', id)
        .replaceAll(r'${childTeamsAfter}',
            childTeamsAfter == null ? '' : ', after: ${childTeamsAfter}')
        .replaceAll(r'${membersAfter}',
            membersAfter == null ? '' : 'after: ${membersAfter}');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team && runtimeType == other.runtimeType && _id == other._id;

  @override
  int get hashCode => _id.hashCode;

// sample ID  MDQ6VGVhbTM3MzAzNzU
  static String _childQuery = r'''
  query { 
      node(id:"${ownerId}") {
        ... on Team {
        id,
        name,
        description,
        avatarUrl,
        createdAt,
        updatedAt,
        members(first: 10${membersAfter}) {
          totalCount,
          pageInfo {
          	hasNextPage,
          	endCursor,
        	},
        	edges {
            node {
              login,
              resourcePath,
              url
            }
          }
        },
        childTeams(first: 10${childTeamsAfter} ) {
          totalCount,
          pageInfo {
            hasNextPage,
            endCursor,
          },
          nodes {
            avatarUrl,
            createdAt,
            description,
            id,
            name,
            updatedAt
          }
        }
      }
    }
  }
  ''';
}

class Issue {
  String _title;
  get title => _title;
  String _id;
  get id => _id;
  int _number;
  get number => _number;
  String _state;
  get state => _state;
  Actor _author;
  get author => _author;
  List<Actor> _assignees;
  get assignees => _assignees;
  String _body;
  get body => _body;
  Labels _labels;
  get labels => _labels;
  String _url;
  get url => _url;
  DateTime _createdAt;
  get createdAt => _createdAt;
  DateTime _closedAt;
  get closedAt => _closedAt;
  DateTime _lastEditAt;
  get lastEditAt => _lastEditAt;
  DateTime _updatedAt;
  get updatedAt => _updatedAt;
  Repository _repository;
  get repository => _repository;
  Milestone _milestone;
  get milestone => _milestone;
  Timeline _timeline;
  get timeline => _timeline;
  get reactionStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = _reactionQuery
          .replaceAll(r'${issue}', this.number.toString())
          .replaceAll(r'${after}', after);
      final options = QueryOptions(document: gql(query));
      final page = await _client.query(options);

      try {
        PageInfo pageInfo = PageInfo.fromGraphQL(
            page.data['repository']['issue']['reactions']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var bufferReactions = <Reaction>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['repository']['issue']['reactions']
          ['nodes']) {
        bufferReactions.add(Reaction.fromGraphQL(jsonSub));
      }

      // Yield each item in our buffer
      if (bufferReactions.length > 0)
        do {
          yield bufferReactions[bufferIndex++];
        } while (bufferIndex < bufferReactions.length);
    } while (hasNextPage);
  }

  get commentStream async* {
    var after = 'null';
    bool hasNextPage;
    do {
      var query = _commentQuery
          .replaceAll(r'${ownerId}', _id)
          .replaceAll(r'${after}', after);
      final options = QueryOptions(document: gql(query));

      final page = await _client.query(options);
      try {
        PageInfo pageInfo =
            PageInfo.fromGraphQL(page.data['node']['comments']['pageInfo']);
        hasNextPage = pageInfo.hasNextPage;
        after = '"${pageInfo.endCursor}"';
      } on Error {
        return;
      }
      // Parse the responses into a buffer
      var commentBuffer = <Comment>[];
      var bufferIndex = 0;
      for (var jsonSub in page.data['node']['comments']['nodes']) {
        commentBuffer.add(Comment.fromGraphQL(jsonSub));
      }

      // Yield each item in our buffer
      if (commentBuffer.length > 0)
        do {
          yield commentBuffer[bufferIndex++];
        } while (bufferIndex < commentBuffer.length);
    } while (hasNextPage);
  }

  Issue(
      this._title,
      this._id,
      this._number,
      this._state,
      this._author,
      this._assignees,
      this._body,
      this._labels,
      this._url,
      this._createdAt,
      this._closedAt,
      this._lastEditAt,
      this._updatedAt,
      this._repository,
      this._milestone,
      this._timeline);

  // Passed a node containing an issue, return the issue
  static Issue fromGraphQL(dynamic node) {
    List<Actor> assignees = null;
    var edges = (node['assignees'] ?? {})['edges'];
    if (edges != null && edges.length != 0) {
      assignees = <Actor>[];
      for (var node in edges) {
        assignees.add(Actor.fromGraphQL(node['node']));
      }
    }
    return Issue(
        node['title'],
        node['id'],
        node['number'],
        node['state'],
        node['author'] == null ? null : Actor.fromGraphQL(node['author']),
        assignees,
        node['body'],
        node['labels'] == null ? null : Labels.fromGraphQL(node['labels']),
        node['url'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
        node['lastEditedAt'] == null
            ? null
            : DateTime.parse(node['lastEditedAt']),
        node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
        node['repository'] == null
            ? null
            : Repository.fromGraphQL(node['repository']),
        node['milestone'] == null
            ? null
            : Milestone.fromGraphQL(node['milestone']),
        node['timelineItems'] == null
            ? null
            : Timeline.fromGraphQL(node['timelineItems']));
  }

  List<Label> _interesting = [
    Label('prod: API break'),
    Label('severe: API break'),
    Label('severe: new feature'),
    Label('severe: performance'),
  ];

  String summary(
      {bool boldInteresting = true,
      showMilestone = false,
      bool linebreakAfter = false,
      includeLabels: true}) {
    var labelsSummary = includeLabels ? _labels.summary() : '';
    var markdown = '[${this.number}](${this.url})';
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (showMilestone) {
      markdown = '${markdown} ' +
          (_milestone == null ? '[no milestone]' : '[${_milestone.title}]');
    }
    if (boldInteresting && _labels.intersect(_interesting))
      markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  String verbose({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url})';
    if (_assignees == null || _assignees.length == 0)
      markdown = '${markdown} > UNASSIGNED';
    else {
      markdown = '${markdown} > (';
      _assignees
          .forEach((assignee) => markdown = '${markdown}${assignee.login}, ');
      markdown = markdown.substring(0, markdown.length - 2);
      markdown = '${markdown})';
    }
    if (_milestone == null)
      markdown = '${markdown} with no milestone';
    else
      markdown = '${markdown} due on ${_milestone.dueOn} (${_milestone.title})';
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (boldInteresting && _labels.intersect(_interesting))
      markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  static get tsvHeader =>
      'Number\tTitle\tPriority\tState\tAuthor\tCreated At\tAssignees\tOriginal Milestone\tCurrent Milestone\tDue On\tClosed At';

  // Top level entities like Issue and PR must TSV, because their fields CSV,
  // and Google Sheets only takes mixed CSV/TSV records with TSV being the containing
  // record format.
  String toTsv() {
    String milestoneHistory = '';
    if (timeline != null)
      timeline.milestoneTimeline.forEach((milestone) => milestoneHistory =
          milestone == null
              ? milestoneHistory
              : '${milestoneHistory},${milestone.title}');
    if (milestoneHistory.length > 0)
      milestoneHistory = milestoneHistory.substring(1);
    if (milestoneHistory.length == 0)
      milestoneHistory = _milestone != null ? _milestone.title : '';

    var originalMilestone;
    if (_timeline == null) {
      originalMilestone = '';
    } else {
      if (_timeline.originalMilestone == null) {
        originalMilestone = '';
      } else {
        _timeline.originalMilestone.title;
      }
    }
    var currentMilestone = _milestone == null ? '' : _milestone.title;
    var dueOn = _milestone == null ? '' : _milestone.dueOn.toString();

    String tsv = '';
    tsv = '${tsv}=HYPERLINK("${_url}","${_number}")';
    tsv = '${tsv}\t${_title}';
    tsv = '${tsv}\t${_labels.priority()}';
    tsv = '${tsv}\t${_state}';
    tsv = '${tsv}\t' + (_author == null ? '' : _author.toCsv());
    tsv = '${tsv}\t${createdAt}';
    if (_assignees != null && _assignees.length > 0) {
      tsv = '${tsv}\t';
      assignees.forEach((assignee) => tsv = '${tsv}${assignee.login},');
      tsv = tsv.substring(0, tsv.length - 1);
    } else {
      tsv = '${tsv}\t';
    }
    tsv = '${tsv}\t${originalMilestone}';
    tsv = '${tsv}\t${currentMilestone}';
    tsv = '${tsv}\t${dueOn}';
    tsv = _closedAt == null ? '${tsv}\t' : '${tsv}\t${_closedAt}';

    return tsv;
  }

  String html() {
    var result = '';
    result += '<a href="${_url}">#${_number}</a> ${_title}';
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Issue && runtimeType == other.runtimeType && _id == other._id;

  @override
  int get hashCode => _id.hashCode;

  static final graphQLResponse = '''
  {
    __typename,
    title,
    id,
    number,
    state,
    author ${Actor.abbreviatedGraphQLResponse},
    assignees(after: null, last: 100) {
      edges {
        node ${Actor.abbreviatedGraphQLResponse}
      }
    },
    body,
    labels(first:100) {
      edges {
        node ${Label.graphQLResponse}
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
    ${Milestone.graphQLResponse},
    timelineItems(first: 100, 
    itemTypes:[CROSS_REFERENCED_EVENT, MILESTONED_EVENT, DEMILESTONED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT]) 
      ${Timeline.graphQLResponse}
  }
  ''';

  final _reactionQuery = r'''
  query {
    repository(owner:"flutter", name:"flutter") {
      issue(number: ${issue}) {
            reactions(first: 100, after: ${after}) {
              totalCount,
              pageInfo {
                endCursor,
                hasNextPage,
              }
              nodes {
                content
              },
            },
          },
        },
      }
''';

// sample ID  "MDU6SXNzdWUyOTM3NTMyODE="
  final _commentQuery = r'''
  query { 
      node(id:"${ownerId}") {
        ... on Issue {
        id,
        comments(first: 100, after: ${after} ) {
          totalCount,
          pageInfo {
            hasNextPage,
            endCursor,
          },
          nodes {
            id,
            body,
            author { url, login},
            reactions(first: 100, after: null) {
              totalCount,
              nodes{
                content
              }
            }
          }
        }
      }
      ... on PullRequest {
        id,
        comments(first: 100, after: ${after} ) {
          totalCount,
          pageInfo {
            hasNextPage,
            endCursor,
          },
          nodes {
            id,
            body,
            author { url, login},
            reactions(first: 100, after: null) {
              totalCount,
              nodes{
                content
              }
            }
          }
        }
      }
    }
  }
  ''';
}

class PullRequest {
  String _title;
  get title => _title;
  String _id;
  get id => _id;
  int _number;
  get number => _number;
  String _state;
  get state => _state;
  Actor _author;
  get author => _author;
  List<Actor> _reviewers;
  get reviewers => _reviewers;
  List<Actor> _assignees;
  get assignees => _assignees;
  String _body;
  get body => _body;
  Milestone _milestone;
  get milestone => _milestone;
  Labels _labels;
  get labels => _labels;
  String _url;
  get url => _url;
  bool _merged;
  get merged => _merged;
  DateTime _createdAt;
  get createdAt => _createdAt;
  DateTime _mergedAt;
  get mergedAt => _mergedAt;
  DateTime _lastEditAt;
  get lastEditAt => _lastEditAt;
  DateTime _updatedAt;
  get updatedAt => _updatedAt;
  DateTime _closedAt;
  get closedAt => _closedAt;
  Repository _repository;
  get repository => _repository;
  Timeline _timeline;
  get timeline => _timeline;

  PullRequest(
      this._title,
      this._id,
      this._number,
      this._state,
      this._author,
      this._reviewers,
      this._assignees,
      this._body,
      this._milestone,
      this._labels,
      this._url,
      this._merged,
      this._createdAt,
      this._mergedAt,
      this._lastEditAt,
      this._updatedAt,
      this._closedAt,
      this._repository,
      this._timeline);

  // Passed a node containing an issue, return the issue
  static PullRequest fromGraphQL(dynamic node) {
    List<Actor> assignees = null;
    List<Actor> reviewers = null;
    if (node['assignees']['edges'] != null &&
        node['assignees']['edges'].length != 0) {
      assignees = <Actor>[];
      for (var node in node['assignees']['edges']) {
        assignees.add(Actor.fromGraphQL(node['node']));
      }
    }
    if (node['reviews']['edges'] != null &&
        node['reviews']['edges'].length != 0) {
      reviewers = <Actor>[];
      for (var node in node['reviews']['edges']) {
        if (node['node']['author'] != null)
          reviewers.add(Actor.fromGraphQL(node['node']['author']));
      }
    }
    return PullRequest(
        node['title'],
        node['id'],
        node['number'],
        node['state'],
        node['author'] == null ? null : Actor.fromGraphQL(node['author']),
        reviewers,
        assignees,
        node['body'],
        node['milestone'] == null
            ? null
            : Milestone.fromGraphQL(node['milestone']),
        node['labels'] == null ? null : Labels.fromGraphQL(node['labels']),
        node['url'],
        node['merged'],
        node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
        node['mergedAt'] == null ? null : DateTime.parse(node['updatedAt']),
        node['lastEditedAt'] == null
            ? null
            : DateTime.parse(node['lastEditedAt']),
        node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
        node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
        node['repository'] == null
            ? null
            : Repository.fromGraphQL(node['repository']),
        node['timelineItems'] == null
            ? null
            : Timeline.fromGraphQL(node['timelineItems']));
  }

  String summary(
      {bool linebreakAfter = false,
      bool boldInteresting = false,
      includeLabels: true}) {
    var labelsSummary = includeLabels ? _labels.summary() : '';
    var markdown =
        '[${this.number}](${this.url}) ${this.title} ${labelsSummary}';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  String verbose({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url})';
    if (_assignees == null || _assignees.length == 0)
      markdown = '${markdown} > UNASSIGNED';
    else {
      markdown = '${markdown} > (';
      _assignees
          .forEach((assignee) => markdown = '${markdown}${assignee.login}, ');
      markdown = markdown.substring(0, markdown.length - 2);
      markdown = '${markdown})';
    }
    if (_milestone == null)
      markdown = '${markdown} with no milestone';
    else
      markdown = '${markdown} due on ${_milestone.dueOn} (${_milestone.title})';
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  static get tsvHeader =>
      'Number\tTitle\tPriority\tAuthor\tCreated At\tMerged?\tAssignees\tReviewers\tOriginal Milestone\tCurrent Milestone\tDue On\tMerged At\tClosed At';

  // Top level entities like Issue and PR must TSV, because their fields CSV,
  // and Google Sheets only takes mixed CSV/TSV records with TSV being the containing
  // record format.
  String toTsv() {
    var milestoneHistory = '';
    if (timeline != null)
      timeline.milestoneTimeline().forEach((milestone) =>
          milestoneHistory = '${milestoneHistory},${milestone.title}');
    if (milestoneHistory.length > 0)
      milestoneHistory = milestoneHistory.substring(1);
    if (milestoneHistory.length == 0)
      milestoneHistory = _milestone != null ? milestone.title : '';
    var originalMilestone;
    if (_timeline == null) {
      originalMilestone = '';
    } else {
      if (_timeline.originalMilestone == null) {
        originalMilestone = '';
      } else {
        _timeline.originalMilestone.title;
      }
    }
    var currentMilestone = _milestone == null ? '' : _milestone.title;
    var dueOn = _milestone == null ? '' : _milestone.dueOn.toString();

    String tsv = '';
    tsv = '${tsv}=HYPERLINK("${_url}","${_number}")';
    tsv = '${tsv}\t${_title}';
    tsv = '${tsv}\t${_labels.priority()}';
    tsv = '${tsv}\t${_author.toCsv()}';
    tsv = '${tsv}\t${createdAt}';
    tsv = '${tsv}\t' + (_merged ? 'Y' : 'N');
    if (_assignees != null && _assignees.length > 0) {
      tsv = '${tsv}\t';
      _assignees.forEach((assignee) => tsv = '${tsv}${assignee.login},');
      tsv = tsv.substring(0, tsv.length - 1);
    } else {
      tsv = '${tsv}\t';
    }
    if (_reviewers != null && _reviewers.length > 0) {
      tsv = '${tsv}\t';
      _reviewers.forEach((reviewer) => tsv = '${tsv}${reviewer.login},');
      tsv = tsv.substring(0, tsv.length - 1);
    } else {
      tsv = '${tsv}\t';
    }
    tsv = '${tsv}\t${originalMilestone}';
    tsv = '${tsv}\t${currentMilestone}';
    tsv = '${tsv}\t${dueOn}';
    tsv = _mergedAt == null ? '${tsv}\t' : '${tsv}\t${_mergedAt}';
    tsv = _closedAt == null ? '${tsv}\t' : '${tsv}\t${_closedAt}';

    return tsv;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PullRequest &&
          runtimeType == other.runtimeType &&
          _id == other._id;

  @override
  int get hashCode => _id.hashCode;

  static final graphQLResponse = '''
  {
    __typename,
    title,
    id,
    number,
    state,
    author ${Actor.abbreviatedGraphQLResponse},
    assignees(after: null, last: 100) {
      edges {
        node ${Actor.abbreviatedGraphQLResponse}
      }
    },
    reviews(after:null, last:100) {
      edges {
        node {
          author {
            avatarUrl
            login
            resourcePath
            url
          }
        }
      }
    },  
    body,
    ${Milestone.graphQLResponse},
    labels(first:100) {
      edges {
        node ${Label.graphQLResponse}
      }
    },
    url,
    merged,
    createdAt,
    lastEditedAt,
    updatedAt,
    closedAt,
    mergedAt,
    repository {
      nameWithOwner
    },
  }

  ''';
}

enum ClusterType { byLabel, byAuthor, byAssignee, byReviewer, byMilestone }
enum ClusterReportSort { byKey, byCount }

class Cluster {
  ClusterType _type;
  get type => _type;
  SplayTreeMap<String, dynamic> _clusters;
  get clusters => _clusters;
  get keys => _clusters.keys;
  dynamic operator [](String key) => _clusters[key];

  void remove(String key) {
    if (_clusters.containsKey(key)) _clusters.remove(key);
  }

  static final _unlabeledKey = '__no labels__';
  static final _unassignedKey = '__unassigned__';
  static final _noMilestoneKey = '__no milestone__';

  static Cluster byLabel(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_unlabeledKey] = [];

    for (var item in issuesOrPullRequests) {
      if (!(item is Issue) && !(item is PullRequest)) {
        throw ('invalid type!');
      }
      if (item.labels != null) {
        for (var label in item.labels.labels) {
          var name = label.label;
          if (!result.containsKey(name)) {
            result[name] = [];
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

    for (var item in issuesOrPullRequests) {
      if (!(item is Issue) && !(item is PullRequest)) {
        throw ('invalid type!');
      }
      var name = item.author != null ? item.author.login : '@@@ NO AUTHOR @@@';
      if (!result.containsKey(name)) {
        result[name] = [];
      }
      result[name].add(item);
    }

    return Cluster._internal(ClusterType.byAuthor, result);
  }

  static Cluster byAssignees(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_unassignedKey] = [];

    for (var item in issuesOrPullRequests) {
      if (!(item is Issue) && !(item is PullRequest)) {
        throw ('invalid type!');
      }
      if (item.assignees == null || item.assignees.length == 0) {
        result[_unassignedKey].add(item);
      } else
        for (var assignee in item.assignees) {
          var name = assignee.login;
          if (!result.containsKey(name)) {
            result[name] = [];
          }
          result[name].add(item);
        }
    }

    return Cluster._internal(ClusterType.byAssignee, result);
  }

  static Cluster byReviewers(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_unassignedKey] = [];

    for (var item in issuesOrPullRequests) {
      if (!(item is PullRequest)) {
        throw ('invalid type!');
      }
      var pr = item as PullRequest;
      if (pr.reviewers == null || pr.reviewers.length == 0) {
        result[_unassignedKey].add(item);
      } else
        for (var reviewer in pr.reviewers) {
          var name = reviewer.login;
          if (!result.containsKey(name)) {
            result[name] = [];
          }
          result[name].add(item);
        }
    }

    return Cluster._internal(ClusterType.byReviewer, result);
  }

  static Cluster byMilestone(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_noMilestoneKey] = [];

    for (var item in issuesOrPullRequests) {
      if (!(item is Issue) && !(item is PullRequest)) {
        throw ('invalid type!');
      }
      if (item.milestone == null) {
        result[_noMilestoneKey].add(item);
      } else {
        if (!result.containsKey(item.milestone.title)) {
          result[item.milestone.title] = [];
        }
        result[item.milestone.title].add(item);
      }
    }

    return Cluster._internal(ClusterType.byMilestone, result);
  }

  String summary() {
    var result = 'Cluster of';
    switch (type) {
      case ClusterType.byAssignee:
        result = '${result} assignees';
        break;
      case ClusterType.byReviewer:
        result = '{$result} reviewers.';
        break;
      case ClusterType.byAuthor:
        result = '${result} authors';
        break;
      case ClusterType.byLabel:
        result = '${result} labels';
        break;
      case ClusterType.byMilestone:
        result = '${result} milestones';
        break;
    }
    result = '${result} has ${this.clusters.keys.length} clusters';
    return result;
  }

  String toString() => summary();

  String toMarkdown(
      {ClusterReportSort sortType,
      bool skipEmpty = true,
      showStatistics = false}) {
    var result = '';
    var m = mean(), s = stdev();

    if (clusters.keys.length == 0) {
      result = 'no items\n\n';
    } else {
      var kind = '';
      // Determine the type of this cluster
      for (var key in clusters.keys) {
        if (clusters[key] != null && clusters[key].length != 0) {
          dynamic item = clusters[key].first;
          if (item is Issue) {
            kind = 'issue(s)';
          } else {
            kind = 'pull request(s)';
          }
          break;
        }
      }

      // Sort labels in descending order
      List<String> keys = clusters.keys.toList();
      keys.sort((a, b) => sortType == ClusterReportSort.byCount
          ? clusters[b].length - clusters[a].length
          : a.compareTo(b));
      // Remove the unlabled item if it's empty
      if (clusters[_unlabeledKey] != null &&
          clusters[_unlabeledKey].length == 0) keys.remove(_unlabeledKey);
      if (clusters[_unassignedKey] != null &&
          clusters[_unassignedKey].length == 0) keys.remove(_unassignedKey);
      if (clusters[_noMilestoneKey] != null &&
          clusters[_noMilestoneKey].length == 0) keys.remove(_noMilestoneKey);
      if (skipEmpty) {
        if (keys.contains(_unlabeledKey)) keys.remove(_unlabeledKey);
        if (keys.contains(_unassignedKey)) keys.remove(_unassignedKey);
      }
      // Dump all clusters
      for (var clusterKey in keys) {
        result =
            '${result}\n\n#### ${clusterKey} - ${clusters[clusterKey].length} ${kind}';
        if (showStatistics) {
          var z = (clusters[clusterKey].length - m) / s;
          result = '${result}, z = ${z}';
        }

        for (var item in clusters[clusterKey]) {
          result = '${result}\n\n' +
              item.summary(linebreakAfter: true, boldInteresting: false);
        }
      }
    }
    return '${result}\n\n';
  }

  double mean() {
    double sum = 0.0;
    double l = 0.0;
    switch (type) {
      case ClusterType.byAuthor:
        l = (clusters.keys.contains(_unassignedKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byAssignee:
      case ClusterType.byReviewer:
        l = (clusters.keys.contains(_unassignedKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byMilestone:
        l = (clusters.keys.contains(_noMilestoneKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byLabel:
        l = (clusters.keys.contains(_unlabeledKey)
                ? (clusters.keys.length - 1)
                : clusters.keys.length)
            .toDouble();
        break;
    }
    clusters.keys.forEach((key) => sum += clusters[key].length);
    return sum / l;
  }

  double stdev() {
    double m = mean();
    double sum = 0.0;
    double l = 0.0;
    switch (type) {
      case ClusterType.byAuthor:
        l = (clusters.keys.contains(_unassignedKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byAssignee:
      case ClusterType.byReviewer:
        l = (clusters.keys.contains(_unassignedKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byMilestone:
        l = (clusters.keys.contains(_noMilestoneKey)
                ? clusters.keys.length - 1
                : clusters.keys.length)
            .toDouble();
        break;
      case ClusterType.byLabel:
        l = (clusters.keys.contains(_unlabeledKey)
                ? (clusters.keys.length - 1)
                : clusters.keys.length)
            .toDouble();
        break;
    }
    clusters.keys.forEach((key) =>
        sum += ((clusters[key].length - m) * (clusters[key].length - m)));

    double deviation = sum / l;

    return sqrt(deviation);
  }

  Cluster._internal(this._type, this._clusters);
}
