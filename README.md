# matrix-architect

A bot to manage your Synapse home server.
It uses Synapse's [admin API](https://github.com/matrix-org/synapse/tree/master/docs/admin_api)
to provides management commands.

Current state of API implementation:
* [ ] account_validity
* [ ] delete_group
* [ ] media_admin_api
* [ ] purge_history_api
* [ ] purge_remote_media
* [x] purge_room
  * `!room purge <room id>`
  * `!room garbage-collect`
* [ ] register_api
* [ ] room_membership
* [x] rooms
  * `!room count`
  * `!room details <room id>`
  * `!room list`
  * `!room top-complexity`
  * `!room top-members`
* [ ] server_notices
* [x] shutdown_room
  * `!room shutdown <room id>`
* [x] user_admin_api
  * `!user list`
  * `!user query <user id>`
  * `!user deactivate <user id>`
  * `!user reset-password <user id>`
* [x] version_api
  * `!version`

See `!help` for more details about the bot's commands.

## Installation

~You can download a static build from the [releases](https://github.com/erdnaxeli/matrix-architect/releases) page.~ well actually this is not live yet

If you want to build it yourself you need to [install Crystal](https://crystal-lang.org/install/) 0.34, then clone the code, go to the new folder and:

```
make
```

You can also build a static binary with
```
make static
```

Note that the static build (manually or from the releases) is not actually totally
static (see the [Cristal wiki](https://github.com/crystal-lang/crystal/wiki/Static-Linking)).
If you have trouble you want prefer to build yourself a not static binary.

## Usage

Setting the configuration:

1. Create a new account for the bot on your HS, with your favorite client
2. Log out (to discard any e2e key that would have been created)
4. Set the new created account as
[admin](https://github.com/matrix-org/synapse/tree/master/docs/admin_api).
3. Run `./matrix-architect gen-config`

Run the bot with `./matrix-architect`. If you let the log level to "info" you should
see some messages.

You can now talk to the bot on Matrix!

## Contributing

1. Fork it (<https://github.com/erdnaxeli/matrix-architect/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Don't forget to run `crystal tool format` on any code you commit.

Your are advised to open an issue before opening a pull request.
In that issue you can describe the context and discuss your proposal.

## TODO

Non ordered list of things I would like to do:

* Implement more API commands:
I am not sure we need all the admin API available though the bot, but it's sure we need more.
* Implement new commands:
there is probably space to implement new commands that combine different APIs,
like the garbage-collect one.
* Provide administration for bridges? That could be something useful.
* Give some love to the cli executable:
  * implement account creation in the main executable
* Test the code

## Contributors

- [erdnaxeli](https://github.com/erdnaxeli) - creator and maintainer
