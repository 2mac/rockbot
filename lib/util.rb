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

require 'date'
require 'pathname'

module Rockbot
  def self.datetime_diff(from, to)
    days = (to - from).to_i
    hours = to.hour - from.hour
    minutes = to.minute - from.minute
    seconds = to.second - from.second
    Rockbot.log.debug "#{days} #{hours} #{minutes} #{seconds}"

    minutes -= 1 if seconds < 0

    if minutes < 0
      hours -= 1
      minutes += 60
    end

    if hours < 0
      days -= 1
      hours += 24
    end

    case days
    when 0
      if hours >= 1
        response = hours == 1 ? "an hour" : "#{hours} hours"
        response << " and #{minutes} minutes" if minutes > 0
      else
        response = minutes >= 1 ? "#{minutes} minutes" : "less than a minute"
      end
    when 1..6
      response = days == 1 ? "a day" : "#{days} days"
      response << " and #{hours} hours" if hours > 0
    else
      weeks = days / 7
      wdays = days % 7
      response = weeks == 1 ? "a week" : "#{weeks} weeks"
      if wdays > 0
        response << " and "
        response << wdays == 1 ? "a day" : "#{wdays} days"
      end
    end

    response
  end

  # Gets the absolute path in relation to rockbot.rb
  def self.resolve_relative(path)
    root = Pathname.new(__dir__).join('..').realpath
    root.join(path)
  end

  def self.operator?(config, nick)
    config['ops'].each { |op| return true if op.casecmp? nick }
  end
end
