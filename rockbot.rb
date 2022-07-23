#!/usr/bin/env ruby
##
##  rockbot - yet another extensible IRC bot written in Ruby
##  Copyright (C) 2022 David McMackins II
##
##  Redistributions, modified or unmodified, in whole or in part, must retain
##  applicable notices of copyright or other legal privilege, these conditions,
##  and the following license terms and disclaimer.  Subject to these
##  conditions, each holder of copyright or other legal privileges, author or
##  assembler, and contributor of this work, henceforth "licensor", hereby
##  grants to any person who obtains a copy of this work in any form:
##
##  1. Permission to reproduce, modify, distribute, publish, sell, sublicense,
##  use, and/or otherwise deal in the licensed material without restriction.
##
##  2. A perpetual, worldwide, non-exclusive, royalty-free, gratis, irrevocable
##  patent license to make, have made, provide, transfer, import, use, and/or
##  otherwise deal in the licensed material without restriction, for any and
##  all patents held by such licensor and necessarily infringed by the form of
##  the work upon distribution of that licensor's contribution to the work
##  under the terms of this license.
##
##  NO WARRANTY OF ANY KIND IS IMPLIED BY, OR SHOULD BE INFERRED FROM, THIS
##  LICENSE OR THE ACT OF DISTRIBUTION UNDER THE TERMS OF THIS LICENSE,
##  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR
##  A PARTICULAR PURPOSE, AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS,
##  ASSEMBLERS, OR HOLDERS OF COPYRIGHT OR OTHER LEGAL PRIVILEGE BE LIABLE FOR
##  ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN ACTION OF CONTRACT,
##  TORT, OR OTHERWISE ARISING FROM, OUT OF, OR IN CONNECTION WITH THE WORK OR
##  THE USE OF OR OTHER DEALINGS IN THE WORK.
##

require_relative 'lib/log'
require_relative 'lib/command'
require_relative 'lib/config'
require_relative 'lib/event'
require_relative 'lib/irc'
require_relative 'lib/plugin'
require_relative 'lib/transport'

APP_NAME = 'rockbot'
APP_VERSION = '0.0.0'
APP_REPO = 'https://github.com/2mac/rockbot'

config_path = Rockbot::Config.find_config
config = Rockbot::Config.new config_path

Rockbot.init_logger(config['log_file'], config['log_level'])
log = Rockbot.log
log.info "#{APP_NAME} #{APP_VERSION}"

unless config.validate
  log.error "Errors in configuration file. See above for info."
  exit 1
end

log.info 'Loading plugins...'
Rockbot.load_plugins config

log.info 'Registering event types...'
Rockbot.register_events

log.info 'Setting default hooks...'
Rockbot.set_default_hooks

help_cmd = Rockbot::Command.new('help', ['h']) do |event, server, config|
  if event.args.nil? || (name = event.args.strip).empty?
    names = Rockbot::Command.commands.map &:name
    response = "Supported commands: #{names.sort.join(', ')}"
  else
    command = Rockbot::Command.from_name name
    if command.nil? || command.help_text.nil?
      response = "#{name} - no help text found"
    else
      response = "#{name} - #{command.help_text}"
    end
  end

  server.send_notice(event.source.nick, response)
end
help_cmd.help_text = "lists commands or shows detailed help text of a command
Usage: help [command]"
Rockbot::Command.add_command help_cmd

source_cmd = Rockbot::Command.new('source') do |event, server, config|
  target = event.channel.start_with?('#') ? event.channel : event.source.nick
  server.send_msg(target,
                  "I'm an instance of #{APP_NAME}. " +
                  "You can find my source here: #{APP_REPO}")
end
source_cmd.help_text = "responds with a link to the bot's source code"
Rockbot::Command.add_command source_cmd

server_info = /(?<host>.*)\/(?<port>\d*)/.match config['server']

if config['secure']
  transport_class = Rockbot::SecureTransport
else
  transport_class = Rockbot::BasicTransport
end

server = Rockbot::IRC::Server.new(server_info[:host], server_info[:port].to_i,
                                  transport_class.new)
server.connect config['nick']

channels = config['channels']
server.join channels unless channels.nil? || channels.empty?

begin
  Rockbot::Event.loop(server, config)
rescue Interrupt => e
  log.info 'Interrupt received. Now shutting down.'
ensure
  server.disconnect config['quit_msg']
end
