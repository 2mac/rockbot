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

require 'pathname'

require_relative 'config'
require_relative 'log'
require_relative 'util'

module Rockbot
  def self.load_plugins(config)
    config['plugins'].each { |p| load_plugin(p, config) }
  end

  def self.load_plugin(plugin_name, config)
    loaded = false

    unless plugin_name.end_with? '.rb'
      plugin_name += '.rb'
    end

    paths = config['plugin_path'] + ['plugins/']

    paths.each do |path|
      dir = Pathname.new(path)
      unless dir.absolute?
        dir = Rockbot.resolve_relative dir
      end

      plugin_file = dir.join(plugin_name)
      if plugin_file.file?
        @logger.debug { "Found #{plugin_name} at #{plugin_file.to_s}" }

        begin
          Kernel.require plugin_file
        rescue => e
          Rockbot.log.error "Error loading #{plugin_name}"
          Rockbot.log.error e
        end

        loaded = true # always set this to suppress the "failed to find" message
        break
      end
    end

    unless loaded
      @logger.error "Failed to find #{plugin_name} in the plugin path"
    end
  end
end
