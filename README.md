# NOTE: WIP

This readme is very much a work-in-progress and will probably have big gaps for
some time.

# Tcl-based Build Helper (TBH)

This is a framework for creating easy-to-maintain and flexible build scripts; at
least, that's the intent. This project was started because I have too many
docker repos where I followed a copy-paste-customize workflow for creating build
scripts. Maintainability is a problem. Also a problem: most of the build scripts
are Bash, which makes complicated looping or control flow more eventful than
desired.

The main idea with this is to create multiple layers where code re-use can
happen between projects, but without creating an ugly mess at the same time. TBH
itself should provide just enough logic itself to be useful, and leave other
implementation-specific logic to said implementation. There are artificial
constraints in some key places to try to keep implementation clean and avoid
creating code spaghetti.

This is entirely Tcl, written for Tcl. If you're looking for something to manage
other kinds of scripts, you're probably better served with something else (even
though this could be repurposed for that, it's probably not worth your effort).

# Background

## The 3 Contexts

High-level program flow/logic is abstracted from configuration and low-level logic:

1. Targets - High-level logic (looping, "do this, then this, etc.")
2. Helpers - Low-level logic (transactional)
3. Defaults - Configuration (project name, default Docker tag, etc.)

### Targets

Targets are the main interface component. All code in TBH itself exists to
provide a means for executing targets. Targets are pluggable and are defined by
calling the target procedure in target files. Targets are not procedures (not
directly anyway) and, as such, do not support the concept of arguments. Instead,
targets make use of the Defaults system for run-time configuration. 

### Helpers

Helpers are plumbing that exists to make writing targets easier. Targets should
be as simple as possible and should rely on helpers as much as possible.
Consider helpers generic, fixed-purpose, re-usable procedures. Helpers use and
require arguments. You cannot run helpers directly; you must use a target to
call helpers.

### Defaults (Configuration)

Defaults are a mechanism for creating an ordered hierarchy for configuration.
Defaults files define one or more "default" configuration settings. Many
defaults files can exist and file name order and how near the file is to the
project directory dictates which setting wins.

This capability exists so that a system can have default settings that are
overridden by project-specific configuration. Beyond defaults files, any default
can be overridden by run-time arguments passed to tbh.

## Put Together - Example

Let's use my real-world use-case of a few Docker projects. Some of the projects
are built from a Dockerfile, and some are built by a script that calls Buildah
directly. Some projects are a mixture of both scenarios. To start, let's look at
the purpose of the components:

* [project directory]/tbh/targets/**make_project.target**
    * Builds the container image for multiple architectures
    * Does some extra things beyond what buildah-bud-multiarch.target from tbh-contrib does
    * Calls get-file.helper to cache reusable bits for the container images
    * Reads a dict containing a list of architectures to build
    * Calls buildah-bud.helper for each architecture image, specifying a custom tag convention
* [tbh-contrib]/helpers/**get-file.helper**
    * Downloads a file
* [tbh-contrib]/helpers/**buildah-bud.helper**
    * Creates docker images with Buildah
* [tbh-contrib]/targets/**buildah-docker-push-multiarch.target**
    * Pushes all multi-arch images created by make_project.target to a remote registry
    * Calls buildah-docker-push.helper per-image
* [tbh-contrib]/helpers/**buildah-docker-push.helper**
    * Pushes a Docker image to a remote registry
* [tbh-contrib]/helpers/**buildah-manifest-create.helper**
    * Creates a local manifest
* [tbh-contrib]/helpers/**buildah-manifest-push.helper**
    * Pushes a local manifest to a remote registry

That's enough to highlight some things. Some key points for this scenario:

1. the make_project target is highly customized for the project, which is why it is in the project repo
1. The various helpers highlighted here are very generic and reusable; so much so that they are provided by tbh-contrib.
1. The build might be customized for the project, but buildah-docker-push-multiarch.target is perfectly usable for pushing the images, so it's just used for this project.
1. make_project.target could have been named buildah-bud-multiarch.target and would have overridden the functionality in the target of that name in tbh-contrib. There's nothing stopping you from doing this, it could get pretty confusing, though.

# Installing

1. Put tbh.tcl where it can be executable and in PATH. You could just pop it into /usr/local/bin/tbh and make it executable.
1. If you want tbh-contrib, put the contents somewhere it'll be found. You can export TBH_PATH and point to tbh-contrib.
1. You can add additional directories (search paths) to tbhDirs, around line 45-ish

# Invocation

Run `tbh` in the root directory of your project. Running it without any
arguments will print a summary of things you can run.

# Customizing

The tbh directory in the project has some examples you can use as a starting
point. For each tbhDir, files are loaded from these subdirectories:

1. tbh/helpers/*.helper
1. tbh/targets/*.target
1. tbh/defaults/*.defaults

You can define multiple items of a type in each file, though probably shouldn't;
keeping each "thing" in its own file helps to promote the concept that it's its
own "thing".

Also worth noting - you can't cross streams. You are free to define multiple
items of a type in a file, but you can't mix targets with defaults or helpers.
This is an intentional design limitation and serves to promote logical
separation of content and discourage creating monolithic tbh files.

The rest of this section references the following three example files for
explanation.

## Example Target

```
target "hello-world" {
    title       "Hello World"
    description "Hello World target"
    version     "1.0"

    help {
        This is a big help block.
        The intent is to add some level of documentation to stuff.
    }

    run {
        # Executable Tcl code block
        call hello-world [cfg hello-world-string]
    }
}
```

**Notes:**

* The string right after the target name is the internal name of the target
    * This name uniquely identifies the helper
    * This should be unique, but there's no strict constraint on that
        * The last write will win, in terms of naming
* The `title`, `description`, and `version` statements should be self-explanatory
    * TBH prints these values in command output in some places
    * These values aren't used for any kind of internal housekeeping; they're really here just to provide in-line metadata
* The `help` block will be printed to stdout by the `tbh help target_name` command
    * Whitespace will be stripped from the beginning of help lines, so don't rely on indentation too much
* The `run` block is where the action is.
    * You can call helpers with the `call` command
    * You can call other targets with the `run` command, though you should use this sparingly
    * Note the call to `cfg`. This command allows you to retrieve configuration settings from defaults files/command line arguments
    * You can call `title "blah blah blah"` to print a fancy title

## Example Helper

```
helper "hello-world" {
    title       "Hello World"
    description "Hello World Helper"
    version     "1.0"

    args {blerb}

    body {
        # Executable Tcl code block
        puts $blerb
    }
}
```

**Notes:**

* The structure of helper definitions is similar to targets
* The `args` are a list that is directly passed to proc to define the helper, so follow proc usage
* `body` contains the executable code for the helper
    * This is intentionally not named `run` to be distinct from targets
    * you can call `cfg` in helpers but you shouldn't - helpers should rely on `args` instead
    * You can call `title "blah blah blah"` to print a fancy title

## Example Default

```
defaults {
    hello-world-string "Hello, World"
}
```

**Notes:**

* Everything in a `defaults` block is considered a dict, so you can use quoting to create a hierarchy


## Running

To call your custom target, run `tbh run hello-world`.