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

require_relative 'command'
require_relative 'irc'

module Rockbot
  class Event
    EVENT_TYPES = []
    HOOKS = {}
    @event_map = {}

    class << self
      def add_hook(&block)
        unless HOOKS[self]
          HOOKS[self] = []
        end

        HOOKS[self] << block
      end

      def hooks
        HOOKS[self]
      end

      def inherited(subclass)
        EVENT_TYPES << subclass
      end

      def loop(server, config)
        until server.done?
          line = server.gets
          Rockbot.log.debug { "recv: #{line}" }

          process(line, server, config)
        end
      end

      def process(line, server, config)
        Thread.new {
          msg = IRC::Message.new line
          EVENT_TYPES.each do |event_type|
            if event_type.responds_to? msg.command
              event = event_type.new msg
              event.fire(server, config)
            end
          end
        }
      end

      def responds_to?(command)
        false
      end
    end

    def fire(server, config)
      if should_process?(server, config)
        hooks = HOOKS[self.class]
        if hooks
          hooks.each { |block| block.call(self, server, config) }
        end
      end
    end

    def should_process?(server, config)
      true
    end
  end

  class JoinEvent < Event
    def self.responds_to?(command)
      command == 'JOIN'
    end

    def self.hook(event, server, config)
      Rockbot.log.info "Joined #{event.channel}" if event.source.nick == server.nick
    end

    attr_reader :source, :channel

    def initialize(message)
      @source = IRC::User.new message.source
      @channel = message.parameters
    end
  end

  class PartEvent < Event
    def self.responds_to?(command)
      command == 'PART'
    end

    def self.hook(event, server, config)
      Rockbot.log.info "Left #{event.channel}" if event.source.nick == server.nick
    end

    attr_reader :source, :channel

    def initialize(message)
      @source = IRC::User.new message.source
      @channel = message.parameters
    end
  end

  class CommandEvent < Event
    def self.hook(event, server, config)
      command = Rockbot::Command.from_name event.command
      command.call(event, server, config) if command
    end

    attr_reader :source, :channel, :command, :args

    def initialize(message_event, server, config)
      @source = message_event.source
      @channel = message_event.channel

      content = message_event.content

      mention_prefix_len = server.nick.length + 1
      if /#{server.nick}.? / =~ content
        content = content[mention_prefix_len..].lstrip
      end

      content = content[1..] if content.chr == config['command_char']
      re = /(?<cmd>\S+)( (?<args>.*))?/
      matches = re.match content

      @command = matches[:cmd]
      @args = matches[:args] || ''
    end
  end

  class MessageEvent < Event
    def self.responds_to?(command)
      command == 'PRIVMSG'
    end

    def self.hook(event, server, config)
      if event.command?(server, config)
        CommandEvent.new(event, server, config).fire(server, config)
      end
    end

    attr_reader :source, :channel, :content, :action
    alias_method :action?, :action

    def initialize(message)
      @source = IRC::User.new message.source

      re = /(?<channel>\S+) :?(?<content>.*)/
      matches = re.match message.parameters

      @channel = matches[:channel]
      @content = matches[:content]

      action_re = /\x01ACTION (?<content>.*)\x01/
      matches = action_re.match @content
      if matches
        @content = matches[:content]
        @action = true
      end
    end

    def command?(server, config)
      return false if action?
      return false if @content.empty?
      (@content.chr == config['command_char'] ||
       @channel.chr != '#' ||
       /#{server.nick}.? / =~ @content)
    end

    def should_process?(server, config)
      !config['ignore'].include? source.nick
    end
  end

  class NickEvent < Event
    def self.responds_to?(command)
      command == 'NICK'
    end

    def self.hook(event, server, config)
      if event.source.nick == server.nick
        Rockbot.log.info "Nick changed to #{event.nick}"
        server.nick = event.nick
      end
    end

    attr_reader :source, :nick

    def initialize(message)
      @source = IRC::User.new message.source

      re = /:?(?<nick>.*)/
      matches = re.match message.parameters
      @nick = matches[:nick]
    end
  end

  class PingEvent < Event
    def self.responds_to?(command)
      command == 'PING'
    end

    def self.hook(event, server, config)
      server.puts "PONG #{event.challenge}"
    end

    attr_reader :challenge

    def initialize(message)
      @challenge = message.parameters
    end
  end

  def self.set_default_hooks
    events_with_hook = Event::EVENT_TYPES.select { |c| c.methods.include? :hook }

    events_with_hook.each do |event_class|
      event_class.add_hook &event_class.method(:hook)
    end
  end

end
