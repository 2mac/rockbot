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

module Rockbot
  module IRC
    class Server
      def initialize(host, port, transport)
        @host = host
        @port = port
        @transport = transport
      end

      def connect(nick)
        Rockbot.log.info "Connecting to server..."
        @socket = @transport.connect(@host, @port)

        @socket.puts "NICK #{nick}"
        @socket.puts "USER #{nick} 0 * :rockbot"

        registered = false
        until registered
          line = @socket.gets.chomp
          Rockbot.log.debug "recv: #{line}"

          msg = Message.new line
          case msg.command
          when 'PING'
            challenge = msg.parameters
            Rockbot.log.debug "PONG #{challenge}"
            @socket.puts "PONG #{challenge}"
          when '376' # end of MOTD
            registered = true
          end
        end
      end

      def disconnect
        Rockbot.log.info "Disconnecting from server."
        @socket.puts "QUIT"
        @transport.disconnect
      end

      def puts(text)
        Rockbot.log.debug "send: #{text}"
        @socket.puts text
      end

      def gets
        @socket.gets.chomp
      end

      def join(channels)
        channel_string = channels.join ','
        Rockbot.log.debug "JOIN #{channel_string}"
        @socket.puts "JOIN #{channel_string}"
      end
    end

    class Message
      attr_reader :tags, :source, :command, :parameters

      def initialize(text)
        re = /(@(?<tag>\S*) )?(:(?<src>\S*) )?(?<cmd>\S*) ?(?<param>.*)/
        matches = re.match text

        @tags = matches[:tag]
        @source = matches[:src]
        @command = matches[:cmd]
        @parameters = matches[:param]
      end
    end

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

        def loop(server)
          while true
            line = server.gets
            Rockbot.log.debug "recv: #{line}"

            Thread.new do
              msg = Message.new line
              event_type = @event_map[msg.command]
              if event_type
                event = event_type.new msg
                event.fire server
              end
            end
          end
        end
      end

      def fire(server)
        hooks = Event.hooks[self.class]
        if hooks
          hooks.each { |block| block.call(self, server) }
        end
      end
    end

    class PingEvent < Event
      def self.hook(event, server)
        server.puts "PONG #{event.challenge}"
      end

      attr_reader :challenge

      def initialize(message)
        @challenge = message.parameters
      end
    end

    def self.register_events
      Event.register('PING', PingEvent)
    end

    def self.set_default_hooks
      Event.add_hook(PingEvent) { |e,s| PingEvent.hook(e,s) }
    end

  end
end
