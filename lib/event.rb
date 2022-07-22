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
      @hooks = {}
      @event_map = {}

      class << self
        def add_hook(type, &block)
          unless @hooks[type]
            @hooks[type] = []
          end

          @hooks[type] << block
        end

        def hooks
          @hooks
        end

        def register(command, event_class)
          @event_map[command] = event_class
        end

        def from_command(command)
          @event_map[command]
        end

        def loop(server, config)
          while true
            line = server.gets
            Rockbot.log.debug { "recv: #{line}" }

            process(line, server, config)
          end
        end

        def process(line, server, config)
          Thread.new {
            msg = IRC::Message.new line
            event_type = @event_map[msg.command]
            if event_type
              event = event_type.new msg
              event.fire(server, config)
            end
          }
        end
      end

      def fire(server, config)
        hooks = Event.hooks[self.class]
        if hooks
          hooks.each { |block| block.call(self, server, config) }
        end
      end
    end

    class JoinEvent < Event
      def self.hook(event, server, config)
        Rockbot.log.info "Joined #{event.channel}"
      end

      attr_reader :channel

      def initialize(message)
        @channel = message.parameters
      end
    end

    class CommandEvent < Event
      def self.hook(event, server, config)
        command = Rockbot::Command.from_name event.command
        command.call(event, server, config) if command
      end

      attr_reader :source, :channel, :command, :args

      def initialize(message_event, config)
        @source = message_event.source
        @channel = message_event.channel

        content = message_event.content
        content = content[1..] if content.chr == config['command_char']
        re = /(?<cmd>\S+)( (?<args>.*))?/
        matches = re.match content

        @command = matches[:cmd]
        @args = matches[:args]
      end
    end

    class MessageEvent < Event
      def self.hook(event, server, config)
        if !event.content.empty? &&
           (event.channel[0] != '#' ||
            event.content[0] == config['command_char'])
          CommandEvent.new(event, config).fire(server, config)
        end
      end

      attr_reader :source, :channel, :content

      def initialize(message)
        @source = IRC::User.new message.source

        re = /(?<channel>\S+) :?(?<content>.*)/
        matches = re.match message.parameters

        @channel = matches[:channel]
        @content = matches[:content]
      end
    end

    class PingEvent < Event
      def self.hook(event, server, config)
        server.puts "PONG #{event.challenge}"
      end

      attr_reader :challenge

      def initialize(message)
        @challenge = message.parameters
      end
    end

    def self.register_events
      Event.register('JOIN', JoinEvent)
      Event.register('PING', PingEvent)
      Event.register('PRIVMSG', MessageEvent)
    end

    def self.set_default_hooks
      events = ObjectSpace.each_object(Class).select { |c| c < Event }
      events_with_hook = events.select { |c| c.methods.include? :hook }

      events_with_hook.each do |event_class|
        Event.add_hook(event_class, &event_class.method(:hook))
      end
    end

end
