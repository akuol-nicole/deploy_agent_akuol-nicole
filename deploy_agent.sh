#!/bin/bash

deploy () {
    echo "Deploy selected"
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