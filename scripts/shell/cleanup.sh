#!/bin/bash

# Define the directory to search
search_dir="$1"

# Find folders named .terraform and files named .terraform.lock.hcl
results=$(find "$search_dir" -type d -name ".terraform" -o -type f -name ".terraform.lock.hcl")

# Loop over the results and ask for confirmation before deleting
for item in $results; do
  echo "Found: $item"
  read -p "Do you want to delete this item? (y/n): " choice </dev/tty
  if [[ $choice == "y" || $choice == "Y" ]]; then
    rm -rf "$item"
    echo "$item has been deleted."
  else
    echo "$item has not been deleted."
  fi
done
