#!/data/data/com.termux/files/usr/bin/bash
APPS_DIR=~/storage/downloads/QuantaOS_Apps

while true; do
  clear
  echo "╔══════════════════════════════════════╗"
  echo "║     🛠️  QUANTA OS APP MANAGER         ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "📦 Installed Apps:"
  echo ""

  # List apps with numbers
  apps=($APPS_DIR/*.apk)
  for i in "${!apps[@]}"; do
    name=$(basename "${apps[$i]}" .apk)
    size=$(du -h "${apps[$i]}" | cut -f1)
    echo "  [$((i+1))] $name ($size)"
  done

  echo ""
  echo "  [d] Delete an app"
  echo "  [q] Quit"
  echo ""
  read -p "Choose: " choice

  if [ "$choice" = "q" ]; then
    echo "Bye!"
    break
  elif [ "$choice" = "d" ]; then
    read -p "Enter number to delete: " num
    idx=$((num-1))
    if [ -f "${apps[$idx]}" ]; then
      read -p "Delete $(basename ${apps[$idx]})? (y/n): " confirm
      if [ "$confirm" = "y" ]; then
        rm "${apps[$idx]}"
        echo "✅ Deleted!"
        sleep 1
      fi
    else
      echo "❌ Invalid number"
      sleep 1
    fi
  fi
done
