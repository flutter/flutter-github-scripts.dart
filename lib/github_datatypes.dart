import 'dart:collection';
import 'dart:io';
import 'package:quiver/core.dart' show hash2;


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
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Label &&
    runtimeType == other.runtimeType &&
    _label == other._label;

  @override 
  int get hashCode => _label.hashCode;
}

class Labels {
  Set<Label> _labels;
  get labels => _labels;
  get length => _labels.length;
  void append(l) => _labels.add(l);
  bool contains(l) => _labels.contains(l);
  bool containsString(s) => labels.contains(Label(s));
  bool intersect(List<Label> list) {
    for(var l in list)
      if (_labels.contains(l)) return true;
    return false;
  }
  String summary() {
    String markdown = '(';
    _labels.forEach((label) {
      markdown = markdown + label.label;
      if (label != _labels.last) markdown = markdown + ', ';
    });
    markdown = markdown + ')';
    return markdown;
  }
  String toString() {
    return summary();
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

  TimelineItem(this._type, this._title, this._number);

  static TimelineItem fromGraphQL(dynamic node) {
    return TimelineItem(
      node['__typename'], 
      node['source']['title'], 
      node['source']['number']);
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is TimelineItem &&
    runtimeType == other.runtimeType &&
    _type == other._type &&
    _title == other._title && 
    _number == other._number;

  @override 
  int get hashCode => hash2(
      hash2(_type.hashCode, _title.hashCode),
        _number.hashCode);
}

class Timeline {
  List<TimelineItem> _timeline;
  get timeline => _timeline;
  get length => _timeline.length;
  void append(l) => _timeline.add(l);
  bool contains(l) => _timeline.contains(l);
  
  String summary() {
    String markdown = '';
    _timeline.forEach((entry) {
      markdown = '${markdown} <${entry.type}> [${entry.number}](https://github.com/flutter/flutter/issues/${entry.number}) ${entry.title}';
      if (entry != _timeline.last) markdown = markdown + ',\n';
    });
    markdown = markdown + '\n\n';
    return markdown;
  }
  String toString() {
    return summary();
  }

  TimelineItem operator[](int index) => _timeline[index];

  Timeline(this._timeline);
  static Timeline fromGraphQL(dynamic node) {
    var result = Timeline(List<TimelineItem>());
    for (dynamic n in node['nodes']) {
      result.append(TimelineItem.fromGraphQL(n));
    }
    return result;
  }
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
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Repository &&
    runtimeType == other.runtimeType &&
    _organization == other._organization &&
    _repository == other._repository;

  @override 
  int get hashCode => '${_organization}/${_repository}'.hashCode;
}

class Actor {
  String _login;
  get login => _login;
  String _url;
  get url => _url;

  Actor(this._login, this._url);
  static Actor fromGraphQL(dynamic node) {
    return Actor(node['login'], node['url']);
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Actor &&
    runtimeType == other.runtimeType &&
    _login == other._login;

  @override 
  int get hashCode => _login.hashCode;

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
  Timeline _timeline;
  get timeline => _timeline;

  Issue(this._title, 
    this._id,
    this._number,
    this._state,
    this._author,
    this._body,
    this._labels,
    this._url,
    this._createdAt,
    this._closedAt,
    this._lastEditAt,
    this._updatedAt,
    this._repository,
    this._timeline
  );
   
  // Passed a node containing an issue, return the issue
  static Issue fromGraphQL(dynamic node) {
    return Issue(node['title'],
      node['id'],
      node['number'],
      node['state'],
      node['author'] == null ? null : Actor.fromGraphQL(node['author']),
      node['body'],
      node['labels'] == null ? null : Labels.fromGraphQL(node['labels']),
      node['url'],
      node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
      node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
      node['lastEditedAt'] == null ? null : DateTime.parse(node['lastEditedAt']),
      node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['repository'] == null ? null : Repository.fromGraphQL(node['repository']),
      node['timelineItems'] == null ? null : Timeline.fromGraphQL(node['timelineItems']));
  }

  List<Label> _interesting = [
        Label('prod: API break'),
        Label('severe: API break'),
        Label('severe: new feature'),
        Label('severe: performance'),
    ];

  String summary({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url}) ${this.title} ${labelsSummary}';
    if (boldInteresting && _labels.intersect(_interesting)) markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Issue &&
    runtimeType == other.runtimeType &&
    _id == other._id;

  @override 
  int get hashCode => _id.hashCode;

  static final jqueryResponse = 
  r'''
  {
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
      pageInfo {
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
  String _body;
  get body => _body;
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

  PullRequest(this._title, 
    this._id,
    this._number,
    this._state,
    this._author,
    this._body,
    this._labels,
    this._url,
    this._merged,
    this._createdAt,
    this._mergedAt,
    this._lastEditAt,
    this._updatedAt,
    this._closedAt,
    this._repository,
  );
   
  // Passed a node containing an issue, return the issue
  static PullRequest fromGraphQL(dynamic node) {
    return PullRequest(node['title'],
      node['id'],
      node['number'],
      node['state'],
      node['author'] == null ? null : Actor.fromGraphQL(node['author']),
      node['body'],
      node['labels'] == null ? null : Labels.fromGraphQL(node['labels']),
      node['url'],
      node['merged'],
      node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
      node['mergedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['lastEditedAt'] == null ? null : DateTime.parse(node['lastEditedAt']),
      node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
      node['repository'] == null ? null : Repository.fromGraphQL(node['repository']));
  }

  String summary({bool linebreakAfter = false, bool boldInteresting = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url}) ${this.title} ${labelsSummary}';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is PullRequest &&
    runtimeType == other.runtimeType &&
    _id == other._id;

  @override 
  int get hashCode => _id.hashCode;

  static final jqueryResponse = 
  r'''
  {
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
    merged,
    createdAt,
    lastEditedAt,
    updatedAt,
    closedAt,
    repository {
      nameWithOwner
    },
  }

  ''';
}