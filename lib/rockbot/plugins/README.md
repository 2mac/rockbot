rockbot plugins
===============

These plugins are included with rockbot. Add them to your config if you would
like to use them.

admin
-----

This plugin contains administrative functions such as joining channels,
changing nick, and managing the ignore list.

magic8
------

This plugin adds the `8ball` command which responds with typical magic 8 ball
yes/no answers.

poll
----

This plugin adds a polling system. Users can create and vote on polls with
arbitrary vote choices.

Requires `database` to be configured.

roll
----

This plugin adds the `roll` command for rolling dice and `coin` command for
flipping coins.

sed
---

This plugin allows `sed`-style string substitutions. Example:

```
<user> beep
<user> s/e/o/g
<rockbot> Correction: <user> boop
```

seen
----

This plugin reads incoming messages and logs the last message per user in each
channel. Later, these messages can be recalled with the `seen` command.

Requires `database` to be configured.

tell
----

This plugin adds a stored message function to rockbot. Users can store messages
with `tell <nick> <message>`, and `nick` will be delivered the message the next
time they are active. To avoid flooding, rockbot will not send the message to
the channel when there are multiple messages in the queue for a returning
user. Instead, that user will be prompted to use `showtells`, in which case
rockbot will deliver all pending messages in private.

Requires `database` to be configured.

URL titles
----------

This plugin scans incoming messages for URLs. If it finds one, it queries it
and scans the contents for a title. If one is found, it puts that title into
the channel for others to see before they click.

YouTube
-------

This plugin adds a command to search for YouTube videos.
