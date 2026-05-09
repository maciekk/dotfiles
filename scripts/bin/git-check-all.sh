#!/bin/bash

# Navigate to the src directory or specify the path
SEARCH_DIR="$HOME/src"

echo "Checking git repositories under $SEARCH_DIR for unpushed commits..."

find "$SEARCH_DIR" -type d -name '.git' | while read repo; do
    # Get the parent directory of .git (the repo root)
    repo_dir=$(dirname "$repo")

    # Run within a subshell to not change the main script's working directory
    (
      cd "$repo_dir" > /dev/null 2>&1;

      # Run git fetch to update remote-tracking branches
      git fetch --quiet

      # Check for unpushed commits using git status -sb and look for "ahead"
      status=$(git status -sb 2>/dev/null | grep 'ahead')

      if [ -n "$status" ]; then
        echo -e "\nRepository: $repo_dir"
        echo "$status"
      fi
    )
done

echo "Finished checking."
