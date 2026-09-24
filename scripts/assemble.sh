#!/bin/sh
set -eu

src=$1
generator=$2
site=$3

: "${PUBLIC_SHA:?}" "${PAC_GENERATOR_SHA:?}" "${PAC_SOURCE_DATE:?}"

mkdir -p "$site"
for entry in "$src"/*; do
  case ${entry##*/} in
    Caddyfile | Dockerfile | Jenkinsfile | helm | scripts) ;;
    *) cp -a "$entry" "$site/" ;;
  esac
done

leftovers=$(find "$site" -name '*pac-script.json')
if [ -n "$leftovers" ]; then
  echo "PAC scripts are published from pac-generator, remove them from the repository:" >&2
  echo "$leftovers" >&2
  exit 1
fi

while read -r output target; do
  mkdir -p "$site/${target%/*}"
  cp "$generator/$output" "$site/$target"
  touch -d "$PAC_SOURCE_DATE" "$site/$target"
done <<EOF
pac-meta.json uboost/pac-meta.json
premium-pac-script.json uboost/premium-pac-script.json
premium-lite-pac-script.json uboost/premium-lite-pac-script.json
free-pac-script.json uboost/free-pac-script.json
free-lite-pac-script.json uboost/free-lite-pac-script.json
premium-pac-script.json pacs/premium-pac-script.json
premium-lite-pac-script.json pacs/premium-lite-pac-script.json
free-pac-script.json pacs/free-pac-script.json
free-lite-pac-script.json pacs/free-lite-pac-script.json
pac-meta.json vrubel/pac-meta.json
no-all-internet-premium-pac-script.json vrubel/premium-pac-script.json
no-all-internet-premium-lite-pac-script.json vrubel/premium-lite-pac-script.json
free-pac-script.json vrubel/free-pac-script.json
free-lite-pac-script.json vrubel/free-lite-pac-script.json
pac-meta.json twihd/pac-meta.json
twihd-pac-script.json twihd/twihd-pac-script.json
twihd-test-pac-script.json twihd/twihd-test-pac-script.json
pac-meta.json otkryvashka/pac-meta.json
otkryvashka-pac-script.json otkryvashka/otkryvashka-pac-script.json
otkryvashka-test-pac-script.json otkryvashka/otkryvashka-test-pac-script.json
pac-meta.json peremen/pac-meta.json
peremen-premium-pac-script.json peremen/peremen-premium-pac-script.json
peremen-free-pac-script.json peremen/peremen-free-pac-script.json
pac-meta.json golosapp/pac-meta.json
free-golos-pac-script.json golosapp/free-golos-pac-script.json
EOF

published=$(find "$site" -name '*scripts-registry*.json' -exec jq -r '.. | strings' {} +)
missing=$(
  echo "$published" |
    sed -n 's|^https://staticfiles\.cukubst\.top/||p' |
    sort -u |
    while read -r path; do
      [ -f "$site/$path" ] || echo "$path"
    done
)
if [ -n "$missing" ]; then
  echo "PAC registries point to files that are not published:" >&2
  echo "$missing" >&2
  exit 1
fi

jq -n --arg public "$PUBLIC_SHA" --arg pacGenerator "$PAC_GENERATOR_SHA" \
  '{public: $public, pacGenerator: $pacGenerator}' > "$site/version.json"

find "$site" -type f -size +1k \( -name '*.json' -o -name '*.html' -o -name '*.js' -o -name '*.mjs' \
  -o -name '*.css' -o -name '*.svg' -o -name '*.txt' -o -name '*.xml' \) -exec gzip -9 -k -n {} +
