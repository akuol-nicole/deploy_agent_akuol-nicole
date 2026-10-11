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
if [ -d "$dir_name" ]; then
read -p "Overwrite? (y/n): " answer
if [ "$answer" = "y" ]; then
rm -rf "$dir_name"
else
echo "Aborted: $dir_name kept"
return
fi
fi
mkdir -p "$dir_name/Helpers" "$dir_name/reports"
cp templates/attendance_checker.py "$dir_name/"
cp templates/config.json "$dir_name/Helpers/"
read -p "Roster: A) copy from template or B) generate? " roster_choice
read -p "How many students? " count

if [ "$roster_choice" = "A" ]; then
head -n $((count+1)) templates/assets.csv > "$dir_name/Helpers/assets.csv"
elif [ "$roster_choice" = "B" ]; then
names=("Alice Johnson" "Bob Smith" "Charlie Davis" "Diana Prince" "Ethan Cole" "Fatima Noor" "George Mensah" "Hannah Kim" "Ibrahim Osei" "Jasmine Lee")
emails=("alice@example.com" "bob@example.com" "charlie@example.com" "diana@example.com" "ethan@example.com" "fatima@example.com" "george@example.com" "hannah@example.com" "ibrahim@example.com" "jasmine@gmail.com")
echo "Email,Names,Attendance Count,Absence Count" > "$dir_name/Helpers/assets.csv"
for  ((i=o; i<count; i++)); do 
echo "${emails[$i]},${names[$i]},0,0" >> "$dir_name/Helpers/assets.csv"
done
sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$dir_name/Helpers/config.json"
fi


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