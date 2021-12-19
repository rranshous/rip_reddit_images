require 'open-uri'
require 'base64'
require 'rss'
require 'json'
require 'uri'

def log msg
  STDERR.write("#{msg}\n")
end

module HttpOpener
  def open_slow url, &blk
    req_args = {
      "User-agent" => "https://github.com/rranshous/rip_reddit_images"
    }
    log "opening: #{url}"
    URI.open(url, req_args) do |*args|
      blk.call(*args)
    end

  rescue URI::InvalidURIError => ex
    log "invalid url: #{ex}"
    nil

  rescue OpenURI::HTTPError => ex
    log "ex: #{ex}"
    if ex.message[/429 Too Many Requests/]
      log "sleeping"
      sleep 10
      open_slow url, &blk
    end
    nil
  end
end

class Post
  include HttpOpener
  attr_accessor :url, :name

  def self.from_feed feed
    feed.items.map do |item|
      post = new
      post.url = item.link.href
      post.name = item.title.content
      post
    end
  end

  def content
    feed.entry.content.content if !feed.nil?
  end

  def title
    feed.title.conten if !feed.nil?
  end

  def feed
    return @parsed_feed if @parsed_feed
    @parsed_feed = open_slow(url + '.rss') do |data|
      if data
        begin
          RSS::Parser.parse(data)
        rescue
          nil
        end
      else
        nil
      end
    end
  end
end

class ImageWriter
  attr_accessor :out_dir

  def initialize out_dir: './data'
    self.out_dir = out_dir
  end

  def write image
    save_path = save_path_for image
    if save_path.exist?
      log "[already-downloaded] skipping data: #{image}"
      return false
    end
    data = image.data
    if data.nil?
      log "[nildata] skipping data: #{image}"
    elsif data.length == 0
      log "[nodata] skipping data: #{image}"
    else
      log "writing data: #{image}"
      write_data image, data
      image.save_path = save_path
    end
  end

  def save_path_for image
    Pathname.new File.join(out_dir, image.save_name)
  end

  private

  def write_data image, data
    File.open(save_path_for(image), 'wb') do |fh|
      fh.write data
    end
  end
end

class MetadataWriter
  attr_accessor :out_dir

  def initialize out_dir: './data'
    self.out_dir = out_dir
  end

  def write image
    if !image.saved?
      log "[notsaved] skipping meta: #{image}"
    else
      log "writing meta: #{image}"
      write_data image
    end
  end

  def save_path_for image
    Pathname.new(image.save_path.to_s + '.meta.json')
  end

  private

  def write_data image
    File.open(save_path_for(image), 'wb') do |fh|
      fh.write image.to_json
    end
  end

  def ext
    '.meta.json'
  end
end

class Image
  include HttpOpener
  attr_accessor :url, :name, :ext, :post_name, :post_url, :save_path, :data_size

  def self.from_post post
    return nil if post.content.nil?
    url = PostParser.image_url_from_content post.content
    return nil if url.nil?

    image = new
    image.url       = url
    image.name      = image.url.split('/').last
    image.ext       = image.name.split('.').last
    image.post_name = post.name
    image.post_url  = post.url
    image
  end

  def data
    _data = open_slow(url) { |image_data| image_data.read }
    self.data_size = _data.length if !_data.nil?
    _data
  end

  def save_name
    "#{Base64.urlsafe_encode64(post_url)}.#{ext}"
  end

  def saved?
    !self.save_path.nil?
  end

  def to_h
    { post_url: post_url, url: url, name: name, data_size: data_size }
  end

  def to_json
    to_h.to_json
  end
end

module PostParser
  def self.image_url_from_content content
    url = content[/https:\/\/i.redd\.it.*?jpg/]
    url ||= content[/https:\/\/i.imgur.com.*?.jpg/]
    url ||= content.match(/(http.*?jpg).*?(http.*?jpg)/)[2][/href.*/][/https.*/] rescue nil
    url
  end
end

class ImageScanner
  attr_accessor :post_scanner

  def initialize post_scanner: nil
    self.post_scanner = post_scanner
  end

  def each
    post_scanner.each do |post|
      begin
        image = Image.from_post post
        yield image if !image.nil?
      rescue => ex
        puts "Error getting image from post: #{ex}"
      end
    end
  end
end

class PostScanner
  attr_accessor :feed_scanner

  def initialize feed_scanner: nil
    self.feed_scanner = feed_scanner
  end

  def each
    feed_scanner.each do |page_feed|
      Post.from_feed(page_feed).each do |post|
        yield post
      end
    end
  end
end

class FeedScanner
  include HttpOpener
  attr_accessor :subreddit_name, :last_id

  def initialize subreddit_name: nil
    self.subreddit_name = subreddit_name
  end

  def each
    each_page do |i|
      puts "page: #{i}"
      feed = get_page_feed
      yield feed
      self.last_id = feed.items.last.id.content
    end
  end

  def page_url
    "https://www.reddit.com/r/#{subreddit_name}/.rss?count=25&after=#{last_id}"
  end

  def feed_url
    "#{page_url}"
  end

  private

  def get_page_feed
    puts "opening feed page: #{feed_url}"
    open_slow(feed_url) { |data| RSS::Parser.parse data }
  end

  def each_page
    (ENV['MAX_PAGES'] || 10).to_i.times { |i| yield i }
  end
end
