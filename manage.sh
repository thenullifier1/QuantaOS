#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps
APPS_JSON=~/QuantaOS/data/apps.json

G='\033[0;32m'
BG='\033[1;32m'
DG='\033[0;90m'
R='\033[0;31m'
Y='\033[1;33m'
NC='\033[0m'

delete_by_filename() {
  local filename=$(basename "$1")
  node -e "
    const fs = require('fs');
    let apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    apps = apps.filter(a => a.filename !== '$filename');
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
  "
}

delete_by_name() {
  node -e "
    const fs = require('fs');
    let apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    apps = apps.filter(a => a.name.toLowerCase() !== '$1'.toLowerCase());
    fs.writeFileSync('$APPS_JSON', JSON.stringify(apps, null, 2));
  "
}

list_apps() {
  clear
  echo -e "${BG}  ================================${NC}"
  echo -e "${BG}   QUANTA OS // APP MANAGER${NC}"
  echo -e "${BG}  ================================${NC}"
  echo ""

  node -e "
    const fs = require('fs');
    const apps = JSON.parse(fs.readFileSync('$APPS_JSON', 'utf8'));
    if(apps.length === 0){
      console.log('\x1b[90m  No apps found.\x1b[0m');
    } else {
      apps.forEach((a, i) => {
        const date = new Date(a.upload_date).toISOString().slice(0,10);
        const size = (a.size/1024/1024).toFixed(1)+'MB';
        console.log('\x1b[1;32m  [' + (i+1) + '] ' + a.name + '\x1b[0m');
        console.log('\x1b[32m      v' + a.version + '  |  ' + date + '  |  ' + size + '\x1b[0m');
        console.log('');
      });
      console.log('\x1b[90m  Total: ' + apps.length + ' app(s)\x1b[0m');
    }
  "

  echo ""
  echo -e "${BG}  ================================${NC}"
  echo -e "${G}  [d] Delete by number${NC}"
  echo -e "${G}  [n] Delete by name${NC}"
  echo -e "${G}  [q] Quit${NC}"
  echo -e "${BG}  ================================${NC}"
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
          delete_by_filename "$target"
          rm -f "$APPS_DIR/$target"
          echo -e "${BG}  ✔ Deleted!${NC}"
          sleep 1
        fi
      else
        echo -e "${R}  ✘ Invalid number${NC}" && sleep 1
      fi
      list_apps ;;
    n)
      echo -ne "${G}  Enter app name: ${NC}"
      read name
      echo -e "${Y}  ⚠  Delete '$name'? (y/n): ${NC}"
      read confirm
      if [ "$confirm" = "y" ]; then
        delete_by_name "$name"
        rm -f $APPS_DIR/*${name,,}*.apk
        echo -e "${BG}  ✔ Deleted!${NC}"
        sleep 1
      fi
      list_apps ;;
    q)
      echo -e "${BG}  Goodbye.${NC}"
      exit 0 ;;
    *)
      list_apps ;;
  esac
}

list_apps
