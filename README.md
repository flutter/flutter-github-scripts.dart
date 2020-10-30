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
`P0` issues, `P0` issues opened in the period from
`from-date` until `to-date`, and `P0` issues closed in the
period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

## bin/performance_report.dart

Usage: `pub run bin/performance_report.dart [-f from-date] [-t to-date]`'

Returns a Markdown document consisting of the number of open
`severe: performance` issues, `severe: performance` issues opened in the 
period from `from-date` until `to-date`, and `severe: performance` issues 
closed in the period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

## bin/regression_report.dart

Usage: `pub run bin/regression_report.dart [-f from-date] [-t to-date]`'

Returns a Markdown document consisting of the number of open
`severe: regression` issues, `severe: regression` issues opened in the 
period from `from-date` until `to-date`, and `severe: regression` issues 
closed in the period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

## bin/open-issue-count-by-week.dart

Usage: `pub run bin/open-issue-count-by-week.dart [-f from-date] [-t to-date]`'

Returns a TSV document consisting of the number of issues opened each  
week from `from-date` until `to-date`.

Weeks end on Saturday.

If not specified, the report spans the previous week.

## bin/issue.dart

Usage: `pub run bin/issue.dart [-tsv] issue-number`

Returns a summary of the issue in Markdown or TSV format.

## bin/pr.dart

Usage: `pub run bin/pr.dart [-tsv] pr-number`

Returns a summary of the pull request in Markdown or TSV format.

## bin/prs.dart

Usage: `pub run bin/prs.dart [-tsv] [--label label] [--merged from-date to-date] [--closed from-date to-date]`

By default, returns a summary of the open pull requests in the Flutter repositories in Markdown format.
When passed `--closed` and two dates in ISO 8601 format, shows the range
of PRs closed between those two dates inclusive.
When passed `--merged` and two dates in ISO 8601 format, shows the range
of PRs merged between those two dates inclusive.
`--merged` and `--closed` are mutually exclusive.
When passed `--skipAutorollers`, skips autoroller PRs.

## bin/issues.dart

Usage: `pub run bin/issues.dart [-tsv] [--label label] [--closed from-date to-date]`

By default, returns a summary of the open issues in Markdown format.
When passed --closed and two dates in ISO 8601 format, shows the range
of issues closed between those two dates inclusive.

## bin/clusters.dart

Usage: `pub run bin/clusters.dart arguments`

Returns Markdown containing clusters of issues or PRs by label, assignee, or author according to
the arguments:

- Pass `prs` to cluster pull requests, or `issues` to cluster issues.

- Pass `labels` to cluster by labels, or `authors` to cluster by authors.

- Pass `closed` to cluster on closed items; otherwise cluster open issues or prs.
  If you pass `closed`, you must also pass the ISO dates beginning and ending the period you're interested in.

- Pass `merged` to cluster on merged items; otherwise cluster open issues or prs.
  If you pass `merged`, you must also pass the ISO dates beginning and ending the period you're interested in.

- Pass `alphabetize` to sort clusters alphabetically instead of largest-to-smallest.

- Pass `customers-only` when clustering issues by label to show only those issues with customer labels. 
When passing `customers-only`, you can pass `-ranking` to include a ranked list of other labels for each customer
at the end of the report.

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

## bin/issues-milestones.dart

Usage: `pub run bin/issues-milestones.dart'

Generates a list of unmilestoned owned issues, unowned milestoned issues, and
some statistics about how many issues are owned by each contributor listed in the
CSV `org-reports.csv`. The CSV is a file consisting of records with two
comma-delineated fields, the first being GitHub account, the second
being 'Y' if the contributor should be included in the statistics, or
'N' otherwise.

## bin/notable-contributors.dart

Usage: `pub run bin/notable-contributors.dart [--all-contributors] [--merged from-date to-date] [--closed from-date to-date]`

Generates a list of non-Googler-submitted PRs (open/closed/merged) in the date range clustered by contributor.

If `--all-contributors` is specified, includes all, not just non-Google, contributors.

Relies on a file `go_flutter_org_members.csv` in the root directory consisting of a
CSV of all organization members, with the following columns:

```
GitHub Login,Discord username (if different),Name,Company,"When Added (original data gave GitHub join date, not Flutter add date)",Reason for Adding,Additional notes,Include in reports
```

Google employees may contact KF6GPE for a current snapshot of this list.

## bin/who-is-doing-what.dart

Usage: `pub run bin/who-is-doing-what.dart [--list --markdown]

Generates a list of pending issues owned by core Flutter team members organized by the milestone
they fall in, and sorted by priority within that milestone.

By default, the output is HTML and relies on the style sheet
`who-is-doing-what.css` in the current directory. You can get
ouput as Markdown by passing `--markdown`, or as a straight
list by passing `--markdown --list` (HTML output of the list
version is not presently supported.

Relies on a file `go_flutter_org_members.csv` in the root directory consisting of a
CSV of all organization members, with the following columns:

```
GitHub Login,Discord username (if different),Name,Company,"When Added (original data gave GitHub join date, not Flutter add date)",Reason for Adding,Additional notes,Include in reports
```

The report includes those logins for which the `Include in reports` field value is `Y`.

Google employees may contact KF6GPE for a current snapshot of this list.

## bin/punted.dart

Usage: `pub run bin/punted.dart [--date-range from-date to-date] [--include-milestones] [--tsv-output]

Generates a list of issues punted from at least one milestone.

Dates are in ISO 8601 format.

If `--include-milestones` is specified, the punt report is prefaced by a list of the punted issues sorted by milestone.

## bin/regressions.dart

Usage: `pub run bin/regressions.dart [--tsv] [--between from-date to-date]`

Generates a list of regressions found in all releases (we started tracking after 1.11).

Dates are in ISO 8601 format.

## bin/reaction_count.dart

Usage: `pub run bin/reaction_count.dart issue`

Indicates the total number of positive, negative, and neutral reactions across the issue
and all comments.

## bin/top_reactions.dart

Usage: `pub run bin/top_reactions.dart'

Dumps all open issues and counts of positive, negative, and neutral reactions in
TSV format. For import to analyze in Google Sheets.
