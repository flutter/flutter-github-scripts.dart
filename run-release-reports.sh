
# flutter-1.20

FROM="2020-09-10T18:17:00";
TO=$1 

[ -z "$TO" ] && TO=` date --iso-8601=seconds`

echo "Running release reports from ${FROM} to ${TO}"

echo -n "Contributors..."
dart bin/notable-contributors.dart $FROM $TO > notable-contributors.md
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
pandoc -o notable-contributors.html notable-contributors.md
pandoc -o notable-contributors.docx notable-contributors.md
pandoc -o prs_merged_by_label.html prs_merged_by_label.md
pandoc -o prs_merged_by_label.docx prs_merged_by_label.md
pandoc -o prs_merged.html prs_merged.md
pandoc -o prs_merged.docx prs_merged.md
pandoc -o issues_closed.html issues_closed.md
pandoc -o issues_closed.docx issues_closed.md
echo "done."
