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

## Scripts
This repository has the following scripts.

### run_release_report.sh

Usage: `run_release_report.sh [to-date]`
Runs a release report from Flutter's 1.20 stable release through the given date.

Creates the files notable-contributors, prs_merged_by_label, prs_merged, 
issues_closed in Markdown, DOCX, and HTML.

#### Detailed Instructions

##### Dependencies
You'll need to have `pandoc` installed. See [here](https://pandoc.org/installing.html) for an installer. The `run-release-report.sh` script uses `pandoc` under the hood to convert the generated Markdown to other formats. If you don't have it installed, the script will fail, but you'll have markdown files that you can inspect with a program like `emacs` or `vim`.

Under the hood, these scripts ralso ely on the following Dart programs in this repository:

*   `bin/notable-contributors.dart`
*   `bin/clusters.dart`
*   `bin/prs.dart`
*   `bin/issues.dart`

You can also run any of these Dart applications standalone; instructions are below, 
or run a script with the `--help` argument.
##### Process to get the release report

1. For `run-release-reports.sh` to work, you need to have access to a list of organization members. This list is only available to Googlers because it contains PII; for information as to how to create this list, see [go/flutter-release-notes-tooling](go/flutter-release-notes-tooling), available on the Google intranet. You'll follow the instructions there, and create a file called `go_flutter_org_members.csv`. *This file should not be committed to Github, as it has PII.*
2. Obtain the commit dates you want which span the release of interest. Typically this is the date for the last tag of interest to the current tag of interest, written in ISO-8601 format (e.g., `2021-05-14T07:22:00-0700`). For example, Flutter 2.2 was tagged on `2021-05-14T07:22:00-0700`; the latest release of Flutter 2.3 (Flutter 2.3.0-24.1.pre was tagged on `2101-06-25T09:24:00-0700`. You can find this information at https://github.com/flutter/flutter/releases. To get a date for something that says something like “7 days ago”, hover over the date and wait about 5 seconds; Github will show the precise date and time of the tag.
3. Run `run-release-reports.sh` in the `flutter-github-scripts.dart` directory. You will need to use the dates you obtained in (3). _By default, the script runs from Flutter 2.2 through the current date and time_. To change this, you can edit the script and update lines 2 & 4. For sanity’s sake, _keep the comment and the date in sync_. For example, to run the report from Flutter 2.2 through Flutter 2.3 beta, use the command
`./run-release-reports.sh 2021-06-25T09:24:00-0700`
5. Go get a cup of coffee. It takes a while. The script will print status messages along the way. For a three-month release window, expect it to take ~45 minutes.

##### Files Generated

The script generates the following files:
*   `all-contributors-committers.[docx|html|md]` - All committers within the date range you specify. Data includes the counts of commits from each contributor as well as the individual commits.
*   `all-contributors-reviewers.[docx|html|md]` - All reviewers within the date range you specify. Data includes the counts of commits from each contributor as well as the individual commits.
*   `notable-contributors-committers.[docx|html|md]` - All unpaid committers within the date range you specify. Data includes the counts of commits from each contributor as well as the individual commits. _For this to be accurate, `go_flutter_org_members.csv` must be up to date. See (2), above._
*   `notable-contributors-reviewers.[docx|html|md]` - All unpaid reviewers within the date range you specify. Data includes the counts of reviews from each contributor as well as the individual reviews. _For this to be accurate, `go_flutter_org_members.csv` must be up to date. See (2), above._
*   `prs_merged_by_label.[docx|html|md]` - Pull requests committed in the date range, clustered by label, from largest to smallest by label.
*   `prs_merged.[docx|html|md]` - All pull requests merged in the date range, sorted by pull request number.
*   `issues_closed.[docx|html|md]` All issues closed in the date range, sorted by the issue number.

If you're doing this as part of a real release, you should save these results. Googlers can save these files For housekeeping; these should be copied to a new release directory on [Flutter’s shared drive](https://drive.google.com/corp/drive/u/0/folders/1Z6ppzZPsyfXJD1Zf6jd-2pUGRh66D9QU?resourcekey=0-x48WXccrJ3cKDRyT0P1b7Q). This link is only available to Googlers.

The script generates output in DOCX, Markdown and HTML formats. You can immediately import the `.docx` files into Google Drive for easy viewing, copying, and pasting with formatting. 

Some files, notably `prs_merged_by_label` and `prs_merged`, may require light editing to get them in the format required for the PR to the web site. See an existing release notes doc, like `website/src/docs/development/tools/sdk/release-notes/release-notes-2.2.0.md` for an example.


##### Notes

As of Dart 2.14, there’s an issue with a dependency of a dependency (the package `uuid`) that has yet to be properly migrated. KF6GPE hasn’t had time to fix this, and has instead chosen to pin the Dart version in `pubspec.yaml` to Dart 2.13.4. This is the version of Dart shipping with Flutter 2.2, so for the next stable release, you should be able to use that version of Dart. This and the dependency scripts may not work for you after that unless you pin the Dart version.


The scripts occasionally time out when Github is being cranky, and you’ll see errors. Don’t panic; just go for a walk and re-run the script.


### bin/prs_landed_weekly.dart

Usage: `pub run bin/prs_landed_weekly.dart [-f from-date] [-t to-date]`

Returns a CSV of the number of PRs merged to all repositories in
the [Flutter](https://github.com/flutter) repository each week
from `from-date` until `to-date`.

If not specified, the report spans the period from 2019-11-01 until
the current date. (Weeks thus end on Fridays, as 2019-11-01 was a
Friday).

### bin/today_report.dart

Usage: `pub run bin/today_report.dart [-f from-date] [-t to-date]`

Returns a Markdown document consisting of the number of open
`P0` issues, `P0` issues opened in the period from
`from-date` until `to-date`, and `P0` issues closed in the
period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

### bin/performance_report.dart

Usage: `pub run bin/performance_report.dart [-f from-date] [-t to-date]`

Returns a Markdown document consisting of the number of open
`severe: performance` issues, `severe: performance` issues opened in the 
period from `from-date` until `to-date`, and `severe: performance` issues 
closed in the period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

### bin/regression_report.dart

Usage: `pub run bin/regression_report.dart [-f from-date] [-t to-date]`

Returns a Markdown document consisting of the number of open
`severe: regression` issues, `severe: regression` issues opened in the 
period from `from-date` until `to-date`, and `severe: regression` issues 
closed in the period from `from-date` until `to-date`.

If not specified, the report spans the previous week.

Markdown output includes a preamble suitable for emailing
to the team when the Markdown is run through
[pandoc](https://pandoc.org/).

### bin/open-issue-count-by-week.dart

Usage: `pub run bin/open-issue-count-by-week.dart [-f from-date] [-t to-date]`

Returns a TSV document consisting of the number of issues opened each  
week from `from-date` until `to-date`.

Weeks end on Saturday.

If not specified, the report spans the previous week.

### bin/issue.dart

Usage: `pub run bin/issue.dart [--tsv] issue-number`

Returns a summary of the issue in Markdown or TSV format.

### bin/pr.dart

Usage: `pub run bin/pr.dart [--tsv] pr-number`

Returns a summary of the pull request in Markdown or TSV format.

### bin/prs.dart

Usage: `pub run bin/prs.dart [--tsv] [--label label] [--merged from-date to-date] [--closed from-date to-date]`

By default, returns a summary of the open pull requests in the Flutter repositories in Markdown format.
When passed `--closed` and two dates in ISO 8601 format, shows the range
of PRs closed between those two dates inclusive.
When passed `--merged` and two dates in ISO 8601 format, shows the range
of PRs merged between those two dates inclusive.
`--merged` and `--closed` are mutually exclusive.
When passed `--skipAutorollers`, skips autoroller PRs.

### bin/issues.dart

Usage: `pub run bin/issues.dart [--tsv] [--label label] [--closed from-date to-date]`

By default, returns a summary of the open issues in Markdown format.
When passed --closed and two dates in ISO 8601 format, shows the range
of issues closed between those two dates inclusive.

### bin/clusters.dart

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

- Pass `-ranking` to include a ranked list of other labels for each label
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

### bin/notable-contributors.dart

Usage: `pub run bin/notable-contributors.dart [--all-contributors] [--merged from-date to-date] [--closed from-date to-date]`

Generates a list of non-Googler-submitted PRs (open/closed/merged) in the date range clustered by contributor.

If `--all-contributors` is specified, includes all, not just non-Google, contributors.

Relies on a file `go_flutter_org_members.csv` in the root directory consisting of a
CSV of all organization members, with the following columns:

```
GitHub Login,Discord username (if different),Name,Company,"When Added (original data gave GitHub join date, not Flutter add date)",Reason for Adding,Additional notes,Include in reports
```

Google employees may contact KF6GPE for a current snapshot of this list.

### bin/who-is-doing-what.dart

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

### bin/regressions.dart

Usage: `pub run bin/regressions.dart [--tsv] [--between from-date to-date]`

Generates a list of regressions found in all releases (we started tracking after 1.11).

Dates are in ISO 8601 format.

### bin/reaction_count.dart

Usage: `pub run bin/reaction_count.dart issue`

Indicates the total number of positive, negative, and neutral reactions across the issue
and all comments.

### bin/top_reactions.dart

Usage: `pub run bin/top_reactions.dart [-only-unprioritized]`

Dumps all open issues and counts of positive, negative, and neutral reactions in
TSV format. For import to analyze in Google Sheets.

If only-unprioritize is passed, only show unprioritized issues.

### enumerate_team_members.dart
Usage: `dart bin/enumerate_team_members.dart [always-include-team] organization-login`
Dumps a TSV list of all teams in the indicated organization, with the members of each team.

### search.dart
Usage: `dart bin/search [--tsv] github query`
Returns the first 1,000 results of the given github query in either TSV or markdown format.

### priority_over_time.dart
Usage `dart bin/priority_over_time.dart [--queries] [--customers] [--summarize] [--delta <days> --from date --to date`

Returns a summary of open and closed P0s, P1s, and P2s weekly over the given span.
If `--summaries` is passed, reports in TSV; otherwise markdown.
If `--queries` is passed, shows each search term used for the open and closed queries.
if `--customers`is passed, shows only issues that also have at least one customer label.
If `--delta` is provided with a numeric argument, reports the counts for the periods in delta days; otherwise 7 days is assumed.

### enumerate_cherrypicks
Usage: `dart bin/enumerate_cherrypicks [--summary] [--formatted] --release x.y`

Lists pending cherrypicks in the Flutter and Dart repositories for the release _x.y_.

If [--summary] is provided, shows the TSV summaries for input into the hotfix review sheet.
If [--formatted] is provided, shows the list of hotfixes in HTML for import into a release plan.

If neither is provided, both are shown.

### flutterfire_closed_over_time.dart
Usage `dart bin/flutterfire_closed_over_time.dart [--queries] [--customers] [--summarize] [--delta <days> --from date --to date`

Returns a summary of open and closed high priority issues weekly over the given span for firebaseextended/flutterfire issues.
If `--summaries` is passed, reports in TSV; otherwise markdown.
If `--queries` is passed, shows each search term used for the open and closed queries.
if `--customers`is passed, shows only issues that also have at least one customer label.
If `--delta` is provided with a numeric argument, reports the counts for the periods in delta days; otherwise 7 days is assumed.

### flutterfire_all_closed_over_time.dart
Usage `dart bin/flutterfire_all_closed_over_time.dart [--queries] [--customers]  [--delta <days> --from date --to date`

Returns a TSV summary of open and closed issues weekly over the given span for firebaseextended/flutterfire issues.
If `--summaries` is passed, reports in TSV; otherwise markdown.
If `--queries` is passed, shows each search term used for the open and closed queries.
if `--customers`is passed, shows only issues that also have at least one customer label.
If `--delta` is provided with a numeric argument, reports the counts for the periods in delta days; otherwise 7 days is assumed.