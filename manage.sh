#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
APPS_JSON=~/QuantaOS/data/apps.json

get_appname() {
  basename "$1" .apk | sed 's/quanta_app_//;s/quanta_//' | cut -d'_' -f1
}

delete_from_json_by_filename() {
  local filename=$(basename "$1")
  node -e "
    const fs = require('fs');
    let apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    const before = apps.length;
    apps = apps.filter(a => a.filename !== '$filename');
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
    console.log('  ✅ Removed ' + (before - apps.length) + ' entry from web');
  "
}

delete_from_json_by_name() {
  local name=$1
  node -e "
    const fs = require('fs');
    let apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    const before = apps.length;
    apps = apps.filter(a => a.name.toLowerCase() !== '$name'.toLowerCase());
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
    console.log('  ✅ Removed ' + (before - apps.length) + ' entries from web');
  "
}

list_apps() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║       🛠️  QUANTA OS APP MANAGER           ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  printf "  %-5s %-15s %-10s %-20s %-8s\n" "No." "Name" "Version" "Date" "Size"
  echo "  ──────────────────────────────────────────────────────"

  # Read from apps.json for accurate listing
  node -e "
    const fs = require('fs');
    const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    apps.forEach((a, i) => {
      const date = new Date(a.upload_date).toISOString().slice(0,10);
      const size = (a.size / 1024 / 1024).toFixed(1) + 'MB';
      const num = String(i+1).padEnd(5);
      const name = (a.name || '').padEnd(15);
      const ver = (a.version || '').padEnd(10);
      const d = date.padEnd(20);
      console.log('  [' + num + '] ' + name + ver + d + size);
    });
    console.log('');
    console.log('  Total apps: ' + apps.length);
  "

  echo ""
  echo "  [d] Delete by number"
  echo "  [n] Delete by name"
  echo "  [q] Quit"
  echo ""
  read -p "  Choose: " choice

  case $choice in
    d)
      read -p "  Enter number: " num
      # Get filename from json
      target=$(node -e "
        const fs = require('fs');
        const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
        const a = apps[$((num-1))];
        if(a) console.log(a.filename);
      ")
      appname=$(node -e "
        const fs = require('fs');
        const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
        const a = apps[$((num-1))];
        if(a) console.log(a.name);
      ")
      if [ -n "$target" ]; then
        read -p "  ⚠️  Delete $appname ($target)? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
          delete_from_json_by_filename "$target"
          rm -f "$APPS_DIR/$target"
          echo "  ✅ Deleted from web and storage!"
          sleep 1
        fi
      else
        echo "  ❌ Invalid number" && sleep 1
      fi
      list_apps ;;
    n)
      read -p "  Enter app name: " name
      delete_from_json_by_name "$name"
      rm -f $APPS_DIR/*${name,,}*.apk
      sleep 1
      list_apps ;;
    q) echo "Bye! 👋"; exit 0 ;;
    *) list_apps ;;
  esac
}

list_apps
