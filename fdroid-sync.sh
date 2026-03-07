#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
MEDIA_DIR=~/storage/downloads/QuantaOS_Media
APPS_JSON=~/QuantaOS/data/apps.json

G='\033[0;32m'; BG='\033[1;32m'; R='\033[0;31m'; Y='\033[1;33m'; NC='\033[0m'
LINE="┌─────────────────────────────────────────────────────────┐"
MID="├─────────────────────────────────────────────────────────┤"
END="└─────────────────────────────────────────────────────────┘"

SOCIAL="cx.ring org.briarproject.briar.android im.vector.app org.jitsi.meet"
TOOLS="com.ghostsq.commander org.sufficientlysecure.keychain com.simplemobiletools.filemanager.pro"
GAMES="org.tuxtype org.freecol.client"
SECURITY="org.torproject.android info.guardianproject.orbot com.kunzisoft.keepass.libre"
INTERNET="org.mozilla.fennec_aurora com.duckduckgo.mobile.android com.devhd.feeder"
MULTIMEDIA="org.videolan.vlc com.poupa.vinylmusicplayer org.schabi.newpipe"

FDROID_REPO="https://f-droid.org/repo"

header() {
  clear
  echo -e "${BG}${LINE}${NC}"
  echo -e "${BG}│         QUANTA OS // F-DROID SYNC              │${NC}"
  echo -e "${BG}${MID}${NC}"
}

download_icon() {
  local pkg=$1
  local iconFile="$MEDIA_DIR/quanta_icon_fdroid_${pkg}_$(date +%s%3N).png"
  curl -sf "$FDROID_REPO/$pkg/en-US/icon.png" -o "$iconFile" 2>/dev/null
  if [ -s "$iconFile" ]; then
    echo "/media/$(basename $iconFile)"
  else
    rm -f "$iconFile"
    # Try legacy icon format
    local versionCode=$2
    iconFile="$MEDIA_DIR/quanta_icon_fdroid_${pkg}_$(date +%s%3N).png"
    curl -sf "$FDROID_REPO/${pkg}_${versionCode}.png" -o "$iconFile" 2>/dev/null
    [ -s "$iconFile" ] && echo "/media/$(basename $iconFile)" || echo ""
  fi
}

download_screenshots() {
  local pkg=$1
  local screenshots=()
  for i in 1 2 3; do
    local ssFile="$MEDIA_DIR/quanta_screenshot_fdroid_${pkg}_${i}_$(date +%s%3N).png"
    curl -sf "$FDROID_REPO/$pkg/en-US/phoneScreenshots/${i}.png" -o "$ssFile" 2>/dev/null
    if [ -s "$ssFile" ]; then
      screenshots+=("/media/$(basename $ssFile)")
    else
      rm -f "$ssFile"
    fi
  done
  echo "${screenshots[@]}"
}

