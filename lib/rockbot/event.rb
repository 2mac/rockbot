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
  ##
  # This generic class represents an event of which the IRC server has notified
  # us. It contains the methods for registering event hooks.
  class Event
    EVENT_TYPES = [] # :nodoc:
    HOOKS = {} # :nodoc:
    THREADS = [] # :nodoc:

    class << self
      ##
      # Adds a new hook for this type of event. This method is mainly used by
      # subclasses of Event. The block passed to this method will be invoked
      # each time the event occurs.
      def add_hook(&block)
        unless HOOKS[self]
          HOOKS[self] = []
        end

        HOOKS[self] << block
      end

      ##
      # Gets the array of hooks for this event type.
      def hooks
        HOOKS[self]
      end

      def inherited(subclass) # :nodoc:
        EVENT_TYPES << subclass
      end

      def loop(server, config) # :nodoc:
        until server.done?
          line = server.gets
          Rockbot.log.debug { "recv: #{line}" }

          process(line, server, config)
        end
      end

      def process(line, server, config) # :nodoc:
        THREADS << Thread.new {
          begin
            msg = IRC::Message.new line
            EVENT_TYPES.each do |event_type|
              if event_type.responds_to? msg.command
                event = event_type.new msg
                event.fire(server, config)
              end
            end
          rescue => e
            Rockbot.log.error e
          ensure
            THREADS.delete Thread.current
          end
        }
      end

      ##
      # Determines whether this type of event should fire for a given IRC
      # command.
      #
      # Returns true if the event should fire.
      def responds_to?(command)
        false
      end
    end

    ##
    # Invoke all event hooks for this event.
    def fire(server, config)
      if should_process?(server, config)
        hooks = HOOKS[self.class]
        hooks.each do |block|
          begin
            block.call(self, server, config)
          rescue => e
            Rockbot.log.error e
          end
        end if hooks
      end
    end

    ##
    # Determines whether to invoke the hooks for this event. While the correct
    # IRC command may have caused this event, it is possible that specific
    # details of the event disqualify it from processing.
    def should_process?(server, config)
      true
    end
  end

  ##
  # This event represents a user joining a channel.
  class JoinEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'JOIN'
    end

    def self.hook(event, server, config) # :nodoc:
      Rockbot.log.info "Joined #{event.channel}" if event.source.nick == server.nick
    end

    ##
    # The IRC::User who joined.
    attr_reader :source

    ##
    # The name of the channel that was joined.
    attr_reader :channel

    def initialize(message) # :nodoc:
      @source = IRC::User.new message.source
      @channel = message.parameters
    end
  end

  ##
  # This event represents a user parting a channel.
  class PartEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'PART'
    end

    def self.hook(event, server, config) # :nodoc:
      Rockbot.log.info "Left #{event.channel}" if event.source.nick == server.nick
    end

    ##
    # The IRC::User who parted.
    attr_reader :source

    ##
    # The name of the channel that was parted.
    attr_reader :channel

    def initialize(message) # :nodoc:
      @source = IRC::User.new message.source
      @channel = message.parameters
    end
  end

  ##
  # This event represents failure to join a channel.
  class JoinFailedEvent < Event
    CODES = { # :nodoc:
      '403' => 'No such channel',
      '405' => 'Joined too many channels',
      '471' => 'Channel is full',
      '473' => 'Not invited',
      '474' => 'Banned',
      '475' => 'Bad password'
    }

    def self.responds_to?(command) # :nodoc:
      CODES.include? command
    end

    def self.hook(event, server, config) # :nodoc:
      Rockbot.log.error "Failed to join #{event.channel}: #{event.reason}"
    end

    ##
    # The channel we attempted to join.
    attr_reader :channel

    ##
    # Text describing the reason we failed.
    attr_reader :reason

    def initialize(message) # :nodoc:
      params = message.parameters.split
      @channel = params[1]
      @reason = CODES[message.command]
    end
  end

  ##
  # This event represents a user being kicked from a channel.
  class KickEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'KICK'
    end

    def self.hook(event, server, config) # :nodoc:
      if event.target.casecmp? server.nick
        Rockbot.log.warn "Kicked from #{event.channel} by #{event.source.nick}"
      end
    end

    ##
    # The IRC::User who kicked +target+.
    attr_reader :source

    ##
    # The channel from which +target+ was kicked.
    attr_reader :channel

    ##
    # The nick of the user who was kicked.
    attr_reader :target

    def initialize(message) # :nodoc:
      @source = IRC::User.new message.source

      params = message.parameters.split
      @channel = params[0]
      @target = params[1]
    end
  end

  ##
  # This event represents the use of a rockbot command. It is always
  # accompanied by a MessageEvent which contained the command.
  class CommandEvent < Event
    def self.hook(event, server, config) # :nodoc:
      command = Rockbot::Command.from_name event.command
      command.call(event, server, config) if command
    end

    ##
    # The IRC::User who sent the command.
    attr_reader :source

    ##
    # The name of the channel in which the command was sent.
    attr_reader :channel

    ##
    # The name of the command (without the leading command character).
    attr_reader :command

    ##
    # The arguments provided for the command (i.e. the rest of the message text
    # after the command name.
    attr_reader :args

    ##
    # The time at which the event occurred.
    attr_reader :time

    def initialize(message_event, server, config) # :nodoc:
      @source = message_event.source
      @channel = message_event.channel
      @time = message_event.time

      content = message_event.content

      mention_prefix_len = server.nick.length + 1
      if /^#{server.nick}.?\s/ =~ content
        content = content[mention_prefix_len..].lstrip
      end

      content = content[1..] if content.chr == config['command_char']
      re = /(?<cmd>\S+)( (?<args>.*))?/
      matches = re.match content

      @command = matches[:cmd]
      @args = matches[:args] || ''
    end
  end

  ##
  # This event represents a chat message.
  class MessageEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'PRIVMSG'
    end

    def self.hook(event, server, config) # :nodoc:
      if event.command?(server, config)
        CommandEvent.new(event, server, config).fire(server, config)
      end
    end

    ##
    # The IRC::User who sent the message.
    attr_reader :source

    ##
    # The name of the channel to which the message was sent.
    attr_reader :channel

    ##
    # The message text.
    attr_reader :content

    ##
    # Determines whether this message is an emote (i.e. +/me+).
    attr_reader :action
    alias_method :action?, :action

    ##
    # The time at which the event occurred.
    attr_reader :time

    def initialize(message) # :nodoc:
      @source = IRC::User.new message.source
      @time = message.time

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

    ##
    # Determines whether this message contains a rockbot command.
    def command?(server, config)
      return false if action?
      return false if @content.empty?
      (/^#{config['command_char']}\w+/ =~ @content ||
       @channel.chr != '#' ||
       /^#{server.nick}.?\s+\w+/ =~ @content)
    end

    def should_process?(server, config) # :nodoc:
      !config['ignore'].include? source.nick
    end
  end

  ##
  # This event represents a user nick change.
  class NickEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'NICK'
    end

    def self.hook(event, server, config) # :nodoc:
      if event.source.nick == server.nick
        Rockbot.log.info "Nick changed to #{event.nick}"
        server.nick = event.nick
      end
    end

    ##
    # The IRC::User who changed nicks. +source.nick+ is the user's old nick.
    attr_reader :source

    ##
    # The new nick.
    attr_reader :nick

    def initialize(message) # :nodoc:
      @source = IRC::User.new message.source

      re = /:?(?<nick>.*)/
      matches = re.match message.parameters
      @nick = matches[:nick]
    end
  end

  ##
  # This event represents a ping from the server.
  class PingEvent < Event
    def self.responds_to?(command) # :nodoc:
      command == 'PING'
    end

    def self.hook(event, server, config) # :nodoc:
      server.puts "PONG #{event.challenge}"
    end

    ##
    # The ping challenge which should be included in the response.
    attr_reader :challenge

    def initialize(message) # :nodoc:
      @challenge = message.parameters
    end
  end

  ##
  # This event is fired when rockbot is shutting down.
  class UnloadEvent < Event
    ##
    # Invokes all hooks for this event.
    def fire
      super(nil, nil)
    end
  end

  def self.set_default_hooks # :nodoc:
    events_with_hook = Event::EVENT_TYPES.select { |c| c.methods.include? :hook }

    events_with_hook.each do |event_class|
      event_class.add_hook &event_class.method(:hook)
    end
  end

end
