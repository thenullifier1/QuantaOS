#!/data/data/com.termux/files/usr/bin/bash

# Quanta OS Management Console
# Simple delete by app name

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Paths
HOME_DIR="$HOME"
APPS_JSON="$HOME_DIR/QuantaOS/data/apps.json"
REVIEWS_JSON="$HOME_DIR/QuantaOS/data/reviews.json"
UPLOAD_DIR="$HOME_DIR/storage/downloads/QuantaOS_Apps"
MEDIA_DIR="$HOME_DIR/storage/downloads/QuantaOS_Media"

# Clear screen
clear_screen() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        QUANTA OS APP MANAGEMENT v1.0          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# List all apps
list_apps() {
    echo -e "${CYAN}📱 AVAILABLE APPS:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -f "$APPS_JSON" ]; then
        echo -e "${RED}No apps found!${NC}"
        return
    fi
    
    # Simple parsing - show package names and versions
    grep -E '"package_name"|"version"' "$APPS_JSON" | while read line; do
        if [[ $line == *"package_name"* ]]; then
            pkg=$(echo "$line" | cut -d'"' -f4)
        fi
        if [[ $line == *"version"* ]]; then
            ver=$(echo "$line" | cut -d'"' -f4)
            echo -e "   ${GREEN}•${NC} $pkg ${YELLOW}(v$ver)${NC}"
        fi
    done
}

