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
      if Rockbot.is_operator(config, event.source.nick)
        args = event.args.split
        server.join args unless args.empty?

        config.edit { config['channels'] |= args }
      end
    end

    def part(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        channels = event.args.split
        channels << event.channel if channels.empty?
        server.part channels

        config.edit do
          channels.each do |parted|
            config['channels'].delete_if { |c| c.casecmp? parted }
          end
        end
      end
    end

    def nick(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        server.set_nick event.args unless event.args.empty?
      end
    end

    def op(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        args = event.args.split
        unless args.empty?
          config.edit do
            args.each do |arg|
              unless config['ops'].include? arg
                Rockbot.log.info "Adding #{arg} as a new operator"
                config['ops'] << arg
              end
            end
          end
        end
      end
    end

    def deop(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        args = event.args.split
        unless args.empty?
          config.edit do
            args.each do |arg|
              unless arg == event.source.nick
                Rockbot.log.info "Removing #{arg} from operators"
                config['ops'].delete_if { |op| op.casecmp? arg }
              else
                server.send_msg(event.channel, "You wouldn't want to deop yourself...")
              end
            end
          end
        end
      end
    end

    def ignore(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        args = event.args.split
        unless args.empty?
          config.edit do
            args.each do |arg|
              unless arg == event.source.nick
                Rockbot.log.info "Adding #{arg} to ignore list"
                config['ignore'] << arg
              else
                server.send_msg(event.channel, "You wouldn't want to ignore yourself...")
              end
            end
          end
        end
      end
    end

    def unignore(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
        args = event.args.split
        unless args.empty?
          config.edit do
            args.each do |arg|
              Rockbot.log.info "Removing #{arg} from ignore list"
              config['ignore'].delete_if { |nick| nick.casecmp? arg }
            end
          end
        end
      end
    end

    def quit(event, server, config)
      if Rockbot.is_operator(config, event.source.nick)
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

      op_cmd = Rockbot::Command.new('op', &AdminPlugin.method(:op))
      op_cmd.help_text = "Add new operators to the ops list\n" +
                         "Usage: op <nick> [...]"
      Rockbot::Command.add_command op_cmd

      deop_cmd = Rockbot::Command.new('deop', &AdminPlugin.method(:deop))
      deop_cmd.help_text = "Removes operators from the ops list\n" +
                           "Usage: deop <nick> [...]"
      Rockbot::Command.add_command deop_cmd

      ignore_cmd = Rockbot::Command.new('ignore', &AdminPlugin.method(:ignore))
      ignore_cmd.help_text = "Adds users to the ignore list\n" +
                             "Usage: ignore <nick> [...]"
      Rockbot::Command.add_command ignore_cmd

      unignore_cmd = Rockbot::Command.new('unignore', &AdminPlugin.method(:unignore))
      unignore_cmd.help_text = "Remove users from the ignore list\n" +
                               "Usage: unignore <nick> [...]"
      Rockbot::Command.add_command unignore_cmd

      quit_cmd = Rockbot::Command.new('quit', &AdminPlugin.method(:quit))
      quit_cmd.help_text = "Disconnect from IRC\n" +
                           "Usage: quit"
      Rockbot::Command.add_command quit_cmd

      Rockbot.log.info "Admin commands plugin loaded"
    end
  end
end

AdminPlugin.load
