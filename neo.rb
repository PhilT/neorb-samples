#!/bin/env ruby

require 'json'
require 'yaml'
require 'socket'
require 'timeout'
require 'fileutils'
require 'pry'

hostname = '192.168.1.68'
port = '4242'
@current_date = 0
@dates = [Date.today + 1, Date.today + 2]
@levels = ''

def next_date(args)
  return args unless args.index('<date>')
  date = @dates[@current_date].strftime('000000%02d%02m%Y')
  @current_date += 1
  args.gsub('<date>', date)
end

class ReadTimeoutError; end;

def read_data
  @socket.gets("\0") if IO.select([@socket], nil, nil, 30)
end

@socket = TCPSocket.open(hostname, port)
@device = 'lounge '

def sub(args)
  #devices = '["lounge ","hallway ","dining ","Phil ","Claudi ", "Guest"]'
  devices = %(["#{@device}"])
  merged = args
    .gsub('<devices>', devices)
    .gsub('<levels>', @levels)
  merged = next_date(merged)
  raise "Args contain missing substitutions in: `#{merged}`" if merged.index(/<.+>/)
  merged
end

def path(name, ext)
  files = Dir["results/#{@dir}/#{name}.?.#{ext}"]
  count = files.empty? ? 0 : files.max.split('.')[1].to_i + 1
  "results/#{@dir}/#{name}.#{count}.#{ext}"
end

def send_command(name, args)
  command = %({"#{name}":#{sub(args)}}\0)
  print "Press ENTER to run: #{command}"
  ARGV.any? ? puts : gets
  @socket.write(command)

  data = read_data
  if data
    File.write(path(name, 'raw'), data)
    json = JSON.parse(data.gsub("\0", ''))
    @levels = json[@device].to_json if name == 'READ_COMFORT_LEVELS'
    File.write(path(name, 'json'), json)
    File.write(path(name, 'yml'), json.to_yaml)
    puts "RESPONSE:", json.to_yaml, ''
  else
    puts 'Timed out reading port'
  end
end

if File.extname(ARGV[0]) == '.yml'
  @dir = File.basename(ARGV[0], '.yml')
  FileUtils.mkdir_p("results/#{@dir}")
  commands = YAML.load(File.read(ARGV[0]))

  commands.each do |command|
    send_command(command.keys.first, command.values.first)
  end

  @socket.close
else
  puts './neo.rb <configfile>'
end
