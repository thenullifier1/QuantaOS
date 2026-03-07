#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
APPS_JSON=~/QuantaOS/data/apps.json

get_appname() {
  basename "$1" .apk | sed 's/quanta_app_//;s/quanta_//' | cut -d'_' -f1
}

delete_from_json() {
  local filename=$(basename "$1")
  # Remove entry from apps.json where fileName matches
  node -e "
    const fs = require('fs');
    const path = '$APPS_JSON';
    let apps = JSON.parse(fs.readFileSync(path, 'utf8'));
    const before = apps.length;
    apps = apps.filter(a => !a.fileName.includes('$filename') && a.fileName !== '$filename');
    fs.writeFileSync(path, JSON.stringify(apps, null, 2));
    console.log('Removed ' + (before - apps.length) + ' entry from apps.json');
  "
}

delete_from_json_by_name() {
  local name=$1
  node -e "
    const fs = require('fs');
    const path = '$APPS_JSON';
    let apps = JSON.parse(fs.readFileSync(path, 'utf8'));
    const before = apps.length;
    apps = apps.filter(a => a.name.toLowerCase() !== '$name'.toLowerCase());
    fs.writeFileSync(path, JSON.stringify(apps, null, 2));
    console.log('Removed ' + (before - apps.length) + ' entries from apps.json');
  "
}

list_apps() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║       🛠️  QUANTA OS APP MANAGER           ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  printf "  %-5s %-15s %-25s %-8s\n" "No." "Name" "Date Uploaded" "Size"
  echo "  ────────────────────────────────────────────────"
  i=1
  files=()
  for f in $APPS_DIR/*.apk; do
    name=$(get_appname "$f")
    ts=$(basename "$f" .apk | grep -oE '[0-9]{13}' | head -1)
    date=$(date -d "@$((ts/1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    size=$(du -h "$f" | cut -f1)
    printf "  %-5s %-15s %-25s %-8s\n" "[$i]" "$name" "$date" "$size"
    files+=("$f")
    ((i++))
  done
  echo ""
  echo "  Total: $(du -sh $APPS_DIR 2>/dev/null | cut -f1)"
  echo ""
  echo "  [d] Delete by number"
  echo "  [n] Delete by name"
  echo "  [c] Delete duplicates (keep latest)"
  echo "  [q] Quit"
  echo ""
  read -p "  Choose: " choice

  case $choice in
    d)
      read -p "  Enter number: " num
      target="${files[$((num-1))]}"
      if [ -f "$target" ]; then
        read -p "  ⚠️  Delete $(basename $target)? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
          delete_from_json "$target"
          rm "$target"
          echo "  ✅ Deleted from store and web!"
          sleep 1
        fi
      else
        echo "  ❌ Invalid number" && sleep 1
      fi
      list_apps ;;
    n)
      read -p "  Enter app name: " name
      matches=($(ls $APPS_DIR/*${name}*.apk 2>/dev/null))
      if [ ${#matches[@]} -eq 0 ]; then
        echo "  ❌ No apps found" && sleep 1
      else
        echo ""
        for f in "${matches[@]}"; do echo "  - $(basename $f)"; done
        read -p "  ⚠️  Delete ${#matches[@]} file(s)? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
          delete_from_json_by_name "$name"
          rm "${matches[@]}"
          echo "  ✅ Deleted from store and web!"
          sleep 1
        fi
      fi
      list_apps ;;
    c)
      declare -A latest latest_ts
      for f in $APPS_DIR/*.apk; do
        n=$(get_appname "$f")
        ts=$(basename "$f" .apk | grep -oE '[0-9]{13}' | head -1)
        if [ -z "${latest_ts[$n]}" ] || [ "$ts" -gt "${latest_ts[$n]}" ]; then
          latest[$n]="$f"; latest_ts[$n]=$ts
        fi
      done
      deleted=0
      for f in $APPS_DIR/*.apk; do
        n=$(get_appname "$f")
        if [ "$f" != "${latest[$n]}" ]; then
          delete_from_json "$f"
          rm "$f"
          ((deleted++))
        fi
      done
      echo "  ✅ Removed $deleted duplicate(s) from store and web!" && sleep 1
      list_apps ;;
    q) echo "Bye! 👋"; exit 0 ;;
    *) list_apps ;;
  esac
}

list_apps
