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

module AdminPlugin
  class << self
    def join(event, server, config)
      if config['ops'].include? event.source.nick
        unless event.args.nil?
          args = event.args.split
          server.join args unless args.empty?
        end
      end
    end

    def part(event, server, config)
      if config['ops'].include? event.source.nick
        channels = event.args.nil? ? [] : event.args.split
        channels << event.channel if channels.empty?
        server.part channels
      end
    end

    def nick(event, server, config)
      if config['ops'].include? event.source.nick
        server.set_nick event.args unless event.args.nil?
      end
    end

    def quit(event, server, config)
      if config['ops'].include? event.source.nick
        server.disconnect config['quit_msg']
      end
    end

    def load
      join_cmd = Rockbot::Command.new('join', &AdminPlugin.method(:join))
      join_cmd.help_text = "Join one or more channels\n" +
                           "Usage: join #channel [#channel ...]"
      Rockbot::Command.add_command join_cmd

      part_cmd = Rockbot::Command.new('part', &AdminPlugin.method(:part))
      part_cmd.help_text = "Part one or more channels, or part the current channel\n" +
                           "Usage: part [#channel ...]"
      Rockbot::Command.add_command part_cmd

      nick_cmd = Rockbot::Command.new('nick', &AdminPlugin.method(:nick))
      nick_cmd.help_text = "Set my nick\n" +
                           "Usage: nick <new_nick>"
      Rockbot::Command.add_command nick_cmd

      quit_cmd = Rockbot::Command.new('quit', &AdminPlugin.method(:quit))
      quit_cmd.help_text = "Disconnect from IRC\n" +
                           "Usage: quit"
      Rockbot::Command.add_command quit_cmd

      Rockbot.log.info "Admin commands plugin loaded"
    end
  end
end

AdminPlugin.load
