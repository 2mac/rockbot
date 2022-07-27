rockbot plugin development
==========================

This document will explain the parts of a rockbot plugin and the interfaces you
will use in creating one.

Structure
---------

To avoid namespace clashes with the core program, all your plugin logic should
be contained within its own module (or modules, if your plugin is complex
enough). Then, at the bottom of the file, you should make a call to your
plugin's setup logic. A typical plugin will look something like this:

``` ruby
module MyPlugin
  # interesting plugin things omitted

  def self.load
    # setup logic omitted
  end
end

MyPlugin.load
```

Event Hooks
-----------

Whenever an `Event` occurs, rockbot will search for any hooks set up to capture
and process it. It passes each of these hooks three parameters:

1. `event`: the `Event` itself;
2. `server`: the `IRC::Server`, which is used for sending responses back to
   the server; and
3. `config`: the application configuration

To hook an event, simply add a new hook to the specific type of event. For
instance, if we wanted to capture incoming messages, we would write:

``` ruby
Rockbot::MessageEvent.add_hook do |event, server, config|
  # do something with the message here
end
```

At the end of this document, you can find an exhaustive list of the different
events to which you can hook.

Commands
--------

A rockbot command is just a message that happens to be formatted in a specific
way. Usually this will come in the form of `,command`, but this is not always
the case. rockbot is internally aware of the different forms that a command
might take, and it will parse them to provide a consistent format for plugins
to work with.

Adding a new command to rockbot is much like adding an event hook, but it
requires a few more parameters. Namely, the name of the command, any aliases it
might have, and optionally some help text.

``` ruby
my_cmd = Rockbot::Command.new('mycommand', ['mycmd', 'myc']) do |event, server, config|
  # process the command
end
my_cmd.help_text = 'this will be shown to users when they ask for it'
Rockbot::Command.add_command my_cmd
```

This creates a new command which will respond to `mycommand`, `mycmd`, and
`myc`. We don't need to bother writing the name of the command in the
`help_text`; the `help` command will insert that for us.

The block passed to `Command.new` will be used as a hook for this command when
it is received. `server` and `config` are the same as any regular event hook,
and `event` is a `CommandEvent` which contains some useful attributes you can
use:

- `source`: the source of the command (see `MessageEvent#source` below for
  details);
- `channel`: which channel the command was received from;
- `command`: the name of the command as it was given by the user
- `args`: the rest of the input that came after the command name

Configuration
-------------

rockbot has a JSON config file which you are allowed to read from and write to
as a plugin developer. When reading from the config, you may simply treat it
like a `Hash` and read its members. When writing, however, you should use its
`edit` method and do all configuration updates in a block. This is because
`Event`s are each processed in their own thread, so the config file needs to be
protected from concurrent writes.

``` ruby
config.edit do
  config['myplugin']['myproperty'] = new_value
end
```

After the block is finished, the changed configuration will be immediately
written to the disk before any other event hook is allowed to touch it.

Database
--------

rockbot provides a SQLite database for plugins to use, which is usually more
handy than the config file. It is accessed similarly to editing the config:

``` ruby
Rockbot.database do |db|
  # access the database with db here
end
```

HTTP
----

If your plugin requires an HTTP GET request, pass a `URI` to `Rockbot.get_uri`,
which will account for HTTP redirects and has a request timeout.

Logging
-------

rockbot uses the standard Ruby `logger` library for logging. Access the logger
object with `Rockbot.log`.

Appendix A: Event Types
-----------------------

In this section, we will list all the event types and which attributes will be
available in the `event` object passed to your hooks.

### `JoinEvent` and `PartEvent`

These events represent joining or parting a channel.

Attributes:

- `source`: the `IRC::User` who joined or parted
- `channel`: the channel which was joined or parted

### `MessageEvent`

This event represents an incoming chat message, either from a channel or a
private message.

Attributes:

- `source`: the `IRC::User` from whence this message came. This `source` is
  split into the three parts `nick`, `username`, and `host`, which are
  attributes of the `source` object
- `channel`: the channel to which the message was sent
- `action?`: whether this message was an action (i.e. `/me`)
- `content`: the message text
- `command?(server, config)`: tells whether this message is a command

### `NickEvent`

This event represents a nick change.

Attributes:

- `source`: the `IRC::User` who changed nicks (their previous identity)
- `nick`: the new nick

Appendix B: The `server` Object
-------------------------------

Most plugins will need to make use of the `server` object passed to each event
hook in order to do anything useful or interesting for the other IRC users,
such as sending response messages. The `server` object has purpose-built
methods for common IRC tasks.

Attributes:

- `nick`: rockbot's current nick. Do **not** directly set a new value to this
  attribute. Use `set_nick` instead.

Methods:

- `join(channels)`: join one or more channels
- `part(channels)`: leave one or more channels
- `send_msg(target, content)`: send a chat message to `target` (a channel or
  user)
- `send_notice(target, content)`: send an IRC NOTICE to `target`
- `set_nick(nick)`: ask the server to change rockbot's nick. If successful,
  this will generate a `NickEvent`.
