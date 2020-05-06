This repository contains scripts written in Dart to report on various
aspects of code health within the [Flutter](https://flutter.dev)  
[repository](https://github.com/flutter).

They're probably not terribly useful if you're not a Flutter 
contributor, but you might find some snippets here that
show you how to access Github using either GraphQL or the
REST API.

## Setup
You must have an environment variable `GITHUB_TOKEN` set with a valid GitHub token 
for any of these scripts to work.

## bin/prs_landed_weekly.dart

Usage: `pub run bin/prs_landed_weekly.dart [-f from-date] [-t to-date]`

Returns a CSV of the number of PRs merged to all repositories in
the [Flutter](https://github.com/flutter) repository each week
from `from-date` until `to-date`.

If not specified, the report spans the period from 2019-11-01 until
the current date. (Weeks thus end on Fridays, as 2019-11-01 was a 
Friday).

## bin/today_report.dart

Usage: `pub run bin/today_report.dart [-f from-date] [-t to-date]`'

Returns a Markdown document consisting of the number of open 
`TODAY` issues, `TODAY` issues opened in the period from
`from-date` until `to-date`, and `TODAY` issues closed in the
period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).


## bin/issue.dart
Usage: `pub run bin/issue.dart issue-number`

Returns a summary of the issue in Markdown format.

## bin/pr.dart
Usage: `pub run bin/pr.dart pr-number`

Returns a summary of the pull request in Markdown format.

## bin/prs.dart
Usage: `pub run bin/prs.dart`

By default, returns a summary of the open pull requests in Markdown format.
When passed --closed and two dates in ISO 8601 format, shows the range
of PRs closed between those two dates inclusive.

