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

module SedPlugin
  RE = /^s\/(?<pattern>(\\\/|[^\/])+)\/(?<repl>(\\\/|[^\/])*)(\/(?<suffix>\w+)?)?/
  LOG = {}
  MAX_LOG = 100
  MAX_RESULT = 360

  class << self
    def load
      Rockbot::JoinEvent.add_hook do |event, server, config|
        if event.source.nick == server.nick
          LOG[event.channel] = [] unless LOG.include? event.channel
        end
      end

      Rockbot::MessageEvent.add_hook do |event, server, config|
        next if event.command?(server, config)

        m = RE.match event.content
        log = LOG[event.channel]

        if m
          pattern = Regexp.new m[:pattern]
          replacement = "\x02#{m[:repl].gsub('\\/','/')}\x02"
          suffix = m[:suffix] || ''

          method = suffix.include?('g') ? :gsub : :sub

          log.each do |msg|
            if pattern =~ msg.content
              result = msg.content.send(method, pattern, replacement)
              result.gsub!("\x02\x02", '') # eliminate double bold
              if result.length <= MAX_RESULT
                nick = msg.source.nick
                prefix = msg.action? ? "* #{nick}" : "<#{nick}>"
                response = "Correction: #{prefix} #{result}"
                server.send_msg(event.channel, response)
              end

              break
            end
          end
        else
          log.prepend event
          log.pop if log.size > MAX_LOG
        end
      end

      Rockbot.log.info "sed plugin loaded"
    end
  end
end

SedPlugin.load
