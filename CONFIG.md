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

rockbot looks for the config in each of the following locations, whichever it
finds first:

- `./rockbot.json`

Alternatively, you may provide a config file as a command line argument.

    $ rockbot.rb config.json

The available options are as follows:

- `auth` - Authentication info. See below for details.
- `channels` - A list of channels to join.
- `command_char` - The character by which rockbot will recognize a command
  originating from IRC. (default: `,`)
- `database` - Path to the database file.
- `ignore` - A list of nicks for whom to ignore incoming messages.
- `log_level` - Sets the verbosity of program logging. One of DEBUG, INFO,
  WARN, ERROR. (default: INFO)
- `log_file` - A file to which logs will be written. If this is unset, logs
  will be sent to the console.
- `ops` - A list of users from which to accept admin commands.
- `nick` - IRC nick for this instance of rockbot.
- `ping_timeout` - Disconnect from the server if we've heard nothing for this
  many seconds. (default: 300)
- `plugin_path` - A list of directories in which to search for plugins.
- `plugins` - A list of plugins to load by name or file.
- `retries` - Number of times to reconnect to the server after an error.
  (default: 10)
- `server` - Hostname and port number for the IRC server, formatted as
  `host/port`.
- `secure` - If this option is set to any value but `false` or `null`, use
  SSL/TLS encryption for the server connection.

`auth`
------

The `auth` option is used for logging into networks with nick
registration. rockbot currently supports the SASL PLAIN mechanism. It is set up
as follows:

    {
        "auth": {
            "type": "sasl",
            "user": "<username>",
            "pass": "<secret_password>"
        }
    }
