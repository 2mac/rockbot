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

tell
----

This plugin adds a stored message function to rockbot. Users can store messages
with `tell <nick> <message>`, and `nick` will be delivered the message the next
time they are active. To avoid flooding, rockbot will not send the message to
the channel when there are multiple messages in the queue for a returning
user. Instead, that user will be prompted to use `showtells`, in which case
rockbot will deliver all pending messages in private.

URL titles
----------

This plugin scans incoming messages for URLs. If it finds one, it queries it
and scans the contents for a title. If one is found, it puts that title into
the channel for others to see before they click.
