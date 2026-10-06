#!/bin/bash

deploy () {
    if ! command -v python3 > /dev/null; then
 echo "Uninstalled python3"
exit 1
fi
if ! command -v zip > /dev/null; then
echo "Uninstalled zip"
exit 1
fi
 read -p "Enter project name: " name
if [ -z "$name" ]; then
echo "Project name can't be empty" >&2
return
fi
dir_name="attendance_tracker_$name"
echo "$dir_name"
}

run_app() {
    echo "Run selected"
}

archive_logs() {
    echo "Archive selected"
}

echo "1) Deploy"
echo "2) Run"
echo "3) Archive"
echo "4) Exit"
read -p "Choose: " choice

case $choice in
1) deploy ;;
2) run_app ;;
3) archive_logs ;;
4) exit 0 ;;
*) echo "Invalid choice" ;;
esac