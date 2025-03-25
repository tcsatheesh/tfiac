#!/bin/bash

# Define the two directories to compare
dir1=$1
dir2=$2

dir1=$(realpath "$dir1")
dir2=$(realpath "$dir2")

echo -e "\nComparing directories:\n$dir1 \nand \n$dir2\n\n"

# Define the files and folders to ignore (comma-separated list)
# ignore_items=".git,node_modules,.terraform,.terraform.lock.hcl,variables,AzuriteConfig,LICENSE,temp,.vscode"
ignore_items=(".git",
"node_modules",
".terraform",
".terraform.lock.hcl",
"variables",
"AzuriteConfig",
"LICENSE",
"temp",
".vscode")

# Join the array elements using a comma
ignore_items=$(IFS=,; echo "${ignore_items[*]}")

# Convert the comma-separated list to an array
IFS=',' read -r -a ignore_array <<< "$ignore_items"

# Build the ignore options for the diff command
ignore_options=""
for item in "${ignore_array[@]}"; do
  ignore_options+="--exclude=$item "
done

# Compare the directories and list the differences, ignoring specified files and folders
diff_output=$(diff -qr $ignore_options "$dir1" "$dir2")

# Check if there are any differences
if [ -z "$diff_output" ]; then
  echo "The directories are identical."
else
  echo "Differences between the directories:"
  echo "$diff_output"
  # Loop through the differences and ask for confirmation before copying missing files and folders
fi