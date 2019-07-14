Peekaygee
===========================================================================

Peekaygee is a framework for handling the creation and publishing of various types of packages. It attempts to be both a unified interface over packaging tools like npm, dpkg, etc., as well as an open-source alternative to services like packagecloud.io.

## Quick Start

#### 1. Install and configure `peekaygee` on both client and server.

See [Installation](#installation) below for instructions.

On the client, you should configure your server as a remote. You'll usually do this in your `~/.config/peekaygee/peekaygee.json` file. See [Configuration Options](#configuration-options) below for more details.

#### 2. Initialize a package server

Make sure you have a basic webserver (apache, nginx or similar) installed on the machine you want to serve your packages. Then run the following:

```
SERVER_PATH=/srv/www/packages.your-domain.io
sudo mkdir -p $SERVER_PATH
peekaygee-archive init $SERVER_PATH
```

This results in the files and folders listed further down the page in [Archive Structure](#archive-structure). One of the folders created is `srv-config`, which contains both an apache and an nginx virtual host declaration. You can feel free to link those into your apache or nginx installs as-is or modify them to suit your specific needs.

If you want to use a different web server, just riff on the apache or nginx files.

#### 3. Create a `pkg-src` directory in your project

This should follow the structure down below in [Usage](#usage). In brief, you should have _something like_ the following:

```
pkg-src/
├── deb/
│   └── my-project/
│       ├── DEBIAN/
│       │   ├── config
│       │   ├── control
│       │   ├── postinst
│       │   └── templates
│       └── VERSION
├── generic/
│   └── my-project/
│       └── etc/
│           └── systemd/
│               └── system/
│                   └── my-project.service
└── rpm/
    └── my-project/
        ├── [some meta files....]
        └── VERSION
```

The first level under `pkg-src` is the package type: `generic` for files common to all package types, `deb` for debian packages, `rpm` for rpm packages, etc.

The level under that is the actual packages. You can have one or more packages for each package type. In this case, we're building a package called simply `my-project`.

The level under that is package type-specific.

#### 4. Add a `place-pkg-files.sh` script

You should create a `scripts` directory at the root of your project and add to it an executable called `place-pkg-files.sh`. This file is called by `peekaygee build` like so:

```
./scripts/place-pkg-files.sh $pkgName $targDir $pkgType
```

You'll usually use this to build any source into final form and then copy the built files into the desired locations in `$targDir` for final packaging.

#### 5. Run `peekaygee build`

This will build all packages for which you have builders installed.

#### 6. Run `peekaygee push nameOfMyArchive`

This is the final step, and will take the packages you built in step 5 and push them to the defined remote.


## Project Overview

Altogether, peekaygee's main goals are the following:

* Allow source code maintainers to easily maintain, build and publish packages from within the source code repository itself
* Allow consumers to optionally build forks of official packages, and publish those package forks to alternative locations

This means that, using `peekaygee`, it should be simple to

1. find the package source files;
2. optionally modify those files;
3. build those files along with the actual application in question into finished packages of various sorts;
4. publish those built packages to one or more remote package repositories.

It is meant to be installed globally and used both globally and repo-locally. Globally, you may use it to view all known peekaygee-enabled repos, to build all known packages, and subsequently to publish all known built packages to their specified package repositories (though global usage is not yet implemented at the time of this writing). Locally, you can use it to build packages defined within the current source code repo and to publish those built packages to specified package repositories.

`peekaygee` is agnostic about what types of packages you're building. It uses cues from the filesystem hierarchy along with matching user-authored scripts to build packages of any sort, so it's trivial for application authors to support any arbitrary package types. It also supports both public and private remote package repositories.

`peekaygee` was originally built to ship both public and private debian packages, so at the time of this writing, that's the best supported functionality. However, the fundamentals of building a package and providing a centrally-accessible package archive (like packagist for php, npmjs.org for javascript, maven for java, etc.) probably won't change much between specific types of packages, and those changes can be easily encapsulated, so it will remain easy to support future package standards.


## Installation

Since `peekaygee` is a client/server utility, you'll have to install it both locally and on your remote package server. (If you're serving packages out of your local machine, it'll work just fine that way, too, just install both the client and server utilities on your machine.) Here's what you need to do:

1. **Install `peekaygee` on your local machine and server using your OS package manager** (or by just placing the source files in the right locations, though there are a few pesky dependencies to worry about, see below). The official project packages are available at https://packages.kaelshipman.me, though at the time of this writing, there are only Debian packages available.
2. **On your local machine, add a configuration file** (at `~/.config/peekaygee/peekaygee.json`) that defines one or more remotes (see Config Options below for more details).
3. **On your server, install the `peekaygee-srvworker-*` package that matches the types of packages you want to serve.** For example, if you want to serve, debian packages, install `peekaygee-srvworker-deb`. If no `srvworker` package is available for the types of packages you want to publish, consider writing one. See `Server Worker Interface` below.
4. **On your server, make sure you've got permissions set up correctly for managing and serving your archive.** For example, if your archive is at `/srv/www/packages.my-site.com`, you'll probably want to do this: `sudo setfacl -Rm user:$USER:rwX,default:user:$USER:rwX /srv/www/packages.my-site.com && mkdir -p /srv/www/packages.my-site.com/webroot && sudo setfacl -Rm user:www-data:rX,default:user:www-data:rX /srv/www/packages.my-site.com/webroot`. That will give your user read/write access to everything and the webserver user r access to the web root directory.

### Type-Specific Setup

The various package types may also have certain requirements. Here's what's required for Debian repositories:

* A gpg key for signing, and the resultant public key at `/webroot/[keyfile]` for download
* A reprepro configuration at `[ARCHIVE-ROOT]/webroot/{public,private}/deb/conf/`

For both of these, you can follow this useful tutorial [here](https://www.digitalocean.com/community/tutorials/how-to-use-reprepro-for-a-secure-package-repository-on-ubuntu-14-04).

Other things may be required for other types of repositories.


## Installation From Source

If you'd like to install `peekaygee` from source, it's pretty easy (since it's all just shell scripts), but you have to make sure you've got all the dependencies. Here's what to do (on both client and server):

1. Install [`jq`](https://github.com/stedolan/jq)
2. Install `librexec.sh` from [`ks-std-libs`](https://github.com/kael-shipman/ks-std-libs)
3. Copy `[peekaygee]/src/*` into your filesystem (for example, `git clone https://github.com/kael-shipman/peekaygee /tmp/peekaygee && sudo cp -R /tmp/peekaygee/src/* /`)
4. Finally, make sure you symlink any of the included `srvworker` executables to their canonical names (e.g., `sudo ln -s /usr/bin/peekaygee-srvworker-deb-reprepro /usr/bin/peekaygee-srvworker-deb`. On Ubuntu systems, you'll do this via `update-alternatives`.)

That should give you all the executables you need. Then you just have to worry about config.


## Usage

As mentioned above, `peekaygee` is a client/server system. It comprises the following scripts:

* `peekaygee-archive` -- a utility that handles functions like initializing an archive, coordinating workers on the archive, and answering queries from clients about the capacities of the archive server
* `peekaygee` -- the client utility that reads local config files and attempts to push files and commands to one or more configured remote archive servers
* `peekaygee-srvworker-*` -- a general class of worker script that is called by `peekaygee-archive` to do the actual work of managing a type of archive.
* `peekaygee-builder-*` -- a general class of worker script that is called by `peekaygee` to do the actual work of building a specific type of package from a prepared package source tree into a final package file.

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
├── peekaygee.json
├── pkg-build/
├── pkg-src/
│   ├── deb/
│   │   └── my-project/
│   │       ├── DEBIAN/
│   │       │   ├── config
│   │       │   ├── control
│   │       │   ├── postinst
│   │       │   └── templates
│   │       └── VERSION
│   ├── generic/
│   │   └── my-project/
│   │       └── etc/
│   │           └── systemd/
│   │               └── system/
│   │                   └── my-project.service
│   └── rpm/
│       └── my-project/
│           ├── [some meta files....]
│           └── VERSION
├── scripts/
│   ├── build.sh
│   └── place-pkg-files.sh
├── src/
│   ├── some-file.c
│   └── other-file.c
├── tests/
└── VERSION
```

We can see this is some simple C program. We can also see that we've prepared control files to build a debian package and an rpm package from this source, and also that we've included a systemd service unit file in a folder called "generic" (more on that in a minute). Now when you run `peekaygee build` from within this repo, `peekaygee` does the following:

1. It iterates through all non-"generic" children of `pkg-src`, each of which represent a type of package to build;
2. For each type, it itereates through all of that type's children, each of which represent a single package to build of the given type;
3. For each package of each type, it does the following:
   a. It copies the base package folder from `pkg-src/{pkg-type}/{pkg-name}` to `pkg-build/{pkg-name}.{pkg-type}`;
   b. It copies all files from `pkg-src/generic/{pkg-name}/` into the new folder;
   c. It calls the script defined in `peekaygee.json` for key `scripts.placeFiles` with arguments `pkg-name`, `targ-dir` (in this case `pkg-build/{pkg-name}.{pkg-type}`), and `pkg-type`;
   d. It replaces ALL INSTANCES of the string `::VERSION::` anywhere in any of the files in `pkg-build/{pkg-name}.{pkg-type}/` with the version defined in `pkg-src/{pkg-type}/{pkg-name}/VERSION` or `pkg-src/generic/{pkg-name}/VERSION` or `pkg-src/VERSION` or `PKG-VERSION`, whichever is found first.
   e. It calls any optional pre-build hooks that it finds (see [hooks](#hooks) below);
   f. Finally, it builds the package by calling `peekaygee-builder-{pkg-type} {prepared-pkg-dir} {final-build-dir}` and then deletes `{prepared-pkg-dir}`, leaving the finished package in `{final-build-dir}`.

As you can see, you can use the `generic` package folder to supply files that should be placed in _all_ different types of packages. This is good for systemd unit files, static documentation files, example config files, etc.

Once you've built the packages, you're ready to publish them to your debian and rpm repos. You can do that by simply running `peekaygee push [your-repo]`, meaning, "push any recognzed packages in the `pkg-build` directory (overridable in `peekaygee.json`) to the remote archive server named `[your-repo]`." Running this command would identify the two files in your build directory, check that `[your-repo]` can handle them (by running `peekaygee-archive supports [type]` on your remote server), transfer the two files to your remote server along with any package-specific options defined in your `peekaygee.json` config files, delete the built files locally, then run `peekaygee-archive update [archive]` on your remote server. That command would identify the two incoming files, then use `peekaygee-srvworker-deb add [archive] [debfile] [options]` to add the debian file, and `peekaygee-srvworker-rpm add [archive] [rpmfile] [options]` to add the rpm file. Assuming all that goes well, it would return success and your packages would be public! (Or private, depending on how you configured them).


## Hooks

As mentioned in the example above, `peekaygee` utilizes certain hooks during its execution. At the time of this writing, there are only three hooks: `prestart`, `prebuild`, and `postfinish`. However, more may eventually emerge.

Hooks may be defined in two places:

* Globally in `$XDG_CONFIG_HOME/peekaygee/hooks/`; and
* Repo-locally, in a location specified by your `peekaygee.json` file.

If both hooks are present, both are run, with the local hook running first.

### Pre-Start Hook

Called before the actual build loop is entered. Probably not very useful, but there if you need it.

### Pre-Build Hook

This hook is called after the entire package directory is prepared and before it is built into a final package file. It is called with arguments `pkg-name`, `targ-dir`, and `pkg-type` (the same options that the `placeFiles` script is called with).

One possible use-case for this script is to allow you to set ownership and/or permissions on certain files for debian packages, which honor such attributes on install.

### Post-Finish Hook

Called after the build loop exits. Might be good for cleanup.


## Configuration Options

`peekaygee` utilizes two suites of configuration files, one for the client and one for the server. A "suite" of configuration files is simply a single configuration file that may be found in various locations, each location overriding directives from previous ones.

`peekaygee`'s client and server configuration files are very similar. In fact, if the client and server happen to be the same machine, you can actually get by by simply symlinking the config files together for easier management.

Below is a description of where the files are found and the options available in each.

### peekaygee.json

This suite of config files controls behavior of the `peekaygee` client (used on your local computer to manage remote repositories). `peekaygee.json` files are searched for in the following locations (4 overrides 3 which overrides 2, etc...):

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
                "deb": {
                    "force": true
                }
            }
        }
    },
    "default-remote": "production",
    "build-dirs": ["pkg-build"],
    "builder": {
        "pkg-src-dir": "pkg-src",
        "build-dir": "pkg-build",
        "hooks": {
            "prestart": "my-scripts/my-prestart-hook.sh",
            "prebuild": "my-scripts/my-prebuild-hook.sh",
            "prefinish": "my-scripts/my-prefinish-hook.sh"
        }
    },
    "packages": {
        "deb": {
            "type": "deb",
            "match": ".*\\.deb$",
            "visibility": "private",
            "options": {
                "dists": ["bionic","xenial"],
                "force": true
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

**default-remote** (optional) -- If specified, this remote will be used if none is given on the command line.

**build-dirs** (required) -- An array of directories to search for built files. May be relative or absolute, but must be local.

**builder** (required for building packages) -- A block of configurations pertaining to the peekaygee package build process and related executables.

**builder.pkg-src-dir** (required for building packages) -- The directory that contains your peekaygee-compatible package template trees.

**builder.build-dir** (required for building packages) -- The directory into which to place finished packages.

**hooks** (optional) -- A block defining the locations of various types of hooks.

**packages** (required) -- A list of package specifications. While normally keys in this list will match their "type" parameters, this is not always the case. For example, in a certain project that contains both public and private package builds, I may null out the default "deb" package specification and replace it with "deb-public" and "deb-private", using the "match" key to select the correct packages for each.

**packages.[name].type** (required) -- Which type of packages match this specification. While technically this may be anything, you must have the respective `builder` and `srvworker` executables installed for each type both locally and on your server, and your server must have config that teaches it how to handle packages of that type. Normally this will be something like `deb`, `npm`, `rpm`, `arch`, etc...

**packages.[name].match** (required) -- A regex used to find all packages that are governed by this package profile. This is used directly with `grep -E`.

**packages.[name].visibility** (optional, default "public") -- Either "public" or "private". This defines whether the package will be published in the public section or the private section of your repository.

**packages.[name].options** (optional) -- This is an arbitrary, worker-specific options hash that's passed along inline to the worker on the server. It may be used for anything, but in the case of debian packages, it's used to specify the releases (`dists`) the package should be published for and whether or not to forcefully replace a package that already exists in the given version at the server. Options for this hash are not well defined or documented yet....

### peekaygee-archive.json

This suite of config files controls behavior of the `peekaygee-archive` agent (used on remote machines to manage repositories there). `peekaygee-archive.json` files are searched for in the following locations (4 overrides 3 which overrides 2, etc...):

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

**packages.[name].type** (required) -- Which type of packages match this specification. While technically this may be anything, your package server must have a `peekaygee-srvworker-[type]` worker application installed and in its path, and it must have config that teaches it how to handle packages of that type. Normally this will be something like `deb`, `npm`, `rpm`, `arch`, etc...

**packages.[name].match** (required) -- A regex used to find all packages that are governed by this package profile. This is used directly with `grep -E`.


## `peekaygee` Interfaces

Following is a brief description of the interfaces of the `peekaygee` utilities. For full documentation, use the `--help` flag on each.

### `peekaygee`

* `peekaygee build` -- Build packages in the current repository
* `peekaygee push [remote]` -- Push any available packages to the given remote
* `peekaygee delete [remote] [package spec]` -- Delete packages matching `package-spec` from the given remote
* `peekaygee prune [remote] ([package-spec]) [num-versions]` -- Delete old versions of packages from remote, leaving only `num-versions` of each (optionally filtering by `package-spec`)
* `peekaygee list [remote] ([type]) ([package-spec])` -- List packages on the given remote, optionally filtered by `type` and `package-spec`

### `peekaygee-builder-*`

This is a general interface for all compliant `peekaygee-builder-*` implementations. You may add support for building any package type by simply implementing this interface, then making your implementation available on your path under the name `peekaygee-builder-[type]`.

* `peekaygee-builder-[type] [src-tree] [build-dir]` -- Builds package prepared in `[src-tree]` into a final file placed in `[build-dir]`.

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

