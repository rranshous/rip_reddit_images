#!/usr/bin/env ruby

require 'rss'
require 'open-uri'
require 'pry'

def log msg
  STDERR.write("#{msg}\n")
end

def open_slow url, &blk
  open(url) do |*args|
    blk.call(*args)
  end
rescue OpenURI::HTTPError => ex
  log "ex: #{ex}"
  if ex.message[/429 Too Many Requests/]
    log "sleeping"
    sleep 10
    open_slow url, &blk
  end
end

subreddit_url = 'https://www.reddit.com/r/PropagandaPosters/'
rss_url = URI.join(subreddit_url, '.rss')
log "RSS: #{rss_url}"
open_slow(rss_url) do |rss|
  feed = RSS::Parser.parse(rss)
  log "Subreddit: #{feed.title.content}"
  feed.items.each do |item|
    log "Post: #{item.title.content}"
    post_url = URI.join(item.link.href, '.rss')
    log "post: #{post_url}"
    open_slow(post_url) do |post_rss|
      post_feed = RSS::Parser.parse(post_rss)
      content = post_feed.entry.content.content
      img_url = content[/https:\/\/i.redd\.it.*?jpg/]
      img_url ||= content[/https:\/\/i.imgur.com.*?.jpg/]
      img_url ||= content.match(/(http.*?jpg).*?(http.*?jpg)/)[2][/href.*/][/https.*/] rescue nil
      puts img_url if img_url
    end
  end
end
