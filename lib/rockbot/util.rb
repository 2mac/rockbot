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
require 'net/http'
require 'pathname'

##
# This module contains all core rockbot functionality.
module Rockbot
  ##
  # Produces a human-readable string of the difference between two DateTime
  # instances. For example: an hour and 20 minutes.
  def self.datetime_diff(from, to)
    from = from.new_offset('+00:00')
    to = to.new_offset('+00:00')

    days = (to - from).to_i
    hours = to.hour - from.hour
    minutes = to.minute - from.minute
    seconds = to.second - from.second
    Rockbot.log.debug { "#{days} #{hours} #{minutes} #{seconds}" }

    minutes -= 1 if seconds < 0

    if minutes < 0
      hours -= 1
      minutes += 60
    end

    hours += 24 if hours < 0

    case days
    when 0
      if hours >= 1
        response = hours == 1 ? "an hour" : "#{hours} hours"
        response << " and #{minutes} minutes" if minutes > 1
      else
        response = case minutes
                   when 0
                     "less than a minute"
                   when 1
                     "a minute"
                   else
                     "#{minutes} minutes"
                   end
      end
    when 1..6
      response = days == 1 ? "a day" : "#{days} days"
      response << " and #{hours} hours" if hours > 1
    else
      weeks = days / 7
      wdays = days % 7
      response = weeks == 1 ? "a week" : "#{weeks} weeks"
      if wdays > 0
        response << " and "
        response << (wdays == 1 ? "a day" : "#{wdays} days")
      end
    end

    response
  end

  # The root of the rockbot project.
  ROOT_DIR = Pathname.new(__dir__).join('../..').realpath

  ##
  # Gets the absolute path in relation to the root of the project.
  def self.resolve_relative(path, rel_to=ROOT_DIR)
    path = Pathname.new path unless path.kind_of? Pathname
    rel_to = Pathname.new rel_to unless rel_to.kind_of? Pathname
    path.absolute? ? path : rel_to.join(path)
  end

  ##
  # Determines whether a nick is in the ops list.
  def self.operator?(config, nick)
    config['ops'].map(&:downcase).include? nick.downcase
  end

  ##
  # Converts a string to a URI, escaping any illegal characters.
  #
  # Returns a URI object for the given string.
  def self.format_uri(s)
    re = /[^A-Za-z0-9\-._~:\/?#\[\]@!$&'()*+,;=]/
    chars = s.chars

    chars.map! do |c|
      (re =~ c) ? c.bytes.map { |b| "%#{b.to_s(16).upcase}" } : c
    end

    URI(chars.join)
  end

  ##
  # Performs an HTTP GET request for the given URI, following redirections up
  # to _redirect_\__limit_ times.
  #
  # Returns a Net::HTTPResponse of the final result or raises
  # Net::ProtocolError.
  def self.get_uri(uri, redirect_limit=10, body_limit=1000000)
    Rockbot.log.debug { "Requesting #{uri.to_s}" }
    result = nil

    if redirect_limit == 0
      raise Net::ProtocolError, "Too many redirects"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10
    http.use_ssl = uri.instance_of? URI::HTTPS

    request = Net::HTTP::Get.new uri
    request['User-Agent'] = 'Mozilla/5.0 (compatible; rockbot/1.0)'
    response = nil
    http.request(request) do |res|
      response = res
      body = ''

      res.read_body do |segment|
        body << segment
        Rockbot.log.debug { "body length=#{body.length}" }
        break if body.length > body_limit
      end

      res.body = body
    end

    Rockbot.log.debug { "Response code #{response.code}" }
    case response
    when Net::HTTPSuccess
      result = response
    when Net::HTTPRedirection
      redirect = response['location']
      Rockbot.log.debug { "Redirected to #{redirect}" }

      if redirect.start_with? /https?:\/\//
        uri = URI(redirect)
      elsif redirect.start_with? '/'
        uri.path = redirect
      else
        existing = uri.path[1..].split '/'
        redirect = redirect.split '/'

        existing.pop unless uri.path.end_with? '/'

        while redirect.first == '..'
          redirect.shift
          existing.pop
        end

        uri.path = '/' + (existing + redirect).join('/')
      end

      result = get_uri(uri, redirect_limit - 1)
    else
      raise Net::ProtocolError, "HTTP #{response.code}"
    end

    result
  end
end
