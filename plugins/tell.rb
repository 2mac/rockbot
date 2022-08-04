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

module TellPlugin
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

          db = Rockbot.database
          existing = db[:tell].where(
            channel: channel,
            target: target,
            message: message
          ) { lower(source()) =~ source.downcase }

          Rockbot.log.debug { existing.sql }

          unless existing.first
            db.transaction do
              db[:tell].insert(
                source: source,
                channel: channel,
                target: target,
                message: message,
                time: DateTime.now
              )

              db[:tell_notify].where(target: target).delete
            end
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

    def clear_tells(db, target, channel=nil)
      tells = db[:tell].where(target: target)
      tells = tells.where(channel: channel) if channel

      tells.delete
    end

    def showtells(event, server, config)
      target = event.source.nick.downcase
      db = Rockbot.database
      tells = db[:tell].where(target: target).all

      if tells.empty?
        server.send_msg(event.source.nick, "You have no pending messages.")
      else
        tells.each do |tell|
          source = tell[:source]
          message = tell[:message]
          time = tell[:time].to_datetime
          diff = Rockbot.datetime_diff(time, DateTime.now)

          server.send_msg(
            event.source.nick,
            "#{diff} ago, #{source} told you: #{message}"
          )
        end

        clear_tells(db, target)
      end
    end

    def check_notify(event, server, config)
      if event.channel.start_with? '#'
        channel = event.channel.downcase
        target = event.source.nick.downcase

        db = Rockbot.database
        notified = db[:tell_notify].where(target: target).first
        return if notified

        pending = db[:tell].where(target: target, channel: channel).first(2)
        if pending.size == 1
          pending = pending[0]
          source = pending[:source]
          message = pending[:message]
          time = pending[:time].to_datetime
          diff = Rockbot.datetime_diff(time, DateTime.now)

          server.send_msg(
            event.channel,
            "#{event.source.nick}: #{diff} ago, #{source} told you: #{message}"
          )

          clear_tells(db, target, channel)
        elsif pending.size > 1
          server.send_msg(
            event.channel,
            "#{event.source.nick}: You have #{num_pending} pending messages. " +
            "Type #{config['command_char']}showtells to read them."
          )

          db[:tell_notify].insert [target]
        end
      end
    end

    def load
      setup_db

      Rockbot::MessageEvent.add_hook &TellPlugin.method(:check_notify)

      tell_cmd = Rockbot::Command.new('tell', &TellPlugin.method(:tell))
      tell_cmd.help_text = "Saves a message to tell someone when they return to the channel\n" +
                           "Usage: tell <nick> <message>"
      Rockbot::Command.add_command tell_cmd

      showtells_cmd = Rockbot::Command.new('showtells', &TellPlugin.method(:showtells))
      showtells_cmd.help_text = "Reads all pending 'tell' messages I have for you"
      Rockbot::Command.add_command showtells_cmd

      Rockbot.log.info "Tell plugin loaded"
    end
  end
end

TellPlugin.load
