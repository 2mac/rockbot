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
      db = Rockbot.database
      db.create_table?(:seen_meta) { Integer :version }

      meta = db[:seen_meta].first
      schema_version = meta ? meta[:version] : 0

      case schema_version
      when 0
        db[:seen_meta].insert [1]
        db.create_table(:seen) do
          String :nick, null: false, size: 32
          String :channel, null: false, size: 64
          String :message, text: true
          DateTime :time, null: false
          primary_key [:nick, :channel]
        end
      end
    end

    def receive(event, server, config)
      if event.channel.start_with? '#'
        content = event.content
        content = "* #{event.source.nick} #{content}" if event.action?

        nick = event.source.nick.downcase
        channel = event.channel.downcase

        db = Rockbot.database
        db.transaction do
          db[:seen].where(nick: nick, channel: channel).delete
          db[:seen].insert [nick, channel, content, DateTime.now]
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
          db = Rockbot.database
          seen = db[:seen].where(nick: nick.downcase, channel: channel.downcase).first

          if seen
            message = seen[:message]
            time = seen[:time].to_datetime
            diff = Rockbot.datetime_diff(time, DateTime.now)

            response = "#{nick} was last seen #{diff} ago saying: #{message}"
          else
            response = "I haven't seen #{nick} talking in this channel."
          end

          server.send_msg(channel, response)
        end
      end
    end

    def load
      setup_db

      Rockbot::MessageEvent.add_hook &SeenPlugin.method(:receive)

      seen_cmd = Rockbot::Command.new('seen', &SeenPlugin.method(:query))
      seen_cmd.help_text = "Queries for the last time a user was seen speaking\n" +
                           "Usage: seen <nick>"
      Rockbot::Command.add_command seen_cmd

      Rockbot.log.info "Last seen message plugin loaded"
    end
  end
end

SeenPlugin.load
