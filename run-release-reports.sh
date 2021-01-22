
FROM="2020-09-10T18:17:00";
TO=$1 

[ -z "$TO" ] && TO=` date --iso-8601=seconds`

echo $FROM
echo $TO
