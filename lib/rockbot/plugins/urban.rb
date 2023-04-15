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

require 'json'

module UrbanPlugin
  BASE_URL = 'https://api.urbandictionary.com/v0/'

  class << self
    def request(type, params)
      params = params.map { |k,v| "#{k.to_s}=#{v}" }
      url = "#{BASE_URL}#{type}?#{params.join('&')}"

      response = Rockbot.get_uri Rockbot.format_uri(url)
      JSON.parse(response.body)
    end

    def search(term)
      results = request('define', {term: term})
      top_result = results.dig('list', 0)
      return nil unless top_result

      {
        word: top_result['word'],
        definition: top_result['definition'].gsub(/(\[|\])/, ''),
        url: top_result['permalink']
      }
    end

    def lookup(event, server, config)
      term = event.args.strip
      result = search term

      if result
        word = result[:word]
        definition = result[:definition].strip.gsub(/\R+/, ' // ')
        url = result[:url]
        response = "\x02#{word}\x02 : #{definition} -- #{url}"
      else
        response = "We ain't found shit."
      end

      server.send_msg(event.channel, "(#{event.source.nick}) #{response}")
    end

    def load
      ud_cmd = Rockbot::Command.new('urban', ['ud'], &method(:lookup))
      ud_cmd.help_text = "Search the Urban Dictionary for slang words.\n" +
                         "Usage: urban <query>"
      Rockbot::Command.add_command ud_cmd

      Rockbot.log.info "Urban Dictionary plugin loaded"
    end
  end
end

UrbanPlugin.load
