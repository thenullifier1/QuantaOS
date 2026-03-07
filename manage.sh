#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
APPS_JSON=~/QuantaOS/data/apps.json

# Colors
G='\033[0;32m'   # Green
BG='\033[1;32m'  # Bright Green
DG='\033[0;90m'  # Dark Grey
R='\033[0;31m'   # Red
Y='\033[1;33m'   # Yellow
NC='\033[0m'     # Reset

delete_from_json_by_filename() {
  local filename=$(basename "$1")
  node -e "
    const fs = require('fs');
    let apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    const before = apps.length;
    apps = apps.filter(a => a.filename !== '$filename');
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
    console.log('removed ' + (before - apps.length));
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
    console.log('removed ' + (before - apps.length));
  "
}

list_apps() {
  clear
  echo -e "${BG}"
  echo "  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓"
  echo "  ▓                                      ▓"
  echo "  ▓      QUANTA OS // APP MANAGER        ▓"
  echo "  ▓                                      ▓"
  echo "  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓"
  echo -e "${NC}"
  echo -e "${DG}  ┌──────┬─────────────────┬──────────┬────────────┬────────┐${NC}"
  echo -e "${G}  │ No.  │ Name            │ Version  │ Date       │ Size   │${NC}"
  echo -e "${DG}  ├──────┼─────────────────┼──────────┼────────────┼────────┤${NC}"

  node -e "
    const fs = require('fs');
    const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    if(apps.length === 0) {
      console.log('  │ No apps found                                          │');
    } else {
      apps.forEach((a, i) => {
        const date = new Date(a.upload_date).toISOString().slice(0,10);
        const size = (a.size/1024/1024).toFixed(1)+'MB';
        const num = String(i+1).padEnd(4);
        const name = (a.name||'').slice(0,15).padEnd(15);
        const ver = (a.version||'').slice(0,8).padEnd(8);
        const d = date.padEnd(10);
        const s = size.padEnd(6);
        console.log('\x1b[32m  │ [' + num + '] │ ' + name + ' │ ' + ver + ' │ ' + d + ' │ ' + s + ' │\x1b[0m');
      });
    }
    process.stdout.write('\x1b[90m  └──────┴─────────────────┴──────────┴────────────┴────────┘\x1b[0m\n');
    console.log('');
    console.log('\x1b[90m  Total: ' + apps.length + ' app(s)\x1b[0m');
  "

  echo ""
  echo -e "${BG}  ┌─────────────────────────────┐${NC}"
  echo -e "${G}  │  [d] Delete by number       │${NC}"
  echo -e "${G}  │  [n] Delete by name         │${NC}"
  echo -e "${G}  │  [q] Quit                   │${NC}"
  echo -e "${BG}  └─────────────────────────────┘${NC}"
  echo ""
  echo -ne "${BG}  > ${NC}"
  read choice

  case $choice in
    d)
      echo -ne "${G}  Enter number: ${NC}"
      read num
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
        echo -e "${Y}  ⚠  Delete $appname? (y/n): ${NC}"
        read confirm
        if [ "$confirm" = "y" ]; then
          delete_from_json_by_filename "$target"
          rm -f "$APPS_DIR/$target"
          echo -e "${BG}  ✔ $appname deleted from store and web!${NC}"
          sleep 1
        fi
      else
        echo -e "${R}  ✘ Invalid number${NC}" && sleep 1
      fi
      list_apps ;;
    n)
      echo -ne "${G}  Enter app name: ${NC}"
      read name
      echo -e "${Y}  ⚠  Delete all versions of '$name'? (y/n): ${NC}"
      read confirm
      if [ "$confirm" = "y" ]; then
        delete_from_json_by_name "$name"
        rm -f $APPS_DIR/*${name,,}*.apk
        echo -e "${BG}  ✔ '$name' deleted from store and web!${NC}"
        sleep 1
      fi
      list_apps ;;
    q)
      echo -e "${BG}  Exiting Matrix...${NC}"
      exit 0 ;;
    *)
      list_apps ;;
  esac
}

list_apps
