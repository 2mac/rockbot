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

module SeenPlugin
  class << self
    def setup_db
      Rockbot.database do |db|
        db.execute "create table if not exists seen_meta ( version int );"

        schema_version = 0
        results = db.query "select version from seen_meta"
        results.each { |row| schema_version = row[0] }
        results.close

        setup_sql = [
          # version 1
          "insert into seen_meta values (1);
create table seen (
  nick text not null,
  channel text not null,
  message text,
  time text,
  primary key (nick,channel) on conflict replace
);"
        ]

        setup_sql[schema_version..].each do |sql|
          sql.split(';').each { |stmt| db.execute stmt }
        end
      end
    end

    def receive(event, server, config)
      if event.channel.start_with? '#'
        content = event.content
        content = "* #{event.source.nick} #{content}" if event.action?

        Rockbot.database do |db|
          db.execute(
            "insert into seen values (?,?,?,datetime('now'))",
            event.source.nick, event.channel, content
          )
        end
      end
    end

    def query(event, server, config)
      args = event.args.split
      if args.size == 1
        nick = args[0]
        channel = event.channel

        if nick.casecmp? event.source.nick
          server.send_msg(channel, "#{nick}: Have you looked in a mirror lately?")
        elsif nick.casecmp? server.nick
          server.send_msg(channel, "#{event.source.nick}: That's me!")
        else
          response = ''
          Rockbot.database do |db|
            results = db.query(
              "select message, time from seen where nick = ? and channel = ?",
              nick, channel
            )

            result = results.next
            if result
              message = result[0]
              time = DateTime.strptime(result[1], '%Y-%m-%d %H:%M:%S')
              diff = Rockbot.datetime_diff(time, DateTime.now.new_offset('+00:00'))

              response = "#{nick} was last seen #{diff} ago saying: #{message}"
            else
              response = "I haven't seen #{nick} talking in this channel."
            end
            results.close
          end

          server.send_msg(channel, response)
        end
      end
    end

    def load
      setup_db

      Rockbot::Event.add_hook(Rockbot::MessageEvent, &SeenPlugin.method(:receive))

      seen_cmd = Rockbot::Command.new('seen', &SeenPlugin.method(:query))
      seen_cmd.help_text = "Queries for the last time a user was seen speaking\n" +
                           "Usage: seen <nick>"
      Rockbot::Command.add_command seen_cmd

      Rockbot.log.info "Last seen message plugin loaded"
    end
  end
end

SeenPlugin.load
