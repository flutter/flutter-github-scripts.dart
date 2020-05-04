import 'package:graphql/client.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  int get number => int.parse(_results.rest[0]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results.rest.length != 1 ) throw('invalid issue number!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run issue.dart issue_number');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  final token = Platform.environment['GITHUB_TOKEN'];

  final github = Github(token);
  
  var issue = await github.issue(owner: 'flutter', name: 'flutter', number: opts.number);
  
  var open = List<Issue>();
  var openedThisPeriod = List<Issue>();
  var closedThisPeriod = List<Issue>();

  issues.forEach((issue) {
    if (issue.state == "OPEN") open.add(issue);
    if (issue.createdAt.compareTo(opts.from) >= 0 && issue.createdAt.compareTo(opts.to) <= 0) openedThisPeriod.add(issue);
    if (issue.state == "CLOSED" && issue.closedAt.compareTo(opts.from) >= 0 && issue.closedAt.compareTo(opts.to) <= 0) closedThisPeriod.add(issue);
  });
  
  var fromStamp = opts.from.toIso8601String().substring(0,10);
  var toStamp = opts.to.toIso8601String().substring(0,10);

  printHeader(opts);

  print('This shows the number of new, open, and closed `TODAY` issues over the period from');
  print('${fromStamp} to ${toStamp}.\n\n');

  print('### ${open.length} open `TODAY` issue(s)');
  open.forEach((issue) => print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print('### ${openedThisPeriod.length} `TODAY` issues opened between ${fromStamp} and ${toStamp}');
  openedThisPeriod.forEach((issue) => print(issue.summary(boldInteresting: false, linebreakAfter: true)));

  print('### ${closedThisPeriod.length} `TODAY` issues closed between ${fromStamp} and ${toStamp}');
  closedThisPeriod.forEach((issue) => print(issue.summary(boldInteresting: false, linebreakAfter: true)));

}
