# flutter-2.5
FROM="2021-04-07T12:24:00-0700"
TO="2021-08-04T18:59:00-0400"
OUT="f25"

echo "Running release reports from ${FROM} to ${TO}"

echo -n "Unpaid contributors..."
echo -n "authors..."
dart bin/notable-contributors.dart --authors --merged $FROM $TO > "$OUT/notable-contributors-committers.md"
echo -n "reviewers..."
dart bin/notable-contributors.dart --reviewers --merged $FROM $TO > "$OUT/notable-contributors-reviewers.md"
echo "done."
echo -n "All contributors..."
echo -n "authors..."
dart bin/notable-contributors.dart --authors --merged --all-contributors $FROM $TO > "$OUT/all-contributors-committers.md"
echo -n "reviewers..."
dart bin/notable-contributors.dart --reviewers --merged  --all-contributors $FROM $TO > "$OUT/all-contributors-reviewers.md"
echo "done."
echo -n "Clusters..."
dart bin/clusters.dart --merged --labels --prs $FROM $TO > "$OUT/prs_merged_by_label.md"
echo "done."
echo -n "PRs merged..."
dart bin/prs.dart --skip-autorollers --merged $FROM $TO > "$OUT/prs_merged.md"
echo "done."
echo -n "Issues closed..."
dart bin/issues.dart --closed $FROM $TO > "$OUT/issues_closed.md"
echo "done."

# echo -n "Running pandoc..."
# pandoc -o notable-contributors-commiters.html notable-contributors-committers.md
# pandoc -o notable-contributors-commiters.docx notable-contributors-committers.md
# pandoc -o notable-contributors-reviewers.html notable-contributors-reviewers.md
# pandoc -o notable-contributors-reviewers.docx notable-contributors-reviewers.md
# pandoc -o all-contributors-commiters.html all-contributors-committers.md
# pandoc -o all-contributors-committers.docx all-contributors-committers.md
# pandoc -o all-contributors-reviewers.html all-contributors-reviewers.md
# pandoc -o all-contributors-reviewers.docx all-contributors-reviewers.md
# pandoc -o prs_merged_by_label.html prs_merged_by_label.md
# pandoc -o prs_merged_by_label.docx prs_merged_by_label.md
# pandoc -o prs_merged.html prs_merged.md
# pandoc -o prs_merged.docx prs_merged.md
# pandoc -o issues_closed.html issues_closed.md
# pandoc -o issues_closed.docx issues_closed.md
#echo "done."
