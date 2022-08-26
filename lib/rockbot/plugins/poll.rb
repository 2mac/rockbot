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

module PollPlugin
  class Poll
    attr_accessor :id, :text, :options, :nick, :channel

    def self.from_db(nick, channel)
      poll = Poll.new
      Rockbot.log.debug { "#{nick} #{channel}" }

      db = Rockbot.database
      selection = db[:poll].where {
        (lower(nick()) =~ nick.downcase) &
          (lower(channel()) =~ channel.downcase)
      }

      Rockbot.log.debug { selection.sql }

      selection.all do |row|
        poll.id = row[:id]
        poll.nick = row[:nick]
        poll.channel = row[:channel]
        poll.text = row[:text]
        poll.options = row[:options].split ','
      end

      raise ArgumentError unless poll.id

      poll
    end
  end

  class << self
    def setup_db
      db = Rockbot.database
      db.create_table?(:poll_meta) { Integer :version }

      meta = db[:poll_meta].first
      schema_version = meta ? meta[:version] : 0

      case schema_version
      when 0
        db[:poll_meta].insert [1]
        db.create_table(:poll) do
          primary_key :id
          String :nick, size: 32, null: false
          String :channel, size: 64, null: false
          String :text, text: true, null: false
          String :options, text: true, null: false
          unique [:nick, :channel]
        end
        db.create_table(:poll_vote) do
          foreign_key :poll_id, :poll
          String :nick, size: 32, null: false
          String :choice, text: true, null: false
          primary_key [:poll_id, :nick]
        end
      end
    end

    def open_poll(event, server, config)
      return if event.args.empty?

      nick = event.source.nick
      channel = event.channel

      unless channel.start_with? '#'
        server.send_msg(nick, "Polls can only be opened in channels")
        return
      end

      poll_details = event.args.split(':')
      poll_text = poll_details[0].strip

      if poll_text.casecmp? 'close'
        close_poll(event, server, config)
        return
      end

      db = Rockbot.database
      selection = db[:poll].where {
        (lower(nick()) =~ nick.downcase) &
          (lower(channel()) =~ channel.downcase)
      }

      if selection.count != 0
        server.send_msg(channel, "#{nick}: You already have a poll open in this channel!")
        return
      end

      case poll_details.size
      when 1
        poll_options = %w{ yes no }
      when 2
        poll_options = poll_details[1].split(',').map(&:strip).map(&:downcase).uniq
      else
        server.send_msg(
          channel,
          "#{nick}: Bad formatting. See 'help poll' for more information."
        )
        return
      end

      if poll_options.size < 2
        server.send_msg(
          channel,
          "#{nick}: It's not much of a poll if there isn't a choice..."
        )
        return
      end

      db[:poll].insert(
        nick: nick,
        channel: channel,
        text: poll_text,
        options: poll_options.join(',')
      )

      server.send_msg(
        channel,
        "#{nick} has started a poll: #{poll_text}" +
        " - options: #{poll_options.join(', ')}." +
        " Use #{config['command_char']}vote #{nick} <choice> to vote!"
      )
    end

    def vote(event, server, config)
      nick = event.source.nick
      channel = event.channel

      re = /^\s*(?<poll>\w+)\s+(?<choice>.+)/
      m = re.match event.args
      unless m
        server.send_msg(channel, "#{nick}: Usage: vote <nick> <choice>")
        return
      end

      poll_nick = m[:poll]
      choice = m[:choice].strip.downcase

      begin
        poll = Poll.from_db(poll_nick, channel)
      rescue ArgumentError => e
        server.send_msg(channel, "#{nick}: #{poll_nick} does not have an active poll.")
        return
      end

      unless poll.options.include? choice
        choices = poll.options.join(', ')
        server.send_msg(
          channel,
          "#{nick}: That option is not available. Choose from: #{choices}"
        )
        return
      end

      db = Rockbot.database
      db.transaction do
        vote_nick = nick.downcase
        db[:poll_vote].where(poll_id: poll.id, nick: vote_nick).delete
        db[:poll_vote].insert(poll_id: poll.id, nick: vote_nick, choice: choice)
      end

      server.send_notice(nick, "You have cast your vote in #{poll_nick}'s poll!")
    end

    def close_poll(event, server, config)
      nick = event.source.nick
      channel = event.channel

      begin
        poll = Poll.from_db(nick, channel)
      rescue ArgumentError => e
        server.send_msg(channel, "#{nick}: You don't have a poll open in this channel.")
        return
      end

      counts = {}
      poll.options.each { |option| counts[option] = 0 }

      db = Rockbot.database

      votes = db[:poll_vote].where(poll_id: poll.id)
      votes.all do |row|
        counts[row[:choice]] += 1
      end

      results = counts.sort { |a,b| b[1] <=> a[1] }
      results.map! { |e| e.join(': ') }
      results = results.join(', ')

      server.send_msg(
        channel,
        "#{nick}'s poll is closed! #{poll.text} - Results: #{results}"
      )

      votes.delete
      db[:poll].where(id: poll.id).delete
    end

    def load
      setup_db

      poll_cmd = Rockbot::Command.new('poll', &method(:open_poll))
      poll_cmd.help_text = "Open or close a poll.\n" +
                           "Usage: poll <question>: <choice1>,<choice2>[,choice3...]\n" +
                           "       poll close"
      Rockbot::Command.add_command poll_cmd

      vote_cmd = Rockbot::Command.new('vote', &method(:vote))
      vote_cmd.help_text = "Vote on a user's poll.\n" +
                           "Usage: vote <user> <choice>"
      Rockbot::Command.add_command vote_cmd

      Rockbot.log.info "Poll plugin loaded"
    end
  end
end

PollPlugin.load
