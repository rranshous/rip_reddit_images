#!/usr/bin/env bash

set -x

for subreddit in `cat subreddits`
do
 echo "download images from $subreddit"
 mkdir -p ./data/$subreddit
 ruby app.rb $subreddit
done
