import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults? _results;
  String get member => _results!.rest[0];
  int? get exitCode => _results == null
      ? -1
      : _results!['help']
          ? 0
          : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage');
    try {
      _results = _parser.parse(args);
      if (_results!['help']) _printUsage();
      if (_results!.rest.length != 1) throw ('no member name!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub run member.dart googler_or_github_handle');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode!);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);
  var isMember = false;
  Actor? user = await github.user(opts.member);
  if (user == null) {
    print('${opts.member} is not a Github user.');
    return;
  }
  await for (var org in user.organizationsStream) {
    print(org.name);
    if (org.name == 'Flutter') {
      isMember = true;
      break;
    }
  }
  String isIsNot = isMember ? 'is' : 'is not';
  print('${opts.member} ${isIsNot} a Flutter org member');
}
