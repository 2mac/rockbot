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

module WikiPlugin
  BASE_URL = 'https://en.wikipedia.org/'
  API_URL = BASE_URL + 'w/api.php?format=json&utf8=1&'
  PAGE_URL = BASE_URL + 'wiki/'
  MAX_TEXT = 250

  class << self
    def request(params)
      params = params.map { |k,v| "#{k.to_s}=#{v}" }
      uri = Rockbot.format_uri(API_URL + params.join('&'))
      response = Rockbot.get_uri(uri)
      JSON.parse response.body
    end

    def search(title)
      params = {
        action: 'query',
        list: 'search',
        srsearch: title,
        srlimit: 1
      }

      data = request params
      result = data.dig('query', 'search', 0)
      return nil unless result

      result = {
        id: result['pageid'],
        title: result['title'],
        url: PAGE_URL + result['title'].gsub(' ', '_')
      }

      params = {
        action: 'query',
        prop: 'extracts',
        pageids: result[:id],
        exintro: '',
        explaintext: '',
        exchars: MAX_TEXT
      }

      data = request params
      result[:text] = data.dig('query', 'pages', result[:id].to_s, 'extract')

      result
    end

    def lookup(event, server, config)
      title = event.args.strip
      result = search title

      if result
        title = result[:title]
        text = result[:text]
        url = result[:url]
        response = "\x02#{title}\x02 : #{text} -- #{url}"
      else
        response = "I couldn't find any results for that."
      end

      server.send_msg(event.channel, "(#{event.source.nick}) #{response}")
    end

    def load
      wiki_cmd = Rockbot::Command.new('wikipedia', ['wiki','w'], &method(:lookup))
      wiki_cmd.help_text = "Search for a Wikipedia article.\n" +
                           "Usage: wikipedia <query>"
      Rockbot::Command.add_command wiki_cmd

      Rockbot.log.info "Wikipedia plugin loaded"
    end
  end
end

WikiPlugin.load
