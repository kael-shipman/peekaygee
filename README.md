Peekaygee
===========================================================================

Peekaygee is a framework for quickly creating a package distribution service.

Let's unpack that:

1. It's a framework. If you don't like frameworks (and I personally don't, so I don't blame you if you don't either), you might not enjoy this project that much.
2. I didn't specify what _kind_ of packages the service will distribute because I'd like that to be user definable. I'm building it to ship both public and private debian packages, but the fundamentals of providing a centrally-accessible package archive (like packagist for php, npmjs.org for javascript, maven for java, etc.) probably won't change much between specific types of packages, and those changes can be easily encapsulated.
3. It's a distribution service, not a packaging service. It's predicated on the idea that you'll build your own packages, then _publish_ them to a defined location that this service will watch and process. The service is actually built to make _publishing_ easy, painless and robust, not packaging.


## Installation

Since `peekaygee` is actually a composite of several different components, installation isn't quite as straightforward as I'd like. The following questions may help you out:

* Are you setting up your package server? Install `peekaygeed` and related files (systemd files, etc.) from this package.
* Are you setting up your local machine to push to a `peekaygee` server? Install `peekaygee` from [peekaygee-client](https://github.com/kael-shipman/peekaygee-client).
* Which types of packages will you be serving out of your package server?
    * Debian packages (apt repo)? Install `peekaygee-client-apt` on your local machine and `peekaygee-server-apt` on your server.
    * Other types? Currently no other types of packages are supported (but you can make workers for whatever type you need!)

Once you've got everything installed, you'll have to create a server configuration on your server at `/etc/peekaygeed/config.json` and at least one of the following on your local machine: a system-wide default config file at `/etc/peekaygee/config.json`, a user config file at `~/.config/peekaygee/config.json`, and repo-specific configs at `[repo-root]/peekaygee.json` (with optional local overrides at `[repo-root]/peekaygee.local.json`).

With all that in place, you can start the `peekaygeed` daemon on the server (usually using `systemctl enable --now peekaygeed.service`), then push to it using the `peekaygee` client.


## Usage

As mentioned above, `peekaygee` is a client/server system. It comprises the following scripts:

* `peekaygee-archive` -- a utility that handles functions like initializing an archive and answering queries from clients about the capacities of the archive server
* `peekaygee` -- the client utility that reads local config files and attempts to push files and commands to one or more remote archive servers.

### Server
To set up a `peekaygee` archive server, you might follow steps similar to this:

1. Install the `peekaygee-server` package: `sudo apt-get install peekaygee-server`. This provides a global config directory at `/etc/peekaygee-server` as well as the `peekaygee-archive` utility.
2. Initialize an archive: `sudo peekaygee-archive init ([path])`. This creates the path, if it doesn't already exist, and structures it according to `peekaygee` conventions. It also creates a config file for the archive at `/etc/peekaygee-server/config.json.d/[basename]`.
3. You might also want to install some extra `peekaygee` workers: `sudo apt-get install peekaygee-npm-worker peekaygee-composer-worker peekaygee-maven-worker peekaygee-pacman-worker` (hypothetical)

Once set up, you can manually run `peekaygee-archive update` to check for changes. You can also put this in a systmed timer file (or cronjob) to regularly check for changes, though theoretically it wouldn't be necessary, since the `peekaygee` client will call this as the final step of any push.

### Client

On the client side, you'll usually be developing a number of projects in their own separate repos, and you'll probably want to package releases of these projects and push them to one or more of your configured servers.

Consider this example repo:

```sh
my-project/
├── build
├── docs
├── LICENSE.md
├── package.json
├── README.md
├── scripts
│   └── build.sh
├── src
└── tests
```

We see from the presence of a `package.json` file that this is a node project. Presumably the `scripts/build.sh` script would compile the final product into a "binary" in the `build` directory.

From there, you can simply run `peekaygee push main`, meaning, "push any recognzed packages in the `build` directory to the remote archive server named `main`." This would work, assuming you've already set up your global configuration to define a `main` server.

A global configuration for this might look like so:

```json
{
    "remotes": {
        "main": {
            "url": "my-server.com:/srv/www/packages.my-server.com"
        },
        "local-test": {
            "url": "192.168.56.101:/srv/www/packages.my-server.com"
        }
    },
    "build-dirs": ["build"],
    "packages": {
        "apt": {
            "match": ".*\.deb$",
            "type": "apt",
            "visibility": "private",
            "options": {
                "releases": ["bionic"]
            }
        }
    }
}
```

As you can see here, we've defined several remotes, "main" and "local-test". We specify one of those as the first argument to `push` and other commands. Next we've defined a build directory (though we could have defined several). This is how `peekaygee` knows where to look for built packages to push. Finally, we've defined a "packages" object whose keys are arbitrary string descriptions of the packages they match.

Package rulesets have only four keys: the required `type` and `match` keys, and the optional `visibility` and `options` keys. They are defined as follows:

* `type`: What type of package this is. This is used to match a `peekaygee-[type]-worker` on the remote.
* `match`: an egrep-compatible regex used to find matching package files in the build directories.
* `visibility`: used to determine whether the package should be placed in the publicly-available section of the repo or in the password-protected private section (defaults to "public").
* `options`: type-specific options passed along to the worker on the remote.

When you call `peekaygee push`, `peekaygee` will search for all packages according to the `build-dirs` directive and the `packages` rules. For relative `build-dirs` (which is the most common case), it will naïvely append the given paths to the current working directory and search for package matches there (if existing). It finds matches by iterating through all package definitions and comparing found files against the definition's `match` directive. For all matches, it will then verify that the requested remote can handle the package type, compose a manifest file containing some meta information, as well as the `visibility` value and the `options` block and upload everything to the server. Finally, to complete the process, it will call `peekaygee-archive update` on the remote.

### Actions Available

At the time of this writing, `peekaygee` was designed to facilitate the pushing of packages to an archive server (possibly overwriting package versions that are already there), the listing of available packages and their versions, and the deletion of packages or package versions from the archive. These actions are accessed as follows:

* `peekaygee push [remote]` -- Push any available packages to the given remote
* `peekaygee delete [remote] [package spec]` -- Delete packages matching `package-spec` from the given remote
* `peekaygee prune [remote] ([package-spec]) [num-versions]` -- Delete old versions of packages from remote, leaving only `num-versions` of each (optionally filtering by `package-spec`)
* `peekaygee list [remote] ([type])` -- List packages on the given remote, optionally filtered by `package-spec`


## Design Goals

The framework aims to simplify two specific elements of the process of publishing packages.

First, it aims to provide an out-of-the-box strategy for laying out a public package archive webservice, some of which may be password-protected (using basic HTTP Auth). This involves creating a filesystem layout for the package archive that accounts for all of the various usecases, such as:

* multiple distinct types of packages (javascript, php, java, deb, rpm, C, etc.).
* multiple hardware architectures (in the case of OS packages)
* multiple levels of arbitrary fragmenting (many OSes silo packages into OS version-specific archives to improve stability)
* multiple levels of stability (stable, development, testing, experimental, etc.)
* public vs password protected

The actual repo maintenance tools are expected to manage a good degree of this complexity themselves. The default setup of this service will employ `reprepro`, for example, to arrange a debian repo in a way that works for the `apt` dependency management system.

Some of it, however, will be handled by convention (that's the framework part of the system). In the next sections, we'll go over the general architecture of the system and some of the conventions that make it work.


## System Architecture

The first thing to note about the system is that it has two parts: a server-side repo maintainer (provided by this codebase and other peekaygee-compatible workers) and a lighter weight client-side pusher (provided by [peekaygee Client](https://github.com/kael-shipman/peekaygee-client).

On the server side, the master process, `peekaygeed`, is usually started on boot, runs as root, and watches directories defined in `/etc/peekaygee/config.json` (more on config further down). On the client side, peekaygee is used as a one-off command and reads a repo-specific config file, `peekaygee.json`.

### Package Types

You can already see that handling different types of packages can quickly become a huge logistical headache for a single program. That's why `peekaygee` takes a "master/worker" approach.

On both the client and the server, the master process parses everything and does all the sanity checks, while a type-specific worker is responsible for doing the work of publishing each individual package. On the client side, this involves pushing the right files into the right places on the server so that the server can pick them up. On the server side, it involves parsing the directory structures created by the client and inserting the packages into their official repos.

This master/worker, together with conventions for identifying workers, allows `peekaygee` to support any arbitrary package type, even types that are yet to be conceived. All you have to do to is name the binary correctly and `peekaygee` will identify it as a worker and call on it to do its work.


## Unit Tests

`peekaygee` uses [`bash_unit`](https://github.com/pgrange/bash_unit) for unit testing. To run tests, install bash-unit (see `bash_unit` readme), then run `bash_unit tests/*` from the repo root.

