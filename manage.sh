#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps

show_menu() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║       🛠️  QUANTA OS APP MANAGER           ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  [1] View & delete by app name"
  echo "  [2] Delete duplicates (keep latest)"
  echo "  [3] Delete all by name"
  echo "  [4] Show storage usage"
  echo "  [q] Quit"
  echo ""
  read -p "  Choose: " choice
  case $choice in
    1) menu_by_name ;;
    2) delete_duplicates ;;
    3) delete_all_by_name ;;
    4) show_storage ;;
    q) echo "Bye! 👋"; exit 0 ;;
    *) show_menu ;;
  esac
}

get_appname() {
  basename "$1" .apk | sed 's/quanta_app_//;s/quanta_//' | cut -d'_' -f1
}

get_timestamp() {
  basename "$1" .apk | grep -oE '[0-9]{13}'
}

menu_by_name() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║         📦 APPS BY NAME                  ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""

  # Get unique app names
  declare -A app_counts
  for f in $APPS_DIR/*.apk; do
    name=$(get_appname "$f")
    app_counts[$name]=$((${app_counts[$name]:-0}+1))
  done

  i=1
  names=()
  for name in $(echo "${!app_counts[@]}" | tr ' ' '\n' | sort); do
    count=${app_counts[$name]}
    echo "  [$i] $name  ($count version(s))"
    names+=($name)
    ((i++))
  done

  echo ""
  echo "  [b] Back"
  echo ""
  read -p "  Select app to manage: " sel
  [ "$sel" = "b" ] && show_menu && return

  selected_name=${names[$((sel-1))]}
  [ -z "$selected_name" ] && menu_by_name && return

  manage_app_versions "$selected_name"
}

manage_app_versions() {
  local appname=$1
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║  📱 Versions of: $appname"
  echo "╚══════════════════════════════════════════╝"
  echo ""

  files=()
  i=1
  for f in $APPS_DIR/*${appname}*.apk; do
    size=$(du -h "$f" | cut -f1)
    ts=$(get_timestamp "$f")
    date=$(date -d "@$((ts/1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    echo "  [$i] $date  |  $size  |  $(basename $f)"
    files+=("$f")
    ((i++))
  done

  echo ""
  echo "  [a] Delete ALL versions of $appname"
  echo "  [b] Back"
  echo ""
  read -p "  Enter number to delete (or a/b): " sel

  if [ "$sel" = "b" ]; then
    menu_by_name
  elif [ "$sel" = "a" ]; then
    read -p "  ⚠️  Delete ALL $appname versions? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
      rm $APPS_DIR/*${appname}*.apk
      echo "  ✅ All $appname versions deleted!"
      sleep 1; menu_by_name
    else
      manage_app_versions "$appname"
    fi
  elif [[ "$sel" =~ ^[0-9]+$ ]]; then
    target="${files[$((sel-1))]}"
    if [ -f "$target" ]; then
      read -p "  ⚠️  Delete $(basename $target)? (y/n): " confirm
      if [ "$confirm" = "y" ]; then
        rm "$target"
        echo "  ✅ Deleted!"
        sleep 1; manage_app_versions "$appname"
      else
        manage_app_versions "$appname"
      fi
    fi
  fi
}

delete_duplicates() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║     🧹 DELETE DUPLICATES (keep latest)   ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""

  declare -A latest
  declare -A latest_ts
  for f in $APPS_DIR/*.apk; do
    name=$(get_appname "$f")
    ts=$(get_timestamp "$f")
    if [ -z "${latest_ts[$name]}" ] || [ "$ts" -gt "${latest_ts[$name]}" ]; then
      latest[$name]="$f"
      latest_ts[$name]=$ts
    fi
  done

  deleted=0
  for f in $APPS_DIR/*.apk; do
    name=$(get_appname "$f")
    if [ "$f" != "${latest[$name]}" ]; then
      echo "  🗑️  Removing: $(basename $f)"
      rm "$f"
      ((deleted++))
    fi
  done

  echo ""
  echo "  ✅ Done! Removed $deleted duplicate(s)."
  echo ""
  read -p "  Press Enter to go back..." _
  show_menu
}

delete_all_by_name() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║     🗑️  DELETE ALL BY NAME               ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  read -p "  Enter app name to delete: " appname
  matches=$(ls $APPS_DIR/*${appname}*.apk 2>/dev/null | wc -l)
  if [ "$matches" -eq 0 ]; then
    echo "  ❌ No apps found matching: $appname"
  else
    read -p "  ⚠️  Delete $matches file(s) matching '$appname'? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
      rm $APPS_DIR/*${appname}*.apk
      echo "  ✅ Deleted $matches file(s)!"
    fi
  fi
  sleep 1; show_menu
}

show_storage() {
  clear
  echo "╔══════════════════════════════════════════╗"
  echo "║     💾 STORAGE USAGE                     ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Per app:"
  for f in $APPS_DIR/*.apk; do
    name=$(get_appname "$f")
    size=$(du -h "$f" | cut -f1)
    echo "  $size  $(basename $f)"
  done | sort -k1 -h
  echo ""
  echo "  Total: $(du -sh $APPS_DIR | cut -f1)"
  echo ""
  read -p "  Press Enter to go back..." _
  show_menu
}

show_menu
