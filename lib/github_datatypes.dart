import 'dart:collection';
import 'dart:math';
import 'package:quiver/core.dart' show hash2;


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
    return PageInfo(node['startCursor'], node['endCursor'], node['hasNextPage']);
  }

  String toString() {
    return 'start: ${startCursor}, end: ${endCursor}, more? ${hasNextPage}';
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is PageInfo &&
    runtimeType == other.runtimeType &&
    _startCursor == other._startCursor &&
    _endCursor == other._endCursor &&
    _hasNextPage == other._hasNextPage;

  @override 
  int get hashCode =>  hash2(
      hash2(_startCursor.hashCode, _endCursor.hashCode),
        _hasNextPage.hashCode);


  static final graphQLResponse = 
  '''
  {
    startCursor, hasNextPage, endCursor
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
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Label &&
    runtimeType == other.runtimeType &&
    _label == other._label;

  @override 
  int get hashCode => _label.hashCode;

  static var graphQLResponse = 
  '''
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
    for(var l in list)
      if (_labels.contains(l)) return true;
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
    final priorities = { 'P0', 'P1', 'P2', 'P3', 'P4', 'P5', 'P6'};
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

  TimelineItem(this._type, this._title, this._number, this._actor, this._createdAt);

  static TimelineItem fromGraphQL(dynamic node) {
    String title  = null;
    int number = null;
    Actor actor = null;

    if (node['__typename'] == 'MilestonedEvent' || node['__typename'] == 'DemilestonedEvent') {
      title = node['milestoneTitle'];
      actor = Actor.fromGraphQL(node['actor']);
    } else if (node['__typename'] == 'CrossReferencedEvent') {
      title = node['source']['title'];
      number = node['source']['number'];
    } else if (node['__typename'] == 'AssignedEvent' || node['__typename'] == 'UnassignedEvent') {
      actor = node['assignee'] != null ? Actor.fromGraphQL(node['assignee']) : null;
    }

    return TimelineItem(
      node['__typename'], 
      title,
      number,
      actor,
      node['createdAt'] == null ? null : DateTime.parse(node['createdAt']));
  }

  String toString() {
    var result = '${_type} (' + _createdAt.toIso8601String() + ')';
    result = '${result}' + (_actor != null ? ' by ${actor.login}' : '');
    
    if (type == 'CrossReferencedEvent') {
      result = '${result} [${_number}](https://github.com/flutter/flutter/issues/${_number}) ${_title}';
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
    _timeline.forEach((entry) =>
      markdown = '${markdown}${entry}\n\n'
    );
    return markdown.length > 2 ? markdown.substring(0, markdown.length-2) : markdown;
  }
  String toString() {
    return summary();
  }
  String toCsv() {
    String csv = '';
    _timeline.forEach((entry) =>
      csv = '${csv}${entry},'
    );
    return csv.length > 1 ? csv.substring(0, csv.length-1) : csv;
  }
  
  TimelineItem operator[](int index) => _timeline[index];

  Timeline(this._timeline);
  static Timeline fromGraphQL(dynamic node) {
    assert(node['pageInfo']['hasNextPage'] == false);
    var result = Timeline(List<TimelineItem>());
    for (dynamic n in node['nodes']) {
      if (n == null) continue;
      result.append(TimelineItem.fromGraphQL(n));
    }
    return result;
  }

  List<String> milestoneTimeline() {
    var result = List<String>();
    _timeline.forEach((item) { 
      if (item.type == 'MilestonedEvent' || item.type == 'DemilestonedEvent') {
        result.add(item.title);
      }
    });
    return result;
  }

  static var graphQLResponse = 
  '''
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
  get closed => closed;
  DateTime _createdAt;
  get createdAt => _createdAt;
  DateTime _closedAt;
  get closedAt => _closedAt;
  DateTime _dueOn;
  get dueOn => _dueOn;

  Milestone(this._title,
    this._id,
    this._number,
    this._url,
    this._closed,
    this._createdAt,
    this._closedAt,
    this._dueOn);

  static Milestone fromGraphQL(dynamic node) {
    return Milestone(
      node['title'],
      node['id'],
      node['number'],
      node['url'],
      node['closed'],
      node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
      node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
      node['dueOn'] == null ? null : DateTime.parse(node['dueOn'])
    );
  }

  String toString() {
    return 'due on ${dueOn} (${title})';
  }
  String toCsv() {
    return '${title},${dueOn}';
  }

  static final graphQLResponse = 
  '''
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

  String toString() => this._login;
  String toCsv() => this._login;

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Actor &&
    runtimeType == other.runtimeType &&
    _login == other._login;

  @override 
  int get hashCode => _login.hashCode;
  static var graphQLResponse = 
  '''
  {
    login,
    resourcePath,
    url
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

  Issue(this._title, 
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
    this._timeline
  );
   
  // Passed a node containing an issue, return the issue
  static Issue fromGraphQL(dynamic node) {
    List<Actor> assignees = null;
    if (node['assignees']['edges'] != null && node['assignees']['edges'].length != 0) {
      assignees = List<Actor>();
      for(var node in node['assignees']['edges']) {
        assignees.add(Actor.fromGraphQL(node['node']));
      }
    }
    return Issue(node['title'],
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
      node['lastEditedAt'] == null ? null : DateTime.parse(node['lastEditedAt']),
      node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['repository'] == null ? null : Repository.fromGraphQL(node['repository']),
      node['milestone'] == null ? null : Milestone.fromGraphQL(node['milestone']),
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
    var markdown = '[${this.number}](${this.url})';
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (boldInteresting && _labels.intersect(_interesting)) markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  String verbose({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url})';
    if (_assignees == null || _assignees.length == 0) markdown = '${markdown} > UNASSIGNED'; else
    {
      markdown = '${markdown} > (';
      _assignees.forEach((assignee) => markdown = '${markdown}${assignee.login}, ');
      markdown = markdown.substring(0, markdown.length-2);
      markdown = '${markdown})';
    }
    if (_milestone == null) markdown = '${markdown} with no milestone'; 
    else markdown = '${markdown} due on ${_milestone.dueOn} (${_milestone.title})';    
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (boldInteresting && _labels.intersect(_interesting)) markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  static get tsvHeader => 
    'Number\tTitle\tURL\tPriority\tAuthor\tCreated At\tAssignees\tMilestone\tDue On\tClosed At';

  // Top level entities like Issue and PR must TSV, because their fields CSV,
  // and Google Sheets only takes mixed CSV/TSV records with TSV being the containing
  // record format.
  String toTsv() {
    String milestoneHistory = '';
    if (timeline != null) timeline.milestoneTimeline().forEach((milestone) =>
      milestoneHistory = '${milestoneHistory},${milestone}'
    );
    if (milestoneHistory.length > 0) milestoneHistory = milestoneHistory.substring(1);
    if (milestoneHistory.length == 0) milestoneHistory = _milestone ?? '';

    String tsv = '';
    tsv = '${tsv}${_number}';
    tsv = '${tsv}\t${_title}';
    tsv = '${tsv}\t${_url}';
    tsv = '${tsv}\t${_labels.priority()}';
    tsv = '${tsv}\t' + (_author == null ? '' : _author.toCsv());
    tsv = '${tsv}\t${createdAt}';
    if(_assignees != null && _assignees.length > 0) {
      tsv = '${tsv}\t';
      assignees.forEach((assignee) => tsv = '${tsv}${assignee.login},');
      tsv = tsv.substring(0, tsv.length-1);
    } else {
      tsv = '${tsv}\t';
    }
    tsv = _milestone == null ? '${tsv}\t' : '${tsv}\t${milestoneHistory}\t${_milestone.dueOn}';
    tsv = _closedAt == null ? '${tsv}\t': '${tsv}\t${_closedAt}';

    return tsv;
  }

  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is Issue &&
    runtimeType == other.runtimeType &&
    _id == other._id;

  @override 
  int get hashCode => _id.hashCode;

  static final graphQLResponse = 
  '''
  {
    title,
    id,
    number,
    state,
    author ${Actor.graphQLResponse},
    assignees(after: null, last: 100) {
      edges {
        node ${Actor.graphQLResponse}
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

  PullRequest(this._title, 
    this._id,
    this._number,
    this._state,
    this._author,
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
    this._timeline
  );
   
  // Passed a node containing an issue, return the issue
  static PullRequest fromGraphQL(dynamic node) {
    List<Actor> assignees = null;
    if (node['assignees']['edges'] != null && node['assignees']['edges'].length != 0) {
      assignees = List<Actor>();
      for(var node in node['assignees']['edges']) {
        assignees.add(Actor.fromGraphQL(node['node']));
      }
    }
    return PullRequest(node['title'],
      node['id'],
      node['number'],
      node['state'],
      node['author'] == null ? null : Actor.fromGraphQL(node['author']),
      assignees,
      node['body'],
      node['milestone'] == null ? null : Milestone.fromGraphQL(node['milestone']),
      node['labels'] == null ? null : Labels.fromGraphQL(node['labels']),
      node['url'],
      node['merged'],
      node['createdAt'] == null ? null : DateTime.parse(node['createdAt']),
      node['mergedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['lastEditedAt'] == null ? null : DateTime.parse(node['lastEditedAt']),
      node['updatedAt'] == null ? null : DateTime.parse(node['updatedAt']),
      node['closedAt'] == null ? null : DateTime.parse(node['closedAt']),
      node['repository'] == null ? null : Repository.fromGraphQL(node['repository']),
      node['timelineItems'] == null ? null : Timeline.fromGraphQL(node['timelineItems']));
  }

  String summary({bool linebreakAfter = false, bool boldInteresting = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url}) ${this.title} ${labelsSummary}';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  String verbose({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}](${this.url})';
    if (_assignees == null || _assignees.length == 0) markdown = '${markdown} > UNASSIGNED'; else
    {
      markdown = '${markdown} > (';
      _assignees.forEach((assignee) => markdown = '${markdown}${assignee.login}, ');
      markdown = markdown.substring(0, markdown.length-2);
      markdown = '${markdown})';
    }
    if (_milestone == null) markdown = '${markdown} with no milestone'; 
    else markdown = '${markdown} due on ${_milestone.dueOn} (${_milestone.title})';    
    markdown = '${markdown} ${this.title} ${labelsSummary}';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

  static get tsvHeader => 
    'Number\tTitle\tURL\tPriority\tAuthor\tCreated At\tMerged?\tAssignees\tMilestone\tDue On\tMerged At\tClosed At';

  // Top level entities like Issue and PR must TSV, because their fields CSV,
  // and Google Sheets only takes mixed CSV/TSV records with TSV being the containing
  // record format.
  String toTsv() {
    String milestoneHistory = '';
    if (timeline != null) timeline.milestoneTimeline().forEach((milestone) =>
      milestoneHistory = '${milestoneHistory},${milestone}'
    );
    if (milestoneHistory.length > 0) milestoneHistory = milestoneHistory.substring(1);
    if (milestoneHistory.length == 0) milestoneHistory = _milestone ?? '';

    String tsv = '';
    tsv = '${tsv}${_number}';
    tsv = '${tsv}\t${_title}';
    tsv = '${tsv}\t${_url}';
    tsv = '${tsv}\t${_labels.priority()}';
    tsv = '${tsv}\t${_author.toCsv()}';
    tsv = '${tsv}\t${createdAt}';
    tsv = '${tsv}\t' + (_merged ? 'Y' : 'N');
    if(_assignees != null && _assignees.length > 0) {
      tsv = '${tsv}\t';
      assignees.forEach((assignee) => tsv = '${tsv}${assignee.login},');
      tsv = tsv.substring(0, tsv.length-1);
    } else {
      tsv = '${tsv}\t';
    }
    tsv = _milestone == null ? '${tsv}\t' : '${tsv}\t${milestoneHistory}\t${_milestone.dueOn}';
    tsv = _mergedAt == null ? '${tsv}\t' : '${tsv}\t${_mergedAt}';
    tsv = _closedAt == null ? '${tsv}\t' : '${tsv}\t${_closedAt}';
    
    return tsv;
  }



  @override
  bool operator==(Object other) =>
    identical(this, other) ||
    other is PullRequest &&
    runtimeType == other.runtimeType &&
    _id == other._id;

  @override 
  int get hashCode => _id.hashCode;

  static final graphQLResponse = 
  '''
  {
    title,
    id,
    number,
    state,
    author ${Actor.graphQLResponse},
    assignees(after: null, last: 100) {
      edges {
        node ${Actor.graphQLResponse}
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
    repository {
      nameWithOwner
    },
  }

  ''';
}

enum ClusterType { byLabel, byAuthor, byAssignee, byMilestone }
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
  static final _noMilestoneKey = '__no milestone__';

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
    result[_unassignedKey] = List<dynamic>();

    for(var item in issuesOrPullRequests) {
      if( !(item is Issue) && !(item is PullRequest)) {
        throw('invalid type!');
      }
      if (item.assignees == null || item.assignees.length == 0) {
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

  static Cluster byMilestone(List<dynamic> issuesOrPullRequests) {
    var result = SplayTreeMap<String, dynamic>();
    result[_noMilestoneKey] = List<dynamic>(); 

    for(var item in issuesOrPullRequests) {
      if( !(item is Issue) && !(item is PullRequest)) {
        throw('invalid type!');
      }
      if (item.milestone == null) {
        result[_noMilestoneKey].add(item);
      } else  {
        if (!result.containsKey(item.milestone.title)) {
          result[item.milestone.title] = List<dynamic>();
        }
        result[item.milestone.title].add(item);
      }
    }

    return Cluster._internal(ClusterType.byMilestone, result);
  }

  String summary() {
    var result = 'Cluster of';
    switch(type) {
        case ClusterType.byAssignee: result = '${result} assignees'; break;
        case ClusterType.byAuthor: result = '${result} authors'; break;
        case ClusterType.byLabel: result = '${result} labels'; break;
        case ClusterType.byMilestone: result = '${result} milestones'; break;        
    }
    result = '${result} has ${this.clusters.keys.length} clusters';
    return result;
  }

  String toString() => summary();

  String toMarkdown({ClusterReportSort sortType, bool skipEmpty = true, showStatistics = false}) {
    var result = '';
    var m = mean(), s = stdev();



    if (clusters.keys.length == 0) {
      result = 'no items\n\n';
    }
    else {
      var kind = '';
      // Determine the type of this cluster
      for(var key in clusters.keys) {
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
      keys.sort((a,b) => sortType == ClusterReportSort.byCount ? 
        clusters[b].length - clusters[a].length : 
        a.compareTo(b));
      // Remove the unlabled item if it's empty
      if (clusters[_unlabeledKey] != null && clusters[_unlabeledKey].length == 0) keys.remove(_unlabeledKey);
      if (clusters[_unassignedKey] != null && clusters[_unassignedKey].length == 0) keys.remove(_unassignedKey);
      if (clusters[_noMilestoneKey] != null && clusters[_noMilestoneKey].length == 0) keys.remove(_noMilestoneKey);
      if (skipEmpty) {
        if (keys.contains(_unlabeledKey)) keys.remove(_unlabeledKey);
        if (keys.contains(_unassignedKey)) keys.remove(_unassignedKey);
      }
      // Dump all clusters
      for (var clusterKey in keys) {
        result = '${result}\n\n### ${clusterKey} - ${clusters[clusterKey].length} ${kind}';
        if(showStatistics) {
          var z = (clusters[clusterKey].length - m) / s;
          result = '${result}, z = ${z}';
        }

        for(var item in clusters[clusterKey]) {
          result = '${result}\n\n' + item.summary(linebreakAfter: true, boldInteresting: false);
        }
      }
    }
    return '${result}\n\n';
  }

  double mean() {
    double sum = 0.0;
    double l = 0.0;
    switch(type) {
      case ClusterType.byAuthor: l = (clusters.keys.contains(_unassignedKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byAssignee: l = (clusters.keys.contains(_unassignedKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byMilestone: l = (clusters.keys.contains(_noMilestoneKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byLabel: l = (clusters.keys.contains(_unlabeledKey) ? (clusters.keys.length - 1) : clusters.keys.length).toDouble(); break;
    }
    clusters.keys.forEach((key) => sum += clusters[key].length);
    return sum /l;
  }

  double stdev() {
    double m = mean();
    double sum = 0.0;
    double l = 0.0;
    switch(type) {
      case ClusterType.byAuthor: l = (clusters.keys.contains(_unassignedKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byAssignee: l = (clusters.keys.contains(_unassignedKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byMilestone: l = (clusters.keys.contains(_noMilestoneKey) ? clusters.keys.length - 1 : clusters.keys.length).toDouble(); break;
      case ClusterType.byLabel: l = (clusters.keys.contains(_unlabeledKey) ? (clusters.keys.length - 1) : clusters.keys.length).toDouble(); break;
    }
    clusters.keys.forEach((key) => sum += ((clusters[key].length - m)*(clusters[key].length - m)));

    double deviation = sum / l;

    return sqrt(deviation);
  }

  Cluster._internal(this._type, this._clusters);
}
