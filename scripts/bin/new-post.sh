#!/bin/bash
#
# Create a new post in my Hugo website. (gohugo.io)

# Usage
#   $ new-post.sh blog-post-alpha.md         # ".md file as blog post"
#   $ new-post.sh blog-post-beta/index.md    # "directory as blog post"

FNAME=$1
FNAME_PATH=content/posts/$(date +%Y)/$FNAME

cd ~/src/total-token-vortex/

echo "About to `hugo new content $FNAME_PATH`."
hugo new content $FNAME_PATH

# leave as 'draft' for now, to evaluate end result first
nvim $FNAME_PATH

# regen `public/`
hugo

# bring up local server, to review draft
hugo server -D
