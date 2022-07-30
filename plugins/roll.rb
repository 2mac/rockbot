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

module RollPlugin
  ROLL_RE = /^(?<n>\d+)?d(?<sides>\d+)$/
  COIN_FACES = %w{ heads tails }
  MAX_ROLLS = 30

  class << self
    def roll(n, sides)
      (1..n).map { |a| Random.rand(1..sides) }
    end

    def parse_roll(text)
      m = ROLL_RE.match text
      raise ArgumentError unless m

      n = m[:n] || 1
      sides = m[:sides]

      [n.to_i, sides.to_i]
    end

    def coin_flip
      COIN_FACES.sample
    end

    def load
      roll_cmd = Rockbot::Command.new('roll') do |event, server, config|
        target = event.channel.start_with?('#') ? event.channel : event.source.nick
        args = event.args.split

        begin
          rolls = args.map &method(:parse_roll)
          num_rolls = rolls.inject(0) { |total, r| total + r[0] }
          if num_rolls > MAX_ROLLS
            server.send_msg(
              target,
              "#{event.source.nick}: Maybe try fewer rolls..."
            )
            next
          end
        rescue
          next
        end

        results = rolls.map { |r| roll *r }
        totals = results.map { |a| a.inject :+ }
        total = totals.inject :+

        results.map! { |r| "(#{r.join(', ')})" }
        results = results.join(', ')

        server.send_msg(
          target,
          "(#{event.source.nick}) Result: #{total}. #{results}"
        )
      end
      roll_cmd.help_text = "Rolls some dice of arbitrary size\n" +
                           "Example: to roll two 6-sided dice: roll 2d6\n" +
                           "Usage: roll <roll> [roll...]"
      Rockbot::Command.add_command roll_cmd

      coin_cmd = Rockbot::Command.new('coin') do |event, server, config|
        target = event.channel.start_with?('#') ? event.channel : event.source.nick
        server.send_emote(target, "flips a coin and gets #{coin_flip}")
      end
      coin_cmd.help_text = "Flips a coin"
      Rockbot::Command.add_command coin_cmd

      Rockbot.log.info "Dice roll plugin loaded"
    end
  end
end

RollPlugin.load
