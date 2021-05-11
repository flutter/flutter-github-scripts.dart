import 'package:test/test.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'dart:convert';

void main() {
  group('Labels', () {
    var json_Label = '{ "name": "t: hot reload" }';
    var json_Labels = '''
    {
      "edges": [
        {
          "node": {
            "name": "perf: speed"
          }
        },
        {
          "node": {
            "name": "severe: performance"
          }
        }
      ]
    }''';

    test('Label constructor', () {
      var l = Label('TODAY');
      expect(l.label, 'TODAY');
    });
    test('Label equality', () {
      var l1 = Label('TODAY');
      var l2 = Label('TODAY');
      var lnot = Label('NOT TODAY');
      expect(l1 == l1, true);
      expect(l1 == l2, true);
      expect(l1 == lnot, false);
    });
    test('Label from GraphQL', () {
      dynamic node = json.decode(json_Label);
      var l = Label.fromGraphQL(node);
      expect(l.label, 't: hot reload');
    });
    test('Labels from GraphQL', () {
      dynamic node = json.decode(json_Labels);
      var ls = Labels.fromGraphQL(node);
      expect(ls.contains(Label('perf: speed')), true);
      expect(ls.contains(Label('TODAY')), false);
      expect(ls.containsString('perf: speed'), true);
      expect(ls.containsString('TODAY'), false);
    });
    test('Labels summary', () {
      Labels l = Labels(Set<Label>());
      l.append(Label('TODAY'));
      l.append(Label('perf: speed'));
      expect(l.summary() == '(TODAY, perf: speed)', true);
    });
  });

  group('Repository', () {
    var json_Repository = '{ "nameWithOwner": "flutter/engine" }';

    test('Constructor', () {
      var r = Repository('flutter/engine');
      expect(r.organization == 'flutter', true);
      expect(r.repository == 'engine', true);
    });
    test('Equality', () {
      var r1 = Repository('flutter/engine');
      var r2 = Repository('flutter/engine');
      var rOther = Repository('flutter/nothing');
      expect(r1 == r1, true);
      expect(r1 == r2, true);
      expect(r1 == rOther, false);
    });
    test('Repository from GraphQL', () {
      var node = json.decode(json_Repository);
      var r = Repository.fromGraphQL(node);
      expect(r.organization == 'flutter', true);
      expect(r.repository == 'engine', true);
    });
  });

  group('Actor', () {
    var json_Actor = '''
      {
        "login": "kf6gpe",
        "resourcePath": "/kf6gpe",
        "url": "https://github.com/kf6gpe"
      }
    ''';
    test('Constructor', () {
      var a = Actor('kf6gpe', 'http://kf6gpe.org');
      expect(a.login == 'kf6gpe', true);
      expect(a.url == 'http://kf6gpe.org', true);
    });
    test('Actor Equality', () {
      var a1 = Actor('kf6gpe', 'http://kf6gpe.org');
      var a2 = Actor('kf6gpe', 'http://kf6gpe.org');
      var aOther = Actor('nobody', 'http://noplace.com');
      expect(a1 == a1, true);
      expect(a1 == a2, true);
      expect(a1 == aOther, false);
    });
    test('Actor from GraphQL', () {
      var node = json.decode(json_Actor);
      var a = Actor.fromGraphQL(node)!;
      expect(a.login == 'kf6gpe', true);
      expect(a.url == 'https://github.com/kf6gpe', true);
    });
  });

  group('Issue', () {
    var json_IssueNoTimeline = '''
      {
        "title": "smoke_catalina_hot_mode_dev_cycle__benchmark hotReloadMillisecondsToFrame & hotReloadMillisecondsToFrame above baseline",
        "id": "MDU6SXNzdWU1OTc5NjA3NTI=",
        "number": 54456,
        "author": {
          "login": "kf6gpe",
          "resourcePath": "/kf6gpe",
          "url": "https://github.com/kf6gpe"
        },
        "body": "After the fix to https://github.com/flutter/flutter/issues/54368 in https://github.com/flutter/flutter/pull/54374, these benchmarks remain slightly above the baseline. Should we re-baseline them?![Screen Shot 2020-04-10 at 8 56 11 AM](https://user-images.githubusercontent.com/1435716/79004222-27bf6c00-7b09-11ea-88ad-96c68f3be102.png) åcc @jonahwilliams ",
        "labels": {
          "edges": [{
              "node": {
                "name": "perf: speed"
              }
            },
            {
              "node": {
                "name": "severe: performance"
              }
            },
            {
              "node": {
                "name": "severe: regression"
              }
            },
            {
              "node": {
                "name": "t: hot reload"
              }
            },
            {
              "node": {
                "name": "tool"
              }
            },
            {
              "node": {
                "name": "⚠ TODAY"
              }
            }
          ]
        },
        "url": "https://github.com/flutter/flutter/issues/54456",
        "createdAt": "2020-04-10T15:55:57Z",
        "closedAt": null,
        "lastEditedAt": "2020-04-10T15:56:27Z",
        "updatedAt": "2020-04-10T15:56:27Z",
        "repository": {
          "nameWithOwner": "flutter/flutter"
        }
      }
    ''';

    var json_Issue_TimelineNoLabels = '''
    {
      "number": 55193,
      "title": "Cupertino widgets blurred on https://flutter.github.io/gallery/#/ ",
      "timelineItems": {
        "pageInfo": {
          "startCursor": "Y3Vyc29yOnYyOpPPAAABcZlZiNACqjEwMzAzNDY5MTA=",
          "hasNextPage": false,
          "endCursor": "Y3Vyc29yOnYyOpPPAAABcZlZiNACqjEwMzAzNDY5MTA="
        },
        "nodes": [
          {
            "__typename": "CrossReferencedEvent",
            "source": {
              "__typename": "PullRequest",
              "title": "Canvas regression",
              "number": 17738
            }
          }
        ]
      }
    }
    ''';

    var json_Issue_TimelineWithLabels = '''
    {
      "title": "[flutter_tools] roll_dev.dart",
      "id": "MDU6SXNzdWU1OTk4MjMyMDU=",
      "number": 54774,
      "author": {
        "login": "christopherfujino",
        "resourcePath": "/christopherfujino",
        "url": "https://github.com/christopherfujino"
      },
      "body": "The `roll_dev.dart` script is still publishing tags with the `x.y.z-dev.m.n` format, whereas it should be publishing using the new(er) format `x.y.z-m.n.pre`.",
      "labels": {
        "edges": [
          {
            "node": {
              "name": "tool"
            }
          },
          {
            "node": {
              "name": "⚠ TODAY"
            }
          }
        ]
      },
      "url": "https://github.com/flutter/flutter/issues/54774",
      "createdAt": "2020-04-14T19:59:40Z",
      "closedAt": null,
      "lastEditedAt": null,
      "updatedAt": "2020-04-16T20:11:37Z",
      "repository": {
        "nameWithOwner": "flutter/flutter"
      },
      "timelineItems": {
        "pageInfo": {
          "startCursor": "Y3Vyc29yOnYyOpPPAAABcX9c6oACqjEwMjk3ODE4MTc=",
          "hasNextPage": false,
          "endCursor": "Y3Vyc29yOnYyOpPPAAABcX9c6oACqjEwMjk3ODE4MTc="
        },
        "nodes": [
          {
            "__typename": "CrossReferencedEvent",
            "source": {
              "__typename": "PullRequest",
              "title": "[flutter_tools] Fix roll dev script, add tests",
              "number": 54783
            }
          }
        ]
      }
    }
    ''';

    var labels = [
      'perf: speed',
      'severe: performance',
      'severe: regression',
      't: hot reload',
      'tool',
      '⚠ TODAY'
    ];
    test('Issue fromGraphQL - no Timeline', () {
      dynamic node = json.decode(json_IssueNoTimeline);
      var i = Issue.fromGraphQL(node);
      expect(i.number == 54456, true);
      expect(i.id == 'MDU6SXNzdWU1OTc5NjA3NTI=', true);
      expect(
          i.title ==
              'smoke_catalina_hot_mode_dev_cycle__benchmark hotReloadMillisecondsToFrame & hotReloadMillisecondsToFrame above baseline',
          true);
      expect(i.author == Actor('kf6gpe', 'https://github.com/kf6gpe'), true);
      expect(
          i.body ==
              'After the fix to https://github.com/flutter/flutter/issues/54368 in https://github.com/flutter/flutter/pull/54374, these benchmarks remain slightly above the baseline. Should we re-baseline them?![Screen Shot 2020-04-10 at 8 56 11 AM](https://user-images.githubusercontent.com/1435716/79004222-27bf6c00-7b09-11ea-88ad-96c68f3be102.png) åcc @jonahwilliams ',
          true);
      expect(i.labels.length == 6, true);
      for (var l in labels) {
        expect(i.labels.containsString(l), true);
      }
      expect(i.url == 'https://github.com/flutter/flutter/issues/54456', true);
      expect(i.createdAt.toIso8601String() == '2020-04-10T15:55:57.000Z', true);
      expect(i.closedAt == null, true);
      expect(
          i.lastEditAt.toIso8601String() == '2020-04-10T15:56:27.000Z', true);
      expect(i.updatedAt.toIso8601String() == '2020-04-10T15:56:27.000Z', true);
    });
    test('Issue from GraphQL - Timeline & no labels', () {
      dynamic node = json.decode(json_Issue_TimelineNoLabels);
      var i = Issue.fromGraphQL(node);
      expect(i.number == 55193, true);
      expect(
          i.title ==
              'Cupertino widgets blurred on https://flutter.github.io/gallery/#/ ',
          true);
      expect(i.timeline.length == 1, true);
      expect(i.timeline[0].type == 'CrossReferencedEvent', true);
      expect(i.timeline[0].number == 17738, true);
      expect(i.timeline[0].title == 'Canvas regression', true);
    });
    test('Issue from GraphQL - Timeline with labels', () {
      dynamic node = json.decode(json_Issue_TimelineWithLabels);
      var i = Issue.fromGraphQL(node);
      expect(i.number == 54774, true);
      expect(
          i.author ==
              Actor(
                  'christopherfujino', 'https://github.com/christopherfujino'),
          true);
      expect(i.timeline.length == 1, true);
      expect(i.timeline[0].number == 54783, true);
      expect(i.labels.length == 2, true);
      expect(i.labels.containsString('tool'), true);
      expect(i.labels.containsString('⚠ TODAY'), true);
      expect(i.labels.containsString('nope'), false);
    });
  });
}