import_app() {
  local pkg=$1 category=$2

  exists=$(node -e "const fs=require('fs');const a=JSON.parse(fs.readFileSync('$APPS_JSON','utf8'));console.log(a.find(x=>x.package_name==='$pkg')?'yes':'no');")
  if [ "$exists" = "yes" ]; then echo -e "${Y}  ⚠  $pkg already exists${NC}"; return; fi

  echo -e "${G}  📦 Fetching $pkg ...${NC}"
  info=$(curl -sf "https://f-droid.org/api/v1/packages/$pkg")
  if [ -z "$info" ]; then echo -e "${R}  ✘ Not found: $pkg${NC}"; return; fi

  versionCode=$(echo "$info" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).suggestedVersionCode||'')}catch(e){}});")
  version=$(echo "$info" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);const p=j.packages&&j.packages.find(x=>x.versionCode==j.suggestedVersionCode);console.log(p?p.versionName:'1.0')}catch(e){console.log('1.0')}});")

  if [ -z "$versionCode" ]; then echo -e "${R}  ✘ No version for $pkg${NC}"; return; fi

  # Download APK
  outFile="$APPS_DIR/quanta_fdroid_${pkg}_$(date +%s%3N).apk"
  appName=$(echo "$pkg" | awk -F'.' '{print $NF}')
  echo -e "${G}  ⬇  Downloading $appName v$version ...${NC}"
  curl -L --progress-bar "$FDROID_REPO/${pkg}_${versionCode}.apk" -o "$outFile"
  if [ ! -s "$outFile" ]; then echo -e "${R}  ✘ Download failed${NC}"; rm -f "$outFile"; return; fi

  # Download icon
  echo -e "${G}  🖼  Downloading icon ...${NC}"
  iconPath=$(download_icon "$pkg" "$versionCode")

  # Download screenshots
  echo -e "${G}  📸  Downloading screenshots ...${NC}"
  screenshotPaths=($(download_screenshots "$pkg"))

  # Build screenshots JSON array
  ssJson=$(node -e "console.log(JSON.stringify($(echo "${screenshotPaths[@]}" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const parts=d.trim().split(/\s+/).filter(Boolean);console.log(JSON.stringify(parts));});")))")

  size=$(stat -c%s "$outFile")
  filename=$(basename "$outFile")

  node -e "
    const fs=require('fs');
    const apps=JSON.parse(fs.readFileSync('$APPS_JSON','utf8'));
    apps.push({
      id:'fdroid-$(date +%s%3N)',
      name:'$appName',
      package_name:'$pkg',
      version:'$version',
      description:'Imported from F-Droid',
      developer:'F-Droid Community',
      category:'$category',
      platform:'android',
      size:$size,
      downloads:0,
      filename:'$filename',
      icon:'$iconPath',
      screenshots:$ssJson,
      github_repo:null,
      video_url:null,
      upload_date:new Date().toISOString(),
      license:'Open Source',
      verified:true,
      rating:0,
      reviewCount:0,
      source:'fdroid'
    });
    fs.writeFileSync('$APPS_JSON',JSON.stringify(apps,null,2));
  "
  echo -e "${BG}  ✔ $appName imported with icon & screenshots!${NC}"
}

sync_category() {
  local name=$1 pkgs=$2
  header
  echo -e "${G}│  Syncing: $name                                  │${NC}"
  echo -e "${BG}${MID}${NC}"; echo ""
  for pkg in $pkgs; do import_app "$pkg" "$name"; done
  echo -e "${BG}  ✔ Done syncing $name!${NC}"
  read -p "  Press Enter..." _
}

search_pkg() {
  echo -ne "${G}  Package name (e.g. cx.ring): ${NC}"; read pkg
  echo -ne "${G}  Category: ${NC}"; read cat
  import_app "$pkg" "${cat:-Other}"
  read -p "  Press Enter..." _
}

main_menu() {
  header
  echo -e "${G}│  [1] Social                                     │${NC}"
  echo -e "${G}│  [2] Tools                                      │${NC}"
  echo -e "${G}│  [3] Games                                      │${NC}"
  echo -e "${G}│  [4] Security                                   │${NC}"
  echo -e "${G}│  [5] Internet                                   │${NC}"
  echo -e "${G}│  [6] Multimedia                                 │${NC}"
  echo -e "${G}│  [7] Sync ALL categories                        │${NC}"
  echo -e "${G}│  [s] Search by package name                     │${NC}"
  echo -e "${G}│  [q] Quit                                       │${NC}"
  echo -e "${BG}${END}${NC}"; echo ""
  echo -ne "${BG}  > ${NC}"; read choice
  case $choice in
    1) sync_category "Social" "$SOCIAL"; main_menu ;;
    2) sync_category "Tools" "$TOOLS"; main_menu ;;
    3) sync_category "Games" "$GAMES"; main_menu ;;
    4) sync_category "Security" "$SECURITY"; main_menu ;;
    5) sync_category "Internet" "$INTERNET"; main_menu ;;
    6) sync_category "Multimedia" "$MULTIMEDIA"; main_menu ;;
    7)
      for cat_data in "Social:$SOCIAL" "Tools:$TOOLS" "Games:$GAMES" "Security:$SECURITY" "Internet:$INTERNET" "Multimedia:$MULTIMEDIA"; do
        sync_category "${cat_data%%:*}" "${cat_data#*:}"
      done
      main_menu ;;
    s) search_pkg; main_menu ;;
    q) echo -e "${BG}  Goodbye.${NC}"; exit 0 ;;
    *) main_menu ;;
  esac
}

pkg install -y curl 2>/dev/null
main_menu
