
# flutter-1.22

FROM="2020-09-10T18:17:00";
TO=$1 

[ -z "$TO" ] && TO=` date --iso-8601=seconds`

echo "Running release reports from ${FROM} to ${TO}"

echo -n "Contributors..."
echo -n "authors..."
dart bin/notable-contributors.dart --authors --merged $FROM $TO > notable-contributors-committers.md
echo -n "reviewers..."
dart bin/notable-contributors.dart --reviewers --merged $FROM $TO > notable-contributors-reviewers.md
echo "done."
echo -n "Clusters..."
dart bin/clusters.dart --merged --labels --prs $FROM $TO > prs_merged_by_label.md
echo "done."
echo -n "PRs merged..."
dart bin/prs.dart --merged $FROM $TO > prs_merged.md
echo "done."
echo -n "Issues closed..."
dart bin/issues.dart --closed $FROM $TO > issues_closed.md
echo "done."

echo -n "Running pandoc..."
pandoc -o notable-contributors-commiters.html notable-contributors-committers.md
pandoc -o notable-contributors-commiters.docx notable-contributors-committers.md
pandoc -o notable-contributors-reviewers.html notable-contributors-reviewers.md
pandoc -o notable-contributors-reviewers.docx notable-contributors-reviewers.md
pandoc -o prs_merged_by_label.html prs_merged_by_label.md
pandoc -o prs_merged_by_label.docx prs_merged_by_label.md
pandoc -o prs_merged.html prs_merged.md
pandoc -o prs_merged.docx prs_merged.md
pandoc -o issues_closed.html issues_closed.md
pandoc -o issues_closed.docx issues_closed.md
echo "done."
