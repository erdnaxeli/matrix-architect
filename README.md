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
  * `!room delete <room id>`
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

You can join the discussion at [#matrix-architect:cervoi.se](https://cervoi.se/element/#/room/#matrix-architect:cervoi.se).

## Installation

### Static build

~You can download a static build from the [releases](https://github.com/erdnaxeli/matrix-architect/releases) page.~ well actually this is not live yet

### Docker

You can use the provided `Dockerfile` to build a docker image, or use the already built one (see the usage section for more details):
```
docker run --init -v $PWD/config.yml:/app/config.yml erdnaxeli/matrix-architect
```

### From source

If you want to build it yourself you need to [install Crystal](https://crystal-lang.org/install/) 0.35, then clone the code, go to the new folder and:

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

Set the configuration:

1. Create a new account for the bot on your HS, with your favorite client
2. Log out (to discard any e2e key that would have been created)
4. Set the new created account as
[admin](https://github.com/matrix-org/synapse/tree/master/docs/admin_api).
3. Run `./matrix-architect gen-config`

Run the bot with `./matrix-architect`. If you let the log level to "info" you should
see some messages.

You can now talk to the bot on Matrix!

### With docker

The commands are a little bit different:
```
# create an empty config file so we can mount it in the docker container
touch config.yml
# generate the config
docker run -it --rm --init -v $PWD/config.yml:/app/config.yml erdnaxeli/matrix-architect gen-config
# run the bot
docker run --init -v $PWD/config.yml:/app/config.yml erdnaxeli/matrix-architect
```

The bot does not register any signal handlers, so the `--init` parameter is mandatory
if you want it to respond correctly to `^C` or `docker stop`.

## Security consideration

This bot use the Synapse's admin API (everything under `/_synapse/admin`).
Although only admin users can use this API, make it available to the whole Internet
is not recommanded. You probably want to run the bot on the same host as your
Synapse instance and communicate through localhost (or you can use a private network).

Note that the domain used to talk to Synapse is your (public) homeserver domain,
so it means that (for example) if you want to access to the admin API on localhost
only you need to have your homeserver domain resolves to `localhost` (by adding an
entry to `/etc/hosts`). The public API (everything under `/_matrix`) must also be
accessible on the same domain and IP.

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
* Test the code

## Contributors

- [erdnaxeli](https://github.com/erdnaxeli) - creator and maintainer
