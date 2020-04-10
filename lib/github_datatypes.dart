import 'dart:collection';
import 'dart:io';


class Label {
  String _label;
  get label => _label;
  Label(this._label);
  static Label fromGraphQL(dynamic node) {
    return Label(node['name']);
  }
}

class Labels {
  Set<Label> _labels;
  get labels => _labels;
  void append(l) => _labels.add(l);
  void contains(l) => _labels.contains(l);
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

  Labels(this._labels);
  static Labels fromGraphQL(dynamic node) {
    var result = Labels(Set<Label>());
    for (dynamic n in node['edges']) {
      result.append(Label(n['node']));
    }
    return result;
  }
}

class Timeline {


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
}

class Actor {
  String _login;
  get login => _login;
  String _url;
  get url => _url;

  Actor(this._login, this._url);
  static Actor fromGraphQL(dynamic node) {
    return Actor(node['login'],
    node['url']);
  }
}

class Issue {
  String _title;
  get title => _title;
  String _id;
  get id => _id;
  int _number;
  get number => _number;
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
  List<Timeline> _timeline;
  get timeline => _timeline;

  Issue(this._title, 
    this._id,
    this._number,
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
      Actor.fromGraphQL(node['author']),
      node['body'],
      Labels.fromGraphQL(node['labels']),
      node['url'],
      DateTime.parse(node['createdAt']),
      DateTime.parse(node['closedAt']),
      DateTime.parse(node['lastEditAt']),
      DateTime.parse(node['updatedAt']),
      Repository(node['repository']),
      null);
  }

  List<Label> _interesting = [
        Label('prod: API break'),
        Label('severe: API break'),
        Label('severe: new feature'),
        Label('severe: performance'),
    ];

  String summary({bool boldInteresting = true, bool linebreakAfter = false}) {
    var labelsSummary = _labels.summary();
    var markdown = '[${this.number}]($this.url}) ${this.title} ${labelsSummary}';
    if (boldInteresting && _labels.intersect(_interesting)) markdown = '**' + markdown + '**';
    if (linebreakAfter) markdown = markdown + '\n';
    return markdown;
  }

}