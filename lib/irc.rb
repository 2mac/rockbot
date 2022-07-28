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

require 'base64'

module Rockbot
  module IRC
    class Server
      attr_accessor :nick
      attr_reader :done
      alias_method :done?, :done

      def initialize(host, port, transport)
        @host = host
        @port = port
        @transport = transport
        @write_mutex = Thread::Mutex.new
        @done = false
      end

      def connect(config)
        Rockbot.log.info "Connecting to #{@host}/#{@port}..."
        @socket = @transport.connect(@host, @port)

        nick = config['nick']

        auth = nil
        if config['auth']
          case config['auth']['type']
          when 'sasl'
            auth = :sasl
            sasl_user = config['auth']['user']
            sasl_pass = config['auth']['pass']
            auth_str = Base64.encode64 "\x00#{sasl_user}\x00#{sasl_pass}"
          end
        end

        self.puts "CAP REQ sasl" if auth == :sasl
        self.puts "NICK #{nick}"
        self.puts "USER #{nick} 0 * :rockbot"

        @nick = nick

        registered = false
        fail_reason = nil
        until registered || fail_reason
          line = self.gets
          Rockbot.log.debug { "recv: #{line}" }

          msg = Message.new line
          case msg.command
          when 'AUTHENTICATE'
            self.puts "AUTHENTICATE #{auth_str}"
          when 'CAP'
            args = msg.parameters.split
            if args[1] == 'ACK' && /:?sasl/ =~ args[2]
              self.puts "AUTHENTICATE PLAIN"
            end
          when 'PING'
            challenge = msg.parameters
            self.puts "PONG #{challenge}"
          when '376','422' # end of MOTD or no MOTD
            registered = true
          when '433' # nick in use
            fail_reason = 'Nick already in use'
          when '903' # sasl success
            self.puts "CAP END"
          when '904'
            fail_reason = 'SASL auth failed'
          end
        end

        if registered
          Rockbot.log.info "Connected!"
        else
          @transport.disconnect
          raise fail_reason
        end
      end

      def disconnect(message='')
        Rockbot.log.info "Disconnecting from server."
        self.puts "QUIT :#{message}"
        @done = true

        begin
          loop do
            line = self.gets
            Rockbot.log.debug { "recv: #{line}" }
          end
        ensure
          @transport.disconnect
        end
      end

      def puts(text)
        @write_mutex.synchronize {
          Rockbot.log.debug { "send: #{text}" }
          @socket.puts text
        }
      end

      def gets
        @socket.gets.chomp
      end

      def join(channels)
        channel_string = channels.join ','
        self.puts "JOIN #{channel_string}"
      end

      def part(channels)
        channel_string = channels.join ','
        self.puts "PART #{channel_string}"
      end

      # Splits a multi-line or long command into multiple commands and sends it
      def send_cmd(prefix, content, max_len=400)
        content.lines(chomp: true).each do |line|
          index = 0
          until index >= line.length
            self.puts "#{prefix}#{line[index,max_len]}"
            index += max_len
          end
        end
      end

      def send_msg(target, content)
        send_cmd("PRIVMSG #{target} :", content)
      end

      def send_notice(target, content)
        send_cmd("NOTICE #{target} :", content)
      end

      def send_emote(target, content)
        send_msg(target, "\x01ACTION #{content}\x01")
      end

      def set_nick(nick)
        self.puts "NICK #{nick}"
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

    COLOR_MAP = {
      'white' => '00',
      'black' => '01',
      'blue' => '02',
      'green' => '03',
      'red' => '04',
      'brown' => '05',
      'purple' => '06',
      'orange' => '07',
      'yellow' => '08',
      'lgreen' => '09',
      'cyan' => '10',
      'lcyan' => '11',
      'lblue' => '12',
      'pink' => '13',
      'gray' => '14',
      'grey' => '14',
      'lgray' => '15',
      'lgrey' => '15'
    }

    def self.format(text)
      text = text.gsub(/<\/?b>/, "\x02")
      text.gsub!(/<\/?i>/, "\x1D")
      text.gsub!(/<\/?u>/, "\x1F")
      text.gsub!(/<\/?s>/, "\x1E")
      text.gsub!(/<\/?c>/, "\x03")

      color_re = /<c:(?<fg>\w+)(,(?<bg>\w+))?>/
      while m = color_re.match(text)
        fg = m[:fg]
        bg = m[:bg]

        fg = COLOR_MAP[fg] if COLOR_MAP.include? fg
        bg = COLOR_MAP[bg] if COLOR_MAP.include? bg

        code = "\x03#{fg}"
        code << ",#{bg}" if bg

        index = m.offset 0
        text = text[0...index[0]] + code + text[index[1]..]
      end

      text
    end

  end
end
