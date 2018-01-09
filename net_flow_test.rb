#!/usr/bin/env ruby

require 'yaml'
require 'sshkit'     
require 'sshkit/dsl'
include SSHKit::DSL

SSHKit.config.output_verbosity=Logger::INFO
config = YAML.load_file('config.yml')


timeout_regex = /socket.timeout: timed out/
connection_refused_regex = /Connection refused/
success_regex = /^Succeeded$/

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

        if output.match(success_regex)
          puts "#{src['src']} => #{dst['ip']}:#{port} is OK with socket up"
        elsif output.match(connection_refused_regex)
          puts "#{src['src']} => #{dst['ip']}:#{port} is OK with socket closed"
        elsif output.match(timeout_regex)
          puts "#{src['src']} => #{dst['ip']}:#{port} is KO"
        else
          puts "#{src['src']} => #{dst['ip']}:#{port} UNEXPECTED OUTCOME"
        end
      end
    end
  end
end
