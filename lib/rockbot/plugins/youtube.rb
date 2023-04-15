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

require 'date'
require 'json'

module YoutubePlugin
  BASE_URL = 'https://www.googleapis.com/youtube/v3/'
  WATCH_URL = 'https://youtu.be/'
  TIME_RE = /P((?<d>\d+)D)?T((?<h>\d+)H)?((?<m>\d+)M)?((?<s>\d+)S)?/
  YOUTUBE_URLS = /https?:\/\/(www\.)?youtu(\.be\/|be\.com\/(watch\?v=|shorts\/))(?<id>[^?&]+)/

  class << self
    def request(type, params)
      params[:key] = @key
      params = params.map { |k,v| "#{k.to_s}=#{v}" }
      url = "#{BASE_URL}#{type}?#{params.join('&')}"

      response = Rockbot.get_uri Rockbot.format_uri(url)
      JSON.parse(response.body)
    end

    def search(title)
      data = request('search', {q: title, type: 'video', part: 'snippet'})
      data.dig('items', 0, 'id', 'videoId')
    end

    def details(video_id)
      params = {
        id: video_id,
        part: 'contentDetails,snippet,statistics'
      }

      data = request('videos', params)
      data = data['items'][0]

      snip = data['snippet']
      detail = data['contentDetails']
      stats = data['statistics']

      {
        id: video_id,
        title: snip['title'],
        duration: detail['duration'],
        channel: snip['channelTitle'],
        live: snip['liveBroadcastContent'],
        views: stats['viewCount'],
        published: DateTime.iso8601(snip['publishedAt'])
      }
    end

    def format(video, include_url=false)
      Rockbot.log.debug { "Formatting #{video}" }
      result = Rockbot::IRC.format '<c:white,red> ▶ <r>'
      result << " \x02#{video[:title]}\x02"

      if video[:live] != 'none'
        result << Rockbot::IRC.format(" - <c:red><b>LIVE<r>")
      else
        m = TIME_RE.match video[:duration]

        time = " - length \x02"
        time << "#{m[:d]}d " if m[:d]
        time << "#{m[:h]}h " if m[:h]
        time << "#{m[:m]}m " if m[:m]
        time << "#{m[:s]}s" if m[:s]

        time.rstrip!
        time << "\x02"

        result << time
      end

      views = video[:views].to_s.reverse.scan(/\d{3}|.+/).join(',').reverse
      result << " - \x02#{views}\x02 views"

      result << " - \x02#{video[:channel]}\x02"

      date = video[:published]
      result << " on \x02#{date.year}.#{date.month}.#{date.day}\x02"

      result << " - " + WATCH_URL + video[:id] if include_url

      result
    end

    def lookup(event, server, config)
      @key = config['youtube']['key'] unless @key

      title = event.args.strip
      return if title.empty?

      result = search title
      if result
        video = details result
        response = format(video, true)
      else
        response = "No results found"
      end

      server.send_msg(event.channel, "(#{event.source.nick}) #{response}")
    end

    def fetch_title(uri, config)
      @key = config['youtube']['key'] unless @key

      m = YOUTUBE_URLS.match uri.to_s
      format(details(m[:id]), uri.path.start_with?('/shorts/'))
    end

    def load
      yt_cmd = Rockbot::Command.new('youtube', ['yt'],
                                    &YoutubePlugin.method(:lookup))
      yt_cmd.help_text = "Search YouTube for a video.\n" +
                         "Usage: youtube <query>"
      Rockbot::Command.add_command yt_cmd

      if Object.const_defined? 'UrlTitles'
        fetcher = UrlTitles::Fetcher.new(YOUTUBE_URLS,
                                         &YoutubePlugin.method(:fetch_title))
        UrlTitles::FETCHERS << fetcher
      end

      Rockbot.log.info "YouTube plugin loaded"
    end
  end
end

YoutubePlugin.load
