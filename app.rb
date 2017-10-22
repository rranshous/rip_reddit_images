#!/usr/bin/env ruby

require 'rss'
require 'open-uri'
require 'base64'
require 'json'
require 'pry'

OUT_BASE = File.absolute_path('./data')

def log msg
  STDERR.write("#{msg}\n")
end

def open_slow url, &blk
  req_args = {
    "User-agent" => "https://github.com/rranshous/rip_reddit_images"
  }
  log "opening: #{url}"
  open(url, req_args) do |*args|
    blk.call(*args)
  end

rescue URI::InvalidURIError => ex
  log "invalid url: #{ex}"

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

# count, after
last = ''
1000.times do |page|
  log "page: #{page+1}"
  page_url = "https://www.reddit.com/r/PropagandaPosters/.rss?count=25&after=#{last}"
  open_slow(page_url) do |rss|
    feed = RSS::Parser.parse(rss)
    log "Subreddit: #{feed.title.content}"
    feed.items.each do |item|
      last = item.id.content
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
          image_name = file_name(post_html_url.to_s, img_url)
          out_path = Pathname.new(File.join(OUT_BASE, image_name))
          meta_out_path = out_path.to_s + '.meta.json'
          if out_path.exist?
            log "skipping, exists: #{out_path}"
          else
            log "downloading image: #{img_url}"
            data_size = nil
            open_slow(img_url) do |img_data|
              log "writing image: #{out_path}"
              File.open(out_path, 'wb') do |fh|
                data = img_data.read
                data_size = data.size
                fh.write data
              end
            end
            log "writing meta: #{meta_out_path}"
            File.open(meta_out_path, 'w') do |fh|
              fh.write(JSON.dump({
                original_post_url: post_html_url,
                image_url: img_url,
                image_name: image_name,
                image_data_size: data_size,
              }))
            end
          end
        end
      end
    end
  end

end
