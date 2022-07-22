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
        Rockbot.log.info "Connecting to #{@host}/#{@port}..."
        @socket = @transport.connect(@host, @port)

        self.puts "NICK #{nick}"
        self.puts "USER #{nick} 0 * :rockbot"

        registered = false
        until registered
          line = self.gets
          Rockbot.log.debug { "recv: #{line}" }

          msg = Message.new line
          case msg.command
          when 'PING'
            challenge = msg.parameters
            self.puts "PONG #{challenge}"
          when '376' # end of MOTD
            registered = true
          end
        end
        Rockbot.log.info "Connected!"
      end

      def disconnect(message='')
        Rockbot.log.info "Disconnecting from server."
        self.puts "QUIT :#{message}"
        @transport.disconnect
      end

      def puts(text)
        Rockbot.log.debug { "send: #{text}" }
        @socket.puts text
      end

      def gets
        @socket.gets.chomp
      end

      def join(channels)
        channel_string = channels.join ','
        self.puts "JOIN #{channel_string}"
      end

      def send_msg(target, content)
        self.puts "PRIVMSG #{target} :#{content}"
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

    class User
      attr_reader :nick, :username, :host

      def initialize(source)
        re = /(?<nick>.*)!(?<user>.*)@(?<host>.*)/
        matches = re.match source

        @nick = matches[:nick]
        @username = matches[:user]
        @host = matches[:host]
      end
    end

  end
end
