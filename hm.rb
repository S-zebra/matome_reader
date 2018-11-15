#!/usr/bin/ruby

require "open-uri"
require "nokogiri"

class IndexPage
  PATTERN = /^([rn])$/
  NUMBERS = /^(\d+)$/

  FUNCS = {"r" => "reload", "q" => "quit", "n" => "next_page"}

  def initialize(url)
    @page_number = 1
    @url = url
    @links = []
    load_page
    print_page
    print "> "
    loop do
      read_command
      print "> "
    end
  end

  def load_page
    @doc = Nokogiri::HTML(open("#{@url}/?p=#{@page_number}"))
    a_elems = @doc.css("h1 a")
    a_elems.each do |l|
      page_id = l.attr("href").split("/").last.split(".")[0]
      @links << {:text => l.text, :page_id => page_id} if page_id =~ NUMBERS
    end
  end

  def print_page
    @links.each_with_index do |l, i|
      puts "[#{i}] #{l[:text]}"
    end
  end

  def read_command
    buf = nil
    while buf == nil
      buf = STDIN.gets.chomp
    end
    eval_command(buf)
  end

  def eval_command(cmd)
    if cmd =~ PATTERN
      send(FUNCS[cmd])
    elsif cmd =~ NUMBERS
      ArticlePage.new(@url, @links[cmd.to_i][:page_id])
    else
      puts "?"
    end
  end

  def next_page
    @page_number += 1
    reload
    print_page
  end

  def reload
    load_page
    puts "reloaded"
  end

  def quit
    exit
  end
end

class ArticlePage
  POST_SPLITTER = "----------"

  def initialize(url, page_id)
    puts "opening # #{page_id}"
    @doc = Nokogiri::HTML(open("#{url}/archives/#{page_id}.html"))
    parse_body
    parse_comments
    print
  end

  def parse_body
    @page_title = @doc.css("h1 a")[1].text
    @post_date = @doc.at("time").text
    @posts = []
    res_headers = @doc.css(".t_h")
    res_bodies = @doc.css(".t_b,.t_k")
    (res_bodies.size).times do |i|
      begin
        new_hash = {}
        new_hash[:res_num] = res_headers[i].text.split(": ")[0].to_i
        new_hash[:poster_id] = res_headers[i].text.split("ID:")[1].gsub(/\s+$/, "")
        new_hash[:body] = res_bodies[i].text.gsub(/^\n+|\n+$/, "")
        # :poster_name => res_headers[i].text.split(),
        @posts << new_hash
      rescue NoMethodError
        puts "Error: Illegal form of post"
      end
    end
  end

  def parse_comments
    comment_elems = @doc.css(".comment-info")
    @comments = []
    comment_elems.each do |ce|
      new_hash = {}
      author_tag = ce.css(".comment-author")[0].text.split(".")
      new_hash[:num] = author_tag[0].to_i
      new_hash[:author] = author_tag[1]
      new_hash[:date] = ce.css(".comment-date")[0].text
      new_hash[:text] = ce.css(".comment-body")[0].text.gsub(/^\s+|\s+$/, "")
      @comments << new_hash
    end
  end

  def print
    buffer = ""
    buffer << "------\n#{@page_title} (#{@post_date})\n------\n"
    @posts.each do |p|
      buffer << "#{p[:res_num]}(#{p[:poster_id]})\n#{p[:body]}\n\n"
    end
    buffer << "----------\nCOMMENTS\n----------\n\n"
    @comments.each do |c|
      buffer << "#{c[:num]}\n#{c[:text]}\n\n"
    end
    begin
      IO.popen("less", "w") { |io|
        io.puts buffer
        io.close_write
      }
    rescue Errno::EPIPE
    end
  end
end

IndexPage.new(ARGV[0] ? ARGV[0] : "http://hattatu-matome.ldblog.jp")