# Delete app by package name (since that's what you have)
delete_app() {
    clear_screen
    echo -e "${RED}🗑️  DELETE APP${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show available apps
    list_apps
    
    echo ""
    echo -e "${YELLOW}Enter the EXACT package name to delete${NC}"
    echo -n "Package name: "
    read pkg_name
    
    if [ -z "$pkg_name" ]; then
        echo -e "${RED}❌ Cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Searching for: $pkg_name${NC}"
    
    # Find the app in JSON
    app_line=$(grep -B5 -A5 "\"package_name\": \"$pkg_name\"" "$APPS_JSON")
    
    if [ -z "$app_line" ]; then
        echo -e "${RED}❌ App not found!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Extract details
    app_id=$(echo "$app_line" | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)
    app_name=$(echo "$app_line" | grep -o '"name": "[^"]*"' | head -1 | cut -d'"' -f4)
    filename=$(echo "$app_line" | grep -o '"filename": "[^"]*"' | head -1 | cut -d'"' -f4)
    icon=$(echo "$app_line" | grep -o '"icon": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo -e "\n${YELLOW}Found: $app_name${NC}"
    echo -n -e "${RED}Are you sure you want to delete? (yes/no): ${NC}"
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Deletion cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "\n${GREEN}Deleting...${NC}"
    
    # Delete APK file
    if [ -n "$filename" ] && [ -f "$UPLOAD_DIR/$filename" ]; then
        rm "$UPLOAD_DIR/$filename"
        echo -e "${GREEN}   ✅ Deleted: $filename${NC}"
    fi
    
    # Delete icon
    if [ -n "$icon" ] && [ "$icon" != "null" ]; then
        icon_file=$(basename "$icon")
        if [ -f "$MEDIA_DIR/$icon_file" ]; then
            rm "$MEDIA_DIR/$icon_file"
            echo -e "${GREEN}   ✅ Deleted icon${NC}"
        fi
    fi
    
    # Delete screenshots
    grep -A10 "\"id\": \"$app_id\"" "$APPS_JSON" | grep -o '"screenshots": \[[^]]*\]' | grep -o '"[^"]*\.jpg"' | while read shot; do
        shot_file=$(basename "$shot" | tr -d '"')
        if [ -f "$MEDIA_DIR/$shot_file" ]; then
            rm "$MEDIA_DIR/$shot_file"
            echo -e "${GREEN}   ✅ Deleted screenshot: $shot_file${NC}"
        fi
    done
    
    # Remove from JSON (create new file without this app)
    grep -v "\"package_name\": \"$pkg_name\"" "$APPS_JSON" | sed '/^$/d' > "$APPS_JSON.tmp"
    # Fix JSON formatting
    echo "[" > "$APPS_JSON.new"
    sed 's/^\[//;s/\]$//' "$APPS_JSON.tmp" | sed '/^$/d' | sed '$!s/$/,/' >> "$APPS_JSON.new"
    echo "]" >> "$APPS_JSON.new"
    mv "$APPS_JSON.new" "$APPS_JSON"
    rm -f "$APPS_JSON.tmp"
    
    # Delete reviews
    if [ -f "$REVIEWS_JSON" ] && [ -n "$app_id" ]; then
        grep -v "\"appId\": \"$app_id\"" "$REVIEWS_JSON" > "$REVIEWS_JSON.tmp"
        mv "$REVIEWS_JSON.tmp" "$REVIEWS_JSON"
        echo -e "${GREEN}   ✅ Deleted reviews${NC}"
    fi
    
    echo -e "\n${GREEN}✅ App deleted successfully!${NC}"
    read -p "Press Enter to continue..."
}

# Quick delete by number
quick_delete() {
    clear_screen
    echo -e "${CYAN}🔢 QUICK DELETE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Create array of package names
    packages=()
    while IFS= read -r line; do
        if [[ $line == *"package_name"* ]]; then
            pkg=$(echo "$line" | cut -d'"' -f4)
            packages+=("$pkg")
        fi
    done < "$APPS_JSON"
    
    # Display numbered list
    for i in "${!packages[@]}"; do
        echo -e "   ${GREEN}$((i+1)).${NC} ${packages[$i]}"
    done
    
    echo ""
    echo -n "Enter number to delete (0 to cancel): "
    read choice
    
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        echo -e "${YELLOW}Cancelled${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ "$choice" -gt 0 ] && [ "$choice" -le "${#packages[@]}" ]; then
        selected="${packages[$((choice-1))]}"
        echo -e "\n${YELLOW}Selected: $selected${NC}"
        echo -n -e "${RED}Delete this app? (yes/no): ${NC}"
        read confirm
        
        if [ "$confirm" = "yes" ]; then
            # Set pkg_name and call delete logic
            pkg_name="$selected"
            
            # Find and delete (simplified version)
            filename=$(grep -A5 "\"package_name\": \"$pkg_name\"" "$APPS_JSON" | grep -o '"filename": "[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$filename" ] && [ -f "$UPLOAD_DIR/$filename" ]; then
                rm "$UPLOAD_DIR/$filename"
            fi
            
            # Remove from JSON
            grep -v "\"package_name\": \"$pkg_name\"" "$APPS_JSON" > "$APPS_JSON.tmp"
            echo "[" > "$APPS_JSON.new"
            sed 's/^\[//;s/\]$//' "$APPS_JSON.tmp" | sed '/^$/d' | sed '$!s/$/,/' >> "$APPS_JSON.new"
            echo "]" >> "$APPS_JSON.new"
            mv "$APPS_JSON.new" "$APPS_JSON"
            rm -f "$APPS_JSON.tmp"
            
            echo -e "${GREEN}✅ App deleted!${NC}"
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
    else
        echo -e "${RED}Invalid choice${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    clear_screen
    echo -e "${CYAN}📱 MAIN MENU${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}1)${NC} 📋 List All Apps"
    echo -e "${WHITE}2)${NC} 🗑️  Delete App (by package name)"
    echo -e "${WHITE}3)${NC} 🔢 Quick Delete (by number)"
    echo -e "${WHITE}4)${NC} 🚪 Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n -e "${GREEN}Choose option [1-4]: ${NC}"
    
    read choice
    
    case $choice in
        1)
            clear_screen
            list_apps
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            delete_app
            ;;
        3)
            quick_delete
            ;;
        4)
            echo -e "${GREEN}Goodbye! 👋${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
