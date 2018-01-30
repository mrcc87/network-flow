#!/usr/bin/env ruby

require 'yaml'
require 'sshkit'     
require 'sshkit/dsl'
require 'ruby-progressbar'
require 'colorize'
include SSHKit::DSL
SSHKit.config.output_verbosity=Logger::INFO




ARGV[0].nil? ? abort("No file provided") : config_file = ARGV[0]

begin
  config = YAML.load_file(config_file)
rescue Psych::SyntaxError => se
  abort "ERROR parsing yaml filei #{se.class}. Please check configuration and try again."
end


timeout_regex = /socket.timeout: timed out/
connection_refused_regex = /Connection refused/
success_regex = /^Succeeded$/

#

flows = 0
config.each do |conf|
  conf['dst'].each do |dst|
    flows += dst['ports'].count
  end
end


progressbar = ProgressBar.create(:format         => "%a %b\u{15E7}%i %p%% %t",
                                 :progress_mark  => ' ',                        
                                 :remainder_mark => "\u{FF65}",                 
                                 :total          => 10)                         


printer = []
config.each do |src|
  SSHKit::Backend::Netssh.configure do |ssh|
    ssh.ssh_options = {
      user: src['username'],
      password: src['password']
    }
  end
  on src['src'] do |host|
    src['dst'].each do |dst|
      dst['ports'].each do |port|
        #puts "Trying #{src['src']} => #{dst['ip']}:#{port}"
        output = capture("python -c \"import socket;s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);s.settimeout(2);port = #{port};s.connect(('#{dst['ip']}', port));print 'Succeeded';s.close()\" 2>&1", raise_on_non_zero_exit: false)
        progressbar.increment

        if output.match(success_regex)
          printer.push "#{src['src']} => #{dst['ip']}:#{port} is OK with socket up".colorize(:green)
        elsif output.match(connection_refused_regex)
          printer.push "#{src['src']} => #{dst['ip']}:#{port} is OK with socket closed".colorize(:yellow)
        elsif output.match(timeout_regex)
          printer.push "#{src['src']} => #{dst['ip']}:#{port} is KO".colorize(:red)
        else
          printer.push "#{src['src']} => #{dst['ip']}:#{port} UNEXPECTED OUTCOME"
        end
      end
    end
  end
end

printer.each do |entry|
  puts entry
end
