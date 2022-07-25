rockbot plugins
===============

These plugins are included with rockbot. Add them to your config if you would
like to use them.

admin
-----

This plugin contains administrative functions such as joining channels,
changing nick, and managing the ignore list.

seen
----

This plugin reads incoming messages and logs the last message per user in each
channel. Later, these messages can be recalled with the `seen` command.

URL titles
----------

This plugin scans incoming messages for URLs. If it finds one, it queries it
and scans the contents for a title. If one is found, it puts that title into
the channel for others to see before they click.
