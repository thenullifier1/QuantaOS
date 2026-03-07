#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
APPS_JSON=~/QuantaOS/data/apps.json

G='\033[0;32m'
BG='\033[1;32m'
R='\033[0;31m'
Y='\033[1;33m'
DG='\033[0;90m'
NC='\033[0m'

LINE="┌─────────────────────────────────────────────────────────┐"
MID="├─────────────────────────────────────────────────────────┤"
END="└─────────────────────────────────────────────────────────┘"

CATEGORIES=("Social" "Tools" "Games" "Security" "Internet" "Multimedia" "Navigation" "Development")

header() {
  clear
  echo -e "${BG}${LINE}${NC}"
  echo -e "${BG}│         QUANTA OS // F-DROID SYNC              │${NC}"
  echo -e "${BG}${MID}${NC}"
}

search_and_import() {
  local query=$1
  local category=$2

  echo -e "${G}  🔍 Searching F-Droid for: $query ...${NC}"

  result=$(curl -s "https://search.f-droid.org/api/search_apps?q=$(echo $query | sed 's/ /%20/g')&page=1")

  if [ -z "$result" ]; then
    echo -e "${R}  ✘ No results or network error${NC}"
    sleep 2; return
  fi

  # Parse results
  node -e "
    const fs = require('fs');
    const results = JSON.parse('$(echo $result | sed "s/'/\\\'/g")');
    const apps = results.results || results || [];
    if(!apps.length){ console.log('NO_RESULTS'); process.exit(); }
    apps.slice(0,10).forEach((a,i) => {
      const name = (a.name || a.packageName || '').slice(0,20).padEnd(20);
      const pkg = (a.packageName || '').slice(0,30);
      console.log('[' + (i+1) + '] ' + name + ' | ' + pkg);
    });
  " 2>/dev/null

  echo ""
  echo -e "${BG}${MID}${NC}"
  echo -e "${G}  Enter number to import, [a] import all, [b] back: ${NC}"
  read sel

  case $sel in
    b) return ;;
    a)
      node -e "
        const results = JSON.parse('$(echo $result | sed "s/'/\\\'/g")');
        const apps = results.results || results || [];
        apps.slice(0,10).forEach(a => console.log(a.packageName));
      " 2>/dev/null | while read pkg; do
        [ -n "$pkg" ] && import_app "$pkg" "$category"
      done ;;
    *)
      pkg=$(node -e "
        const results = JSON.parse('$(echo $result | sed "s/'/\\\'/g")');
        const apps = results.results || results || [];
        const a = apps[$((sel-1))];
        if(a) console.log(a.packageName);
      " 2>/dev/null)
      [ -n "$pkg" ] && import_app "$pkg" "$category" ;;
  esac
}

import_app() {
  local pkg=$1
  local category=$2

  echo -e "${G}  📦 Fetching info for $pkg ...${NC}"

  info=$(curl -s "https://f-droid.org/api/v1/packages/$pkg")
  if [ -z "$info" ]; then
    echo -e "${R}  ✘ Could not fetch package info${NC}"; sleep 1; return
  fi

  # Check if already in store
  exists=$(node -e "
    const fs = require('fs');
    const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    const found = apps.find(a => a.package_name === '$pkg');
    console.log(found ? 'yes' : 'no');
  ")

  if [ "$exists" = "yes" ]; then
    echo -e "${Y}  ⚠  $pkg already in store, skipping${NC}"; sleep 1; return
  fi

  # Get version code and build APK url
  versionCode=$(echo "$info" | node -e "
    let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
      const j=JSON.parse(d);
      console.log(j.suggestedVersionCode||'');
    });
  ")

  version=$(echo "$info" | node -e "
    let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
      const j=JSON.parse(d);
      const pkg=j.packages&&j.packages.find(p=>p.versionCode==j.suggestedVersionCode);
      console.log(pkg?pkg.versionName:'1.0');
    });
  ")

  apkName="${pkg}_${versionCode}.apk"
  apkUrl="https://f-droid.org/repo/$apkName"
  outFile="$APPS_DIR/quanta_fdroid_${pkg}_$(date +%s%3N).apk"

  echo -e "${G}  ⬇  Downloading $pkg v$version ...${NC}"
  curl -L --progress-bar "$apkUrl" -o "$outFile"

  if [ ! -f "$outFile" ] || [ ! -s "$outFile" ]; then
    echo -e "${R}  ✘ Download failed${NC}"; sleep 1; return
  fi

  size=$(stat -c%s "$outFile")
  filename=$(basename "$outFile")
  id="fdroid-$(date +%s%3N)-$$"

  # Add to apps.json
  node -e "
    const fs = require('fs');
    const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    apps.push({
      id: '$id',
      name: '$pkg'.replace(/\./g,' ').split(' ').pop(),
      package_name: '$pkg',
      version: '$version',
      description: 'Imported from F-Droid',
      developer: 'F-Droid',
      category: '$category',
      platform: 'android',
      size: $size,
      downloads: 0,
      filename: '$filename',
      icon: '',
      screenshots: [],
      github_repo: null,
      video_url: null,
      upload_date: new Date().toISOString(),
      license: 'Open Source',
      verified: true,
      rating: 0,
      reviewCount: 0,
      source: 'fdroid'
    });
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
    console.log('done');
  "

  echo -e "${BG}  ✔ $pkg imported successfully!${NC}"
  sleep 1
}

main_menu() {
  header
  echo -e "${G}│  Choose a category to sync from F-Droid:        │${NC}"
  echo -e "${BG}${MID}${NC}"
  for i in "${!CATEGORIES[@]}"; do
    printf "${G}│  [%d] %-51s│\n${NC}" $((i+1)) "${CATEGORIES[$i]}"
  done
  echo -e "${G}│  [s] Search by app name                         │${NC}"
  echo -e "${G}│  [q] Quit                                       │${NC}"
  echo -e "${BG}${END}${NC}"
  echo ""
  echo -ne "${BG}  > ${NC}"
  read choice

  case $choice in
    [1-8])
      category="${CATEGORIES[$((choice-1))]}"
      header
      echo -e "${G}│  Syncing category: $category${NC}"
      echo -e "${BG}${MID}${NC}"
      search_and_import "$category" "$category"
      main_menu ;;
    s)
      echo -ne "${G}  Search F-Droid: ${NC}"
      read query
      search_and_import "$query" "Other"
      main_menu ;;
    q)
      echo -e "${BG}  Goodbye.${NC}"; exit 0 ;;
    *)
      main_menu ;;
  esac
}

# Check curl available
if ! command -v curl &>/dev/null; then
  echo -e "${Y}  Installing curl...${NC}"
  pkg install -y curl
fi

main_menu
