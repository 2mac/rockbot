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
require 'pathname'

module Rockbot
  ##
  # Represents the application configuration file.
  class Config
    # Contains the default config options.
    DEFAULT_CONFIG = {
      'command_char' => ',',
      'ignore' => [],
      'log_level' => 'INFO',
      'ops' => [],
      'ping_timeout' => 300,
      'plugins' => [],
      'plugin_path' => [],
      'quit_msg' => '',
      'retries' => 10
    }

    ##
    # Create a new Config from a file path.
    def initialize(path)
      config = {}

      unless File.file? path
        raise "Config file #{path} not found"
      end

      @path = path

      file = File.open path
      config_text = file.read
      file.close

      config = JSON.parse config_text
      unless config.kind_of? Hash
        raise 'Configuration is not a JSON object'
      end

      @data = DEFAULT_CONFIG.merge config

      @write_mutex = Thread::Mutex.new
    end

    ##
    # Validate this Config to make sure all required parameters are accounted
    # for.
    #
    # Returns true if the configuration is valid.
    def validate
      valid = true
      required_params = [
        'nick',
        'server',
        'command_char'
      ]

      required_params.each do |param|
        if @data[param].nil? || @data[param].empty?
          Rockbot.log.error "Required configuration \"#{param}\" is missing!"
          valid = false
        end
      end

      unless /\S+\/\d+/ =~ @data['server']
        Rockbot.log.error "Server string is improperly formatted!"
        valid = false
      end

      valid
    end

    ##
    # Edit the configuration in a thread-safe manner. The Config object can be
    # safely written to within the block passed to this method. After the block
    # finishes, the configuration will be saved to the disk.
    def edit
      begin
        @write_mutex.lock

        result = yield
        File.open(@path, "w") { |f| f.puts JSON.pretty_generate(@data) }
      ensure
        @write_mutex.unlock
      end

      result
    end

    def dir # :nodoc:
      Pathname.new(@path).dirname.realpath
    end

    ##
    # Gets the config option indicated by _key_.
    def [](key)
      @data[key]
    end

    ##
    # Sets the config option _key_ to _value_. This should only be used with
    # Config#edit.
    def []=(key, value)
      @data[key] = value
    end
  end
end
