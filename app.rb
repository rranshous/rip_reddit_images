#!/usr/bin/env ruby

require 'rss'
require 'open-uri'
require 'base64'
require 'pry'

OUT_BASE = File.absolute_path('./data')

def log msg
  STDERR.write("#{msg}\n")
end

def open_slow url, &blk
  req_args = {
    "User-agent" => "https://github.com/rranshous/rip_reddit_images"
  }
  open(url, req_args) do |*args|
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

def file_name post_url, image_url
  ext = image_url.split('.').last
  "#{Base64.urlsafe_encode64(post_url)}.#{ext}"
end

subreddit_url = 'https://www.reddit.com/r/PropagandaPosters/'
rss_url = URI.join(subreddit_url, '.rss')
open_slow(rss_url) do |rss|
  feed = RSS::Parser.parse(rss)
  log "Subreddit: #{feed.title.content}"
  feed.items.each do |item|
    post_html_url = item.link.href
    post_url = URI.join(item.link.href, '.rss') rescue nil
    post_url ||= item.link.href + '.rss'
    open_slow(post_url) do |post_rss|
      post_feed = RSS::Parser.parse(post_rss)
      title = post_feed.title.content
      log "Post: #{title}"
      content = post_feed.entry.content.content
      img_url = content[/https:\/\/i.redd\.it.*?jpg/]
      img_url ||= content[/https:\/\/i.imgur.com.*?.jpg/]
      img_url ||= content.match(/(http.*?jpg).*?(http.*?jpg)/)[2][/href.*/][/https.*/] rescue nil
      if img_url
        out_path = Pathname.new(
          File.join(OUT_BASE,
                    file_name(post_html_url.to_s, img_url))
        )
        if out_path.exist?
          log "skipping, exists: #{out_path}"
        else
          log "downloading: #{img_url}"
          open_slow(img_url) do |img_data|
            log "writing: #{out_path}"
            File.open(out_path, 'wb') do |fh|
              fh.write img_data
            end
          end
        end
      end
    end
  end
end
