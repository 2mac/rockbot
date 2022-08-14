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

module Rockbot
  ##
  # Represents a rockbot command.
  class Command
    @commands = {}

    class << self
      ##
      # Registers a new command.
      #
      # _command_ should be an instance of Command.
      def add_command(command)
        @commands[command.name] = command
      end

      ##
      # Looks up a Command by name or alias in the registry.
      #
      # Returns the Command or +nil+ if it could not be found.
      def from_name(name)
        @commands.each do |key, command|
          return command if name == key || command.aliases.include?(name)
        end

        nil
      end

      ##
      # Array of all registered rockbot commands.
      def commands
        @commands.values
      end
    end

    ##
    # The help text for this command.
    attr_accessor :help_text

    ##
    # The name of this command.
    attr_reader :name

    ##
    # Array of aliases for this command.
    attr_reader :aliases

    ##
    # Create a new command with the name _name_. An array of _aliases_ may
    # optionally be provided. The block given will be invoked each time this
    # command is received.
    def initialize(name, aliases=[], &block)
      @name = name
      @block = block
      @aliases = aliases
    end

    ##
    # Invoke this command.
    #
    # _event_ should be a CommandEvent that was received.
    #
    # _server_ is the IRC::Server to which rockbot is connected.
    #
    # _config_ is the application Config.
    def call(event, server, config)
      @block.call(event, server, config)
    end
  end

end
