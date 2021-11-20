# note: to get the TO, use the following command w/ the last commit hash:
# git show --format="%cd" <commit-hash>
# e.g.
# git show --format="%cd" 33e261c0a2eb1f02b94c8fdfef092350c65b4d5c

# flutter-2.8
# commit right after 2.5 stable: cabf35ad1d91d46d63f44c3b13e0f90f6872e464.
# commit right before 2.8 b3 branch: 33e261c0a2eb1f02b94c8fdfef092350c65b4d5c
FROM="2021-08-04T18:59:01-0400"
TO="2021-11-01T12:43:02-0700"
OUT="output/f28"

echo "Running release reports from ${FROM} to ${TO}"
mkdir -p ${OUT}

echo -n "Unpaid contributors..."
echo -n "authors..."
dart bin/notable_contributors.dart --authors --merged $FROM $TO > "$OUT/notable-contributors-committers.md"
echo -n "reviewers..."
dart bin/notable_contributors.dart --reviewers --merged $FROM $TO > "$OUT/notable-contributors-reviewers.md"
echo "done."
echo -n "All contributors..."
echo -n "authors..."
dart bin/notable_contributors.dart --authors --merged --all-contributors $FROM $TO > "$OUT/all-contributors-committers.md"
echo -n "reviewers..."
dart bin/notable_contributors.dart --reviewers --merged  --all-contributors $FROM $TO > "$OUT/all-contributors-reviewers.md"
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
