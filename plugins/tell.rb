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
      Rockbot.database do |db|
        db.execute "create table if not exists tell_meta ( version int );"

        schema_version = 0
        results = db.query "select version from tell_meta"
        results.each { |row| schema_version = row[0] }
        results.close

        setup_sql = [
          # version 1
          "insert into tell_meta values (1);
create table tell (
  source text not null,
  channel text not null,
  target text not null,
  message text,
  time text,
  primary key (source,channel,target,message) on conflict ignore
);
create table tell_notify (
  target text not null,
  primary key (target) on conflict ignore
);"
        ]

        setup_sql[schema_version..].each do |sql|
          sql.split(';').each { |stmt| db.execute stmt }
        end
      end
    end

    def tell(event, server, config)
      if event.channel.start_with? '#'
        args = event.args.split
        if args.size >= 2
          if args[0] == event.source.nick
            server.send_msg(
              event.channel,
              "#{event.source.nick}: Might I recommend a notepad?"
            )
            return
          elsif args[0] == server.nick
            server.send_msg(
              event.channel,
              "#{event.source.nick}: Why don't you say that to my face?"
            )
            return
          end

          target = args[0].downcase
          re = /\S+\s+(?<message>.*)/
          matches = re.match event.args
          message = matches[:message].strip

          Rockbot.database do |db|
            db.execute(
              "insert into tell (source,channel,target,message,time) " +
              "values (?,?,?,?,datetime('now'))",
              event.source.nick, event.channel.downcase, target, message
            )

            db.execute(
              "delete from tell_notify where target = ?",
              target
            )
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
      sql = "delete from tell where target = ?"
      params = [target]

      if channel
        sql << " and channel = ?"
        params << channel
      end

      db.execute(sql, params)
    end

    def showtells(event, server, config)
      Rockbot.database do |db|
        results = db.query(
          "select source, message, time from tell where target = ?",
          event.source.nick.downcase
        )

        count = 0
        while (result = results.next)
          source = result[0]
          message = result[1]
          time = DateTime.strptime(result[2], '%Y-%m-%d %H:%M:%S')
          diff = Rockbot.datetime_diff(time, DateTime.now)

          server.send_msg(
            event.source.nick,
            "#{diff} ago, #{source} told you: #{message}"
          )

          count += 1
        end
        results.close

        if count == 0
          server.send_msg(event.source.nick, "You have no pending messages.")
        else
          clear_tells(db, event.source.nick.downcase)
        end
      end
    end

    def check_notify(event, server, config)
      if event.channel.start_with? '#'
        channel = event.channel.downcase
        target = event.source.nick.downcase

        Rockbot.database do |db|
          results = db.query(
            "select target from tell_notify where target = ?",
            target
          )

          if results.next
            results.close
            return
          end

          results = db.query(
            "select count(*) from tell where channel = ? and target = ?",
            channel, target
          )

          result = results.next
          num_pending = result[0].to_i
          results.close

          if num_pending == 1
            results = db.query(
              "select source, message, time from tell where channel = ? and target = ?",
              channel, target
            )

            result = results.next
            source = result[0]
            message = result[1]
            time = DateTime.strptime(result[2], '%Y-%m-%d %H:%M:%S')
            diff = Rockbot.datetime_diff(time, DateTime.now)
            results.close

            server.send_msg(
              event.channel,
              "#{event.source.nick}: #{diff} ago, #{source} told you: #{message}"
            )

            clear_tells(db, target, channel)
          elsif num_pending > 1
            server.send_msg(
              event.channel,
              "#{event.source.nick}: You have #{num_pending} pending messages. " +
              "Type #{config['command_char']}showtells to read them."
            )

            db.execute("insert into tell_notify values (?)", target)
          end
        end
      end
    end

    def load
      setup_db

      Rockbot::Event.add_hook(Rockbot::MessageEvent, &TellPlugin.method(:check_notify))

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
