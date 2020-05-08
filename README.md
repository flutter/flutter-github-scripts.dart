This repository contains scripts written in Dart to report on various
aspects of code health within the 
[Flutter](https://flutter.dev) [repository](https://github.com/flutter).

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

## bin/clusters.dart
Usage: `pub run bin/clusters.dart arguments`

Returns a cluster of issues or PRs by either label or author according to
the arguments:

  *  Pass `prs` to cluster pull requests, or `issues` to cluster issues.

  *  Pass `labels` to cluster by labels, or `authors` to cluster by authors.

  *  Pass `closed` to cluster on closed items; otherwise cluster open issues or prs. 
     If you pass `closed`, you must also pass the ISO dates beginning and ending the period you're interested in.

  *  Pass `alphabetize` to sort clusters alphabetically instead of largest-to-smallest.

  *  Pass `customers-only` when clustering issues by label to show only those issues with customer labels.

Examples:
```
pub run bin/clusters.dart --issues --labels --customers-only 
```
Shows all open issues with customer labels, sorted in decreasing order of cluster size.

```
pub run bin/clusters.dart --issues --labels --customers-only --alphabetize
```
Shows all open issues with customer labels, sorted by the customer label.

```
pub run bin/clusters.dart --issues --labels --closed 2020-01-01 2020-05-01
```
Shows all closed issues between January 1 2020 and May 1 2020.

```
pub run bin/clusters.dart --prs --authors 
```
Shows all open PRs by author, in decreasing order of number of open PRs per author.

```
pub run bin/clusters.dart --prs --authors 
```
Shows all open PRs by author, in alphabetical order.


```
pub run bin/clusters.dart --prs --authors --closed 2020-05-01 2020-05-03
```
Shows all authors closing PRs between May 1 2020 and May 3 2020.


