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

require 'set'

module TellPlugin
  TELLS = {}
  NOTIFIED = Set.new

  Tell = Struct.new(:source, :channel, :target, :message, :time)

  class << self
    def setup_db
      db = Rockbot.database
      db.create_table?(:tell_meta) { Integer :version }

      meta = db[:tell_meta].first
      schema_version = meta ? meta[:version] : 0

      case schema_version
      when 0
        db[:tell_meta].insert [1]
        db.create_table(:tell) do
          String :source, null: false, size: 32
          String :channel, null: false, size: 64
          String :target, null: false, size: 32
          String :message, text: true
          DateTime :time, null: false
          primary_key [:source, :channel, :target, :message]
        end
        db.create_table(:tell_notify) do
          String :target, size: 32, null: false
          primary_key [:target]
        end
      end
    end

    def load_db
      db = Rockbot.database

      db[:tell].all.each do |row|
        tell = Tell.new(
          row[:source],
          row[:channel],
          row[:target],
          row[:message],
          row[:time].to_datetime
        )

        TELLS[tell.target] = [] unless TELLS.include? tell.target
        TELLS[tell.target] << tell
      end

      db[:tell_notify].all.each { |nick| NOTIFIED << nick }
    end

    def save_db(event, server, config)
      db = Rockbot.database

      db[:tell].delete
      TELLS.each do |target, tells|
        tells.each { |tell| db[:tell].insert tell.to_h }
      end

      db[:tell_notify].delete
      NOTIFIED.each { |nick| db[:tell_notify].insert nick }
    end

    def tell(event, server, config)
      if event.channel.start_with? '#'
        args = event.args.split
        if args.size >= 2
          if args[0].casecmp? event.source.nick
            server.send_msg(
              event.channel,
              "#{event.source.nick}: Might I recommend a notepad?"
            )
            return
          elsif args[0].casecmp? server.nick
            server.send_msg(
              event.channel,
              "#{event.source.nick}: Why don't you say that to my face?"
            )
            return
          end

          source = event.source.nick
          channel = event.channel.downcase
          target = args[0].downcase

          re = /\S+\s+(?<message>.*)/
          matches = re.match event.args
          message = matches[:message].strip

          TELLS[target] = [] unless TELLS.include? target
          existing = TELLS[target].select do |tell|
            tell.channel == channel &&
              tell.source.downcase == source.downcase &&
              tell.message == message
          end

          if existing.empty?
            tell = Tell.new(source, channel, target, message, event.time)
            TELLS[target] << tell
            NOTIFIED.delete target
          end

          server.send_notice(
            event.source.nick,
            "Your message has been saved, and #{args[0]} will be notified upon their return."
          )
        end
      else
        server.send_msg(event.source.nick, "You can only use 'tell' in a channel.")
      end
    end

    def showtells(event, server, config)
      target = event.source.nick.downcase
      tells = TELLS[target] || []

      if tells.empty?
        server.send_msg(event.source.nick, "You have no pending messages.")
      else
        TELLS[target] = []
        thread = Thread.new {
          tells.each do |tell|
            diff = Rockbot.datetime_diff(tell.time, event.time)
            server.send_msg(
              event.source.nick,
              "#{diff} ago, #{tell.source} told you: #{tell.message}"
            )

            sleep 2
          end

          Rockbot::Event::THREADS.delete Thread.current
        }

        Rockbot::Event::THREADS << thread
      end
    end

    def check_notify(event, server, config)
      if event.channel.start_with? '#'
        target = event.source.nick.downcase
        return if NOTIFIED.include? target

        pending = TELLS[target]
        return unless pending

        channel = event.channel.downcase
        pending = pending.select { |tell| tell.channel == channel }
        num_pending = pending.size

        if num_pending == 1
          pending = pending[0]
          TELLS[target].delete pending

          source = pending.source
          message = pending.message
          diff = Rockbot.datetime_diff(pending.time, event.time)

          server.send_msg(
            event.channel,
            "#{event.source.nick}: #{diff} ago, #{source} told you: #{message}"
          )
        elsif num_pending > 1
          server.send_msg(
            event.channel,
            "#{event.source.nick}: You have #{num_pending} pending messages. " +
            "Type #{config['command_char']}showtells to read them."
          )

          NOTIFIED << target
        end
      end
    end

    def load
      setup_db
      load_db

      Rockbot::MessageEvent.add_hook &TellPlugin.method(:check_notify)

      tell_cmd = Rockbot::Command.new('tell', &TellPlugin.method(:tell))
      tell_cmd.help_text = "Saves a message to tell someone when they return to the channel\n" +
                           "Usage: tell <nick> <message>"
      Rockbot::Command.add_command tell_cmd

      showtells_cmd = Rockbot::Command.new('showtells', &TellPlugin.method(:showtells))
      showtells_cmd.help_text = "Reads all pending 'tell' messages I have for you"
      Rockbot::Command.add_command showtells_cmd

      Rockbot::UnloadEvent.add_hook &TellPlugin.method(:save_db)

      Rockbot.log.info "Tell plugin loaded"
    end
  end
end

TellPlugin.load
