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

module Magic8Plugin
  RESPONSES = [
    '<c:green>Yes</c>',
    '<c:green>It is certain</c>',
    '<c:green>It is decidedly so</c>',
    '<c:green>Without a doubt</c>',
    '<c:green>Yes, definitely</c>',
    '<c:green>You may rely on it</c>',
    '<c:green>As I see it, yes</c>',
    '<c:green>Most likely</c>',
    '<c:green>Outlook good</c>',
    '<c:green>Signs point to yes</c>',
    '<c:red>No</c>',
    '<c:red>Don\'t count on it</c>',
    '<c:red>My reply is no</c>',
    '<c:red>My sources say no</c>',
    '<c:red>Outlook not so good</c>',
    '<c:red>Very doubtful</c>',
    'Reply hazy, try again',
    'Ask again later',
    'Better not tell you now',
    'Cannot predict now',
    'Concentrate and ask again'
  ]

  class << self

    def load
      rand = Random.new

      cmd = Rockbot::Command.new('8ball') do |event, server, config|
        target = event.channel.start_with?('#') ? event.channel : event.source.nick
        response = RESPONSES[rand.rand(RESPONSES.size)]
        response = Rockbot::IRC.format "<b>#{response}</b>"

        server.send_emote(target, "shakes the magic 8 ball... #{response}")
      end
      cmd.help_text = "Queries the mysterious magic 8 ball\n" +
                      "Usage: 8ball [question]"
      Rockbot::Command.add_command cmd

      Rockbot.log.info "Magic 8 ball plugin loaded"
    end
  end
end

Magic8Plugin.load
