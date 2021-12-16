#!/usr/bin/env bash

set -x

for subreddit in `cat subreddits`
do
 export OUTPUT_DIR=$DATA_DIR/$subreddit
 echo "download images from $subreddit"
 mkdir -p $DATA_DIR/$subreddit
 ruby app.rb $subreddit
done
