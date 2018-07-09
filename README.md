Peekaygee
===========================================================================

Peekaygee is a framework for quickly creating a package distribution service. It is an open-source alternative to services like packagecloud.io and accomplish the same general goals of making it easy to publish packages for various package managers in various ways.

There are a few things to note up front:

1. It's a framework. If you don't like frameworks (and I personally don't, so I don't blame you if you don't either), you might not enjoy this project that much.
2. I didn't specify what _kind_ of packages the service will distribute because I'd like that to be user definable. I'm building it to ship both public and private debian packages, but the fundamentals of providing a centrally-accessible package archive (like packagist for php, npmjs.org for javascript, maven for java, etc.) probably won't change much between specific types of packages, and those changes can be easily encapsulated.
3. It's a distribution service, not a packaging service. It's predicated on the idea that you'll build your own packages, then _publish_ them to a defined location using this service. The service is actually built to make _publishing_ easy, not packaging.


## Installation

Since `peekaygee` is actually a composite of several different components, installation isn't quite as straightforward as I'd like. The following questions may help you out:

* Are you setting up your package server? Install `peekaygee-archive` using the `peekaygee-server` package.
* Are you setting up your local machine to push to a `peekaygee` server? Install `peekaygee` using the `peekaygee-client` package.
* Which types of packages will you be serving out of your package server?
    * Debian packages (apt repo)? Install `peekaygee-client-apt` on your local machine and `peekaygee-server-apt` on your server.
    * npm, composer, gem or other types? Currently no other types of packages are supported (but you can make workers for whatever type you need!)

Once you've got everything installed, you'll have to make sure you've got the correct permissions for publishing packages on your server, as well as the appropriate peekaygee config files on both server and client, which may include a global config files in `~/.config/peekaygee/`, repo-specific config in the repo root (for clients), and archive-specific config (for servers) at the archive root. Config files on the server are named `peekaygee-archive.json`, while config files on the client are named `peekaygee.json`.

With all that in place, you can start pushing packages.


## Usage

As mentioned above, `peekaygee` is a client/server system. It comprises the following scripts:

* `peekaygee-archive` -- a utility that handles functions like initializing an archive and answering queries from clients about the capacities of the archive server
* `peekaygee` -- the client utility that reads local config files and attempts to push files and commands to one or more remote archive servers.

### Server

To set up a `peekaygee` archive server, you might follow steps similar to this:

1. Install the `peekaygee-server` package: `sudo apt-get install peekaygee-server`.
2. Initialize an archive: `sudo peekaygee-archive init ([path])`. This creates the path, if it doesn't already exist, and structures it according to `peekaygee` conventions.
3. You might also want to install some extra `peekaygee` workers: `sudo apt-get install peekaygee-srvworker-npm peekaygee-srvworker-composer peekaygee-srvworker-maven peekaygee-srvworker-pacman` (hypothetical) on the server.

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

From there, you can simply run `peekaygee push main`, meaning, "push any recognzed packages in the `build` directory to the remote archive server named `main`." This would work, assuming you've already set up your user configuration to define a `main` server.

A configuration for this might look like so:

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
            "match": ".*\\.deb$",
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
* `peekaygee list [remote] ([type]) ([package-spec])` -- List packages on the given remote, optionally filtered by `type` and `package-spec`


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


## Archive Structure

Peekaygee archives have a very specific filesystem arrangement to facilitate all of the functions that they support. Here is the basic tree, with example archives for apt, npm, and packagist (though there could equally be more, less or different archives):

```sh
packages.peekaygee.org/
├── incoming
├── srv-config
└── webroot
    ├── index.html
    ├── [name]-archive-keyring.gpg
    ├── private
    │   ├── apt
    │   │   └── [vendor-structure]
    │   ├── npm
    │   │   └── [vendor-structure]
    │   └── packagist
    │       └── [vendor-structure]
    └── public
        ├── apt
        │   └── [vendor-structure]
        ├── npm
        │   └── [vendor-structure]
        └── packagist
            └── [vendor-structure]
```

And here's an explanation of some of the files and directories:

1. `incoming` directory -- This is the directory used by the `peekaygee` client program to place incoming packages and instruction files for the `peekaygee-archive` utility to handle.
2. `srv-config` directory -- A directory containing machine- and user-generated server configuration files, such as apache and nginx virtualhost definitions.
3. `webroot` directory -- The publicly accessible root of the archive wbsite.
4. `webroot/index.html` -- A simple index file that may be used or discarded at will. It serves as a place where you can explain the archive and what it contains, and also serves to hide the supposedly-password-protected 'private' directory.
5. `webroot/[name]-archive-keygring.gpg` -- The public gpg key used to sign packages in this archive.
6. `webroot/private` -- A container for all password-protected private packages.
7. `webroot/public` -- A container for all publicly-available packages.

This is the structure that's created with `peekaygee-archive init ([path])` (minus the vendor-specific directories, which are created the first time a vendor worker runs on the archive).


## Configuration Options

### peekaygee.json

This suite of config files controls behavior of the `peekaygee` client (used on your local computer to manage remote repositories). `peekaygee.json` files are searched for in the following locations (4 overrides 3, etc...):

1. `/etc/peekaygee/peekaygee.json`
2. `/etc/peekaygee/peekaygee.json.d/` (filenames under this directory are arbitrary)
3. `~/.config/peekaygee/peekaygee.json`
4. `$PWD/peekaygee.json`

Here's a full example using every possible config option (at the time of this writing):

```json
{
    "remotes": {
        "production": {
            "url": "my-server.com:/srv/www/packages.my-server.com",
            "package-opts": {
                "apt": {
                    "force": true
                }
            }
        }
    },
    "build-dirs": ["build"],
    "packages": {
        "deb": {
            "type": "deb",
            "match": ".*\\.deb$",
            "visibility": "private",
            "options": {
                "dists": ["bionic","xenial"]
            }
        }
    }
}
```

Explanations:

>
> **Note:** options marked "required" need to be present in _some_ config file, not _all_ config files.
>

**remotes** (required) -- An object containing remote archive specifications.

**remotes.[name].url** (required) -- The url of the remote. May be a local path or an ssh-formatted remote path.

**remotes.[name].package-opts** (optional) -- A collection of additional options to apply on a per-remote basis when pushing packages. In this example, I'm enabling "force" mode when pushing debian packages to my "production" archive, even though it is not normally enabled by the options defined in the "apt" package specification. (See `packages.[name].options` below for more details.)

**build-dirs** (required) -- An array of directories to search for built files. May be relative or absolute, but must be local.

**packages** (required) -- A list of package specifications. While normally keys in this list will match their "type" parameters, this is not always the case. For example, in a certain project that contains both public and private package builds, I may null out the default "deb" package specification and replace it with "deb-public" and "deb-private", using the "match" key to select the correct packages for each.

**packages.[name].type** (required) -- Which type of packages match this specification. While technically this may be anything, your package server must have a `peekaygee-srvworker-[type]`
worker application installed and in its path, and it must have config that teaches it how to handle packages of that type. Normally this will be something like `deb`, `npm`, `rpm`, etc...

**packages.[name].match** (required) -- A regex used to find all packages that are governed by this package profile. This is used directly with `egrep`.

**packages.[name].visibility** (optional, default "public") -- Either "public" or "private". This defines whether the package will be published in the public section or the private section of your repository.

**packages.[name].options** (optional) -- This is an arbitrary, worker-specific options hash that's passed along inline to the worker on the server. It may be used for anything, but in the case of debian packages, it's used to specify the releases (`dists`) the package should be published for and whether or not to forcefully replace a package that already exists in the given version at the server. Options for this hash are not well defined or documented yet....


### peekaygee-archive.json

This suite of config files controls behavior of the `peekaygee-archive` agent (used on remote machines to manage repositories there). `peekaygee-archive.json` files are searched for in the following locations (4 overrides 3, etc...):

1. `/etc/peekaygee/peekaygee-archive.json`
2. `/etc/peekaygee/peekaygee-archive.json.d/` (filenames under this directory are arbitrary)
3. `~/.config/peekaygee/peekaygee-archive.json`
4. `$ARCHIVE_ROOT/peekaygee-archive.json`

Here's a full example using every possible config option (at the time of this writing):

```json
{
    "archives": [
        {
            "path": "/srv/www/packages.my-server.com"
        }
    ],
    "packages": {
        "deb": {
            "type": "deb",
            "match": ".*\\.deb$"
        }
    }
}
```

You'll notice that these options are very similar to the client-side `peekaygee.json` options. Technically, these two suites of config files overlap, so configs from `peekaygee.json` that appear here are semantically identical. Explanations:

>
> **Note:** options marked "required" need to be present in _some_ config file, not _all_ config files.
>

**archives** (optional) -- An array of archives on this machine. Currently, the only property is `path`, though that may grow later. If this is not specified anywhere global, then the `peekaygee-archive update` command won't work without a specific archive given as an argument.

**archives.[name].path** (required) -- The path of the archive. Required if "archives" array given, as this is the only defining property of an archive specification.

**packages** (required) -- A list of package specifications. While normally keys in this list will match their "type" parameters, this is not always the case. See the same property in `peekaygee.json` for more information.

**packages.[name].type** (required) -- Which type of packages match this specification. While technically this may be anything, your package server must have a `peekaygee-srvworker-[type]`
worker application installed and in its path, and it must have config that teaches it how to handle packages of that type. Normally this will be something like `deb`, `npm`, `rpm`, etc...

**packages.[name].match** (required) -- A regex used to find all packages that are governed by this package profile. This is used directly with `egrep`.

