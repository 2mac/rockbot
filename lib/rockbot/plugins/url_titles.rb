# coding: utf-8
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

require 'cgi'

module UrlTitles
  URL_RE = /https?:\/\/\S+\.\S+/
  TITLE_RE = /<title>(?<title>.*?)<\/title>/m
  MAX_LENGTH = 100
  FETCHERS = []

  ENTITY_RE = /&([a-z]+);/
  ENTITY_MAP = {
    'bull' => '•',
    'horbar' => '―',
    'mdash' => '—',
    'ndash' => '–'
  }

  class Fetcher
    attr_reader :pattern

    def initialize(pattern, &block)
      @pattern = pattern
      @block = block
    end

    def fetch(uri, config)
      @block.call(uri, config)
    end
  end

  class << self
    def title(html)
      matches = TITLE_RE.match html
      text = matches ? matches[:title].gsub(/(\R|&nbsp;)/,' ').strip : nil
      if text
        text = CGI.unescapeHTML(text).force_encoding(Encoding::UTF_8)

        while matches = ENTITY_RE.match(text)
          decoded = ENTITY_MAP[matches[1]] || '?'
          text.gsub!(matches[0], decoded)
        end

        if text.length > MAX_LENGTH
          text = text[0, MAX_LENGTH]
          index = text.rindex ' '
          text = text[0, index] if index
          text << '…'
        end

        text.strip!
        text = nil if text.empty?
      end

      text
    end

    def fetch(uri)
      response = Rockbot.get_uri uri
      type = response['Content-Type']
      Rockbot.log.debug { "type=#{type}" }
      if type.include? 'text/html'
        text = title response.body
        text = text ? Rockbot::IRC.format("<b>#{text}</b>") : 'No title found'
      end

      text
    end

    def load
      Rockbot::MessageEvent.add_hook do |event, server, config|
        unless event.command?(server, config)
          matches = URL_RE.match event.content
          if matches
            url = matches[0]
            if i = url.index('>')
              url = url[0...i]
            end

            Rockbot.log.debug { "Captured URL #{url}" }

            uri = Rockbot.format_uri(url)

            begin
              response = nil
              FETCHERS.each do |fetcher|
                begin
                  if fetcher.pattern =~ uri.to_s
                    response = fetcher.fetch(uri, config)
                    break
                  end
                rescue => e
                  Rockbot.log.error e
                end
              end

              unless response
                response = fetch uri
              end
            rescue => e
              Rockbot.log.error "Error fetching #{matches[0]}"
              Rockbot.log.error e
            end

            if response
              server.send_msg(
                event.channel,
                "(#{event.source.nick}) ^ #{response}"
              )
            end
          end
        end
      end

      Rockbot.log.info "URL titles plugin loaded"
    end
  end
end

UrlTitles.load
