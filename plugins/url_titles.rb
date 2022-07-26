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

require 'net/http'

module UrlTitles
  URL_RE = /https?:\/\/\S+\.\S+/
  TITLE_RE = /<title>(?<title>.*)<\/title>/m

  class << self
    def title(html)
      matches = TITLE_RE.match html
      matches ? matches[:title].gsub(/\R/,' ').strip : nil
    end

    def get_uri(uri, redirect_limit=10)
      result = nil

      unless redirect_limit == 0
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 10
        http.read_timeout = 10
        http.use_ssl = uri.instance_of? URI::HTTPS

        request = Net::HTTP::Get.new uri
        response = http.request request

        Rockbot.log.debug { "Response code #{response.code}" }
        case response
        when Net::HTTPSuccess
          result = response
        when Net::HTTPRedirection
          redirect = response['location']
          Rockbot.log.debug { "Redirected to #{redirect}" }
          result = get_uri(URI(redirect), redirect_limit - 1)
        end
      end

      result
    end

    def load
      Rockbot::Event.add_hook(Rockbot::MessageEvent) do |event, server, config|
        matches = URL_RE.match event.content
        if matches
          Rockbot.log.debug { "Captured URL #{matches[0]}" }

          uri = URI(matches[0])

          response = get_uri uri
          if response
            type = response['Content-Type']
            Rockbot.log.debug { "type=#{type}" }
            title_text = title response.body if type == 'text/html'

            if title_text
              server.send_msg(
                event.channel,
                "(#{event.source.nick}) ^ #{title_text}"
              )
            end
          end
        end
      end

      Rockbot.log.info "URL Titles plugin loaded"
    end
  end
end

UrlTitles.load
