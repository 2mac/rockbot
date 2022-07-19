rockbot configuration
=====================

The configuration file is written as a JSON object with various keys, e.g.

    {
        "log_level": "INFO",
        "nick": "my_irc_bot",
        "server": "my.ircd.net/6667",
        "channels": [
            "#rockbot"
        ]
    }

The available options are as follows:

- `channels` - A list of channels to join, formatted as a JSON array.
- `command_char` - The character by which rockbot will recognize a command
  originating from IRC.
- `log_level` - Sets the verbosity of program logging. One of DEBUG, INFO,
  WARN, ERROR. (default: INFO)
- `log_file` - A file to which logs will be written. If this is unset, logs
  will be sent to the console.
- `nick` - IRC nick for this instance of rockbot.
- `server` - Hostname and port number for the IRC server, formatted as
  `host/port`.
