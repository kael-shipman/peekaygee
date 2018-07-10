Peekaygee
===========================================================================

Peekaygee is a framework for quickly creating a package distribution service. It is an open-source alternative to services like packagecloud.io and accomplishes the same general goals of making it easy to publish packages for various package managers in various ways.

There are a few things to note up front:

1. It's a framework. If you don't like frameworks (and I personally don't, so I don't blame you if you don't either), you might not enjoy this project that much.
2. I didn't specify what _kind_ of packages the service will distribute because that's flexible. I'm building it to ship both public and private debian packages, but the fundamentals of providing a centrally-accessible package archive (like packagist for php, npmjs.org for javascript, maven for java, etc.) probably won't change much between specific types of packages, and those changes can be easily encapsulated.
3. It's a distribution service, not a packaging service. It's predicated on the idea that you'll build your own packages, then _publish_ them to a defined location using this service. The service is actually built to make _publishing_ easy, not packaging.


## Installation

Since `peekaygee` is actually a composite of several different components, installation isn't quite as straightforward as I'd like.

Since you're here, you're probably looking for an easy way to push packages that you've built locally to a remote server and have them slurped into that servers published indexes. Here's what you'll need to do:

1. Install `peekaygee` using your OS package manager (or by just places the source files in the right locations, though there are a few pesky dependencies to worry about). You can try my repo at https://packages.kaelshipman.me.
2. On your local machine, add a configuration file (you'll probably want to use `~/.config/peekaygee/peekaygee.json`) that defines one or more remotes (see Config Options below for more details).
3. On your server, install the `peekaygee-srvworker-*` package that matches the types of packages you want to server. For example, if you want to serve, debian packages, install `peekaygee-srvworker-deb`. If no `srvworker` package is available for the types of packages you want to publish, consider writing one. See `Server Worker Interface` below.
4. On your server, make sure you've got permissions set up correctly for managing and serving your archive. For example, if your archive is at `/srv/www/packages.my-site.com`, you'll probably want to do this: `sudo setfacl -Rm user:$USER:rwX,default:user:$USER:rwX /srv/www/packages.my-site.com && mkdir -p /srv/www/packages.my-site.com/webroot && sudo setfacl -Rm user:www-data:rX,default:user:www-data:rX /srv/www/packages.my-site.com/webroot`. That will give your user read/write access to everything and the webserver user r access to the web root directory.

### Type-Specific Setup

The various types may also have certain requirements. Here's what's required for Debian repositories:

* A gpg key for signing, and the resultant public key at `/webroot/[keyfile]` for download
* A reprepro configuration at `[ARCHIVE-ROOT]/webroot/{public,private}/deb/conf/`

For both of these, you can follow this useful tutorial [here](https://www.digitalocean.com/community/tutorials/how-to-use-reprepro-for-a-secure-package-repository-on-ubuntu-14-04).

Other things may be required for other types of repositories.


## Usage

As mentioned above, `peekaygee` is a client/server system. It comprises the following scripts:

* `peekaygee-archive` -- a utility that handles functions like initializing an archive, coordinating workers on the archive, and answering queries from clients about the capacities of the archive server
* `peekaygee` -- the client utility that reads local config files and attempts to push files and commands to one or more configured remote archive servers
* `peekaygee-srvworker-*` -- a general class of worker script that is called by `peekaygee-archive` to do the actual work of managing a type of archive.

### Server

You won't generally need to use the `peekaygee-archive` utility directly. While you're certainly allowed to, this utility is usually called by the `peekaygee` client-side utility when managing your archives.

All the same, if you want to, you can do things like initialize an archive (`peekaygee-archive init [path]`), manage private users for an archive (`peekaygee-archive manage-users [path]`), or update an archive (`peekaygee-archive update [path]`).

### Client

On the client side, you'll usually be developing a number of projects in their own separate repos, and you'll probably want to package releases of these projects and push them to one or more of your configured servers.

Consider this example repo:

```sh
my-project/
├── build/
├── docs/
├── LICENSE.md
├── README.md
├── pkg-src/
│   ├── deb/
│   │   └── my-project/
│   │       └── DEBIAN/
│   │           ├── config
│   │           ├── control
│   │           ├── postinst
│   │           └── templates
│   └── rpm/
│       └── my-project/
│   │       └── [some meta files....]
├── scripts/
│   └── build.sh
├── src/
│   ├── some-file.c
│   └── other-file.c
├── tests/
└── VERSION
```

We can see this is some simple C program. We can also see that we've prepared control files to build a debian package and an rpm package from this source. Now you can imagine that when we run `./scripts/build.sh`, the build script creates a `.deb` file and a `.rpm` file and drops them into `build/`.

All that is the hard part (and the part that `peekaygee` doesn't help you with). Once you've done that, though, you're ready to publish your packages to your public debian and rpm repos. You can do that by simply running `peekaygee push [your-repo]`, meaning, "push any recognzed packages in the `build` directory to the remote archive server named `[your-repo]`." Running this command would identify the two files in your build directory, check that `[your-repo]` can handle them (by running `peekaygee-archive supports [type]` on your remote server), transfer the two files to your remote server along with any package-specific options defined in your `peekaygee.json` config files, delete the built files locally, then run `peekaygee-archive update [archive]` on your remote server. That command would identify the two incoming files, then use `peekaygee-srvworker-deb add [archive] [debfile] [options]` to add the debian file, and `peekaygee-srvworker-rpm add [archive] [rpmfile] [options]` to add the rpm file. Assuming all that goes well, it would return success and your packages would be public! (Or private, depending on how you configured them).


## Configuration Options

`peekaygee` utilizes two suites of configuration files, one for the client and one for the server. A "suite" of configuration files is simply a single configuration file that may be found in various locations, each location overriding directives from previous ones.

`peekaygee`'s client and server configuration files are very similar. In fact, if the client and server happen to be the same machine, you can actually get by by simply symlinking the config files together for easier management.

Below is a description of where the files are found and the options available in each.

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


## `peekaygee` Interfaces

Following is a brief description of the interfaces of the `peekaygee` utilities. For full documentation, use the `--help` flag on each.

### `peekaygee`

* `peekaygee push [remote]` -- Push any available packages to the given remote
* `peekaygee delete [remote] [package spec]` -- Delete packages matching `package-spec` from the given remote
* `peekaygee prune [remote] ([package-spec]) [num-versions]` -- Delete old versions of packages from remote, leaving only `num-versions` of each (optionally filtering by `package-spec`)
* `peekaygee list [remote] ([type]) ([package-spec])` -- List packages on the given remote, optionally filtered by `type` and `package-spec`

### `peekaygee-archive`

* `peekaygee-archive init ([path])` -- Initialize an archive at `[path]`, or in the current working directory if `[path]` not specified.
* `peekaygee-archive manage-users ([path])` -- Manage the list of users configured to access the private part of the archive at `[path]`, or in the current working directory if `[path]` not specified.
* `peekaygee-archive supports [type]` -- Find out whether the server can support archives of type `[type]`. (This simply looks for the presence of a `peekaygee-srvworker-[type]` executable in the `PATH`).
* `peekaygee-archive update ([path])` -- Searches the `/incoming` directory of the archive at `[path]`, or of the current working directory if `[path]` is not given and the current working directory is a `peekaygee` archive, or in all configured archives if neither of the above conditions are true, and tries to incorporate any packages found into their respective archives.

### `peekaygee-srvworker-*`

This is a general interface for all compliant `peekaygee-srvworker-*` implementations. You may add support for any package type by simply implementing this interface, then making your implementation available on your path under the name `peekaygee-srvworker-[type]`. For all commands, the optional `[json-options]` argument is a json string representing arbitrary arguments for the worker. Workers themselves are responsible for validating incoming arguments.

* `peekaygee-srvworker-[type] add [archive] [package-file] ([json-options])` -- Adds `[package-file]` to `[archive]`, using options found in `[json-options]`, if available.
* `peekaygee-srvworker-[type] list [archive] [package-spec]` -- Lists packages matching `[package-spec]` in `[archive]`. This should output a list of packages as lines of the following format: `[package-name] [version] ([optional-details])`. The `[optional-details]` field may be used by workers to show more information about packages they list.


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


## Unit Tests

`peekaygee` uses [`bash_unit`](https://github.com/pgrange/bash_unit) for unit testing. To run tests, install bash-unit (see `bash_unit` readme), then run `bash_unit tests/*` from the repo root.


## Archive Structure

Peekaygee archives have a very specific filesystem arrangement to facilitate all of the functions that they support. Here is the basic tree, with example archives for apt, rpm, and packagist (though there could equally be more, less or different archives):

```sh
packages.peekaygee.org/
├── .peekaygee-version
├── incoming/
│   ├── private/
│   └── public/
├── logs/
├── srv-config/
└── webroot/
    ├── index.html
    ├── [name]-archive-keyring.gpg
    ├── private/
    │   ├── apt/
    │   │   └── [vendor-structure]
    │   ├── rpm/
    │   │   └── [vendor-structure]
    │   └── packagist/
    │       └── [vendor-structure]
    └── public/
        ├── apt/
        │   └── [vendor-structure]
        ├── rpm/
        │   └── [vendor-structure]
        └── packagist/
            └── [vendor-structure]
```

And here's an explanation of some of the files and directories:

1. `/incoming` directory -- This is the directory used by the `peekaygee` client program to place incoming packages and instruction files for the `peekaygee-archive` utility to handle. It places them in the `public` or `private` subdirectories so `peekaygee-archive` knows which section they belong in.
2. `/logs` directory -- A directory for server logs.
3. `/srv-config` directory -- A directory containing machine- and user-generated server configuration files, such as apache and nginx virtualhost definitions and the `htpasswd` file that defines access rights for the private section of the archives.
4. `/webroot` directory -- The publicly accessible root of the archive wbsite.
5. `/webroot/index.html` -- A simple index file that may be used or discarded at will. It serves as a place where you can explain the archive and what it contains, and also serves to hide the supposedly-password-protected 'private' directory.
6. `/webroot/[name]-archive-keygring.gpg` -- The public gpg key used to sign packages in this archive.
7. `/webroot/private` -- A container for all password-protected private packages.
8. `/webroot/public` -- A container for all publicly-available packages.

This is the structure that's created with `peekaygee-archive init ([path])` (minus the vendor-specific directories, which are created the first time a vendor worker runs on the archive).

