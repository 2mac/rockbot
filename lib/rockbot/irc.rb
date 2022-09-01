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
  ##
  # This module contains classes and methods related to the IRC protocol.
  module IRC
    ##
    # Represents a connection to an IRC server.
    class Server
      ##
      # rockbot's current nick
      attr_accessor :nick

      attr_reader :done # :nodoc:
      alias_method :done?, :done # :nodoc:

      attr_reader :timed_out # :nodoc:
      alias_method :timed_out?, :timed_out # :nodoc:

      ##
      # Creates a new server.
      #
      # _host_ and _port_ are the server's hostname and IRC port number
      # respectively.
      #
      # _transport_ is one of BasicTransport or SecureTransport defined in
      # +transport.rb+.
      def initialize(host, port, transport)
        @host = host
        @port = port
        @transport = transport
        @write_mutex = Thread::Mutex.new
        @done = false
        @timed_out = false
      end

      ##
      # Connect to the IRC server.
      #
      # _config_ is the Rockbot::Config representing the application config.
      # This is used to determine the nick and any authentication details.
      #
      # Raises an exception if the connection fails.
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
          start_ping_loop config
        else
          @transport.disconnect
          raise fail_reason
        end
      end

      ##
      # Disconnect from the IRC server.
      #
      # The optional _message_ parameter will be used as the quit message.
      def disconnect(message='')
        Rockbot.log.info "Disconnecting from server."

        @done = true
        self.puts "QUIT :#{message}"
        loop { self.gets }
      rescue
      # ignore
      ensure
        @transport.disconnect
        @ping_thread.kill
      end

      def start_ping_loop(config) # :nodoc:
        @ping_thread = Thread.new {
          timeout = config['ping_timeout']
          half = timeout / 2
          index = 0

          loop do
            diff = Time.now.to_i - @last_contact_time
            if diff > timeout
              Rockbot.log.error "Ping timeout: #{diff} seconds"
              @timed_out = true
              @transport.disconnect
              break
            elsif diff >= half
              index += 1
              self.puts "PING #{index}"
              sleep half
            else
              sleep half - diff
            end
          end
        }
      end

      ##
      # Writes a line of text verbatim to the IRC server.
      def puts(text)
        @write_mutex.synchronize {
          Rockbot.log.debug { "send: #{text}" }
          @socket.puts text
        }
      end

      ##
      # Reads the next incoming line of text from the IRC server.
      #
      # Returns the line, without the trailing newline character.
      def gets
        line = @socket.gets.chomp
        Rockbot.log.debug { "recv: #{line}" }
        @last_contact_time = Time.now.to_i
        line
      end

      ##
      # Join one or more channels.
      #
      # _channels_ is an array of channel names.
      #
      # This method will not return success or failure. Instead, the server
      # will later send a JOIN message or else a failure code which will be
      # captured by the event loop.
      def join(channels)
        channel_string = channels.join ','
        self.puts "JOIN #{channel_string}"
      end

      ##
      # Part one or more channels.
      #
      # _channels_ is an array of channel names.
      #
      # This method will not return success or failure. Instead, the server
      # will later send a PART message which will be captured by the event
      # loop.
      def part(channels)
        channel_string = channels.join ','
        self.puts "PART #{channel_string}"
      end

      ##
      # Splits a multi-line or long command into multiple commands and sends it
      # to the IRC server.
      #
      # _prefix_ represents the beginning of each command that is sent.
      #
      # _content_ is the payload which will be split into multiple commands if
      # necessary, always prefixed by _prefix_.
      #
      # _max_\__len_ may be set to determine how many characters of content may
      # be included in each command. The default is 400.
      def send_cmd(prefix, content, max_len=400)
        content.lines(chomp: true).each do |line|
          index = 0
          until index >= line.length
            self.puts "#{prefix}#{line[index,max_len]}"
            index += max_len
          end
        end
      end

      ##
      # Send a message to a channel or user.
      def send_msg(target, content)
        send_cmd("PRIVMSG #{target} :", content)
      end

      ##
      # Send a notice to a channel or user.
      #
      # Note that the IRC protocol specifies that no client should ever
      # automatically reply to a notice.
      def send_notice(target, content)
        send_cmd("NOTICE #{target} :", content)
      end

      ##
      # Send an emote to a channel or user.
      #
      # This is equivalent to the +/me+ command in most IRC clients.
      def send_emote(target, content)
        send_msg(target, "\x01ACTION #{content}\x01")
      end

      ##
      # Change rockbot's nick.
      #
      # This method does not return success or failure. Instead, the server
      # will later send a NICK command or else a failure code which will be
      # captured by the event loop.
      def set_nick(nick)
        self.puts "NICK #{nick}"
      end
    end

    ##
    # Represents an IRC message coming from the server.
    #
    # This is not to be confused with a chat message from a channel or user.
    # In IRC protocol language, a message is any line coming from the server,
    # whether it is a chat message, nick change, join notification, or any
    # other traffic.
    class Message
      attr_reader :tags, :source, :command, :parameters, :time

      ##
      # Creates a new Message by parsing a raw line of text.
      def initialize(text)
        @time = DateTime.now

        re = /(@(?<tag>\S*) )?(:(?<src>\S*) )?(?<cmd>\S*) ?(?<param>.*)/
        matches = re.match text

        @tags = matches[:tag]
        @source = matches[:src]
        @command = matches[:cmd]
        @parameters = matches[:param]
      end
    end

    ##
    # Represents a user on the IRC network.
    class User
      attr_reader :nick, :username, :host

      ##
      # Creates a new User by parsing the +source+ of a message.
      def initialize(source)
        re = /(?<nick>.*)!(?<user>.*)@(?<host>.*)/
        matches = re.match source

        @nick = matches[:nick]
        @username = matches[:user]
        @host = matches[:host]
      end
    end

    COLOR_MAP = { # :nodoc:
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

    ##
    # Format a line of text using HTML-like markup.
    #
    # Example:
    #   Rockbot::IRC.format "<b>This text is bold!</b>"
    #
    # Supported tags:
    #
    # * +b+: bold
    # * +i+: italic
    # * +u+: underline
    # * +s+: strike-through
    # * +r+: reset all formatting
    # * +c+: color
    #
    # Color is specified as: +<c:fg,bg>content</c>+, where +fg+ and +bg+ are
    # the foreground and background colors respectively. Numeric color codes
    # are accepted as well as some common color names. This is documented
    # further in the plugin developer guide.
    #
    # Returns the formatted text string, ready to be sent.
    def self.format(text)
      text = text.gsub(/<\/?b>/, "\x02")
      text.gsub!(/<\/?i>/, "\x1D")
      text.gsub!(/<\/?u>/, "\x1F")
      text.gsub!(/<\/?s>/, "\x1E")
      text.gsub!(/<\/?c>/, "\x03")
      text.gsub!(/<r>/, "\x0F")

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
