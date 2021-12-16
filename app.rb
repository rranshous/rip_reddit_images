#!/usr/bin/env ruby

require 'pry'
require_relative 'objs'

SUBREDDIT_NAME = ARGV.shift
puts "ripping subreddit #{SUBREDDIT_NAME}"
OUT_BASE = ENV['OUTPUT_DIR'] || File.absolute_path('./data')
puts "outputting to #{OUT_BASE}"

feed_scanner    = FeedScanner.new(subreddit_name: SUBREDDIT_NAME)
post_scanner    = PostScanner.new(feed_scanner: feed_scanner)
image_scanner   = ImageScanner.new(post_scanner: post_scanner)
image_writer    = ImageWriter.new(out_dir: OUT_BASE)
metadata_writer = MetadataWriter.new(out_dir: OUT_BASE)

image_scanner.each do |image|
  image_writer.write image
  metadata_writer.write image
end
