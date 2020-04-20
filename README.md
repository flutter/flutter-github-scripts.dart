This repository contains scripts written in Dart to report on various
aspects of code health within the [Flutter](https://flutter.dev)  
[repository](https://github.com/flutter).

They're probably not terribly useful if you're not a Flutter 
contributor, but you might find some snippets here that
show you how to access Github using either GraphQL or the
REST API.

## bin/prs_landed_weekly.dart

Usage: `pub run bin/prs_landed_weekly.dart [-f from-date] [-t to-date]`

Returns a CSV of the number of PRs merged to all repositories in
the [Flutter](https://github.com/flutter) repository each week
from `from-date` until `to-date`.


