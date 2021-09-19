#! /usr/bin/env tclsh

# tbh.tcl --
#
#     Tcl-Based Build Helper (TBH)
# 
# Copyright 2021 C. Annable
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# ------------------------------------------------------------------------------
# Main Variables

# tbhDirs - This is list of the locations for which to load target and defaults
# data. List order matters - last write wins. The script will search for files
# matching these patterns:
#
#   - tbhDir/defaults/*.defaults
#   - tbhDir/targets/*.target

set tbhDirs [list [file join $env(HOME) ".tbh"] [file join [pwd] "tbh"]]

if {[lsearch [array names env] TBH_PATH] >= 0} {
    set tbhDirs [linsert $tbhDirs 0 $env(TBH_PATH)]
}

# defaults - Stores the default configuration

set defaults [dict create]

# helpers - A single dict that will contain all helper data

set helpers [dict create]

# targets - A single dict that will contain all target data

set targets [dict create]


# ------------------------------------------------------------------------------
# App Default Settings

# You can set debug to on in command line arguments, but because loading those
# happens fairly late, you can't really debug command or argument handling. To
# do that, set debug to 1 here.
dict set ::defaults debug 0

# Terminal defaults (affects procs that print "nice" output)
dict set ::defaults term lines 25
dict set ::defaults term columns 80

# Load app-default settings for now
set ::config $defaults


# ------------------------------------------------------------------------------
# Config File-Handling Procedures

# debug --
#
#           Print debug information
#
# Arguments:
#           args    Strings to print
#
# Results:
#           Prints arguments to stdout if debug is on
#
proc debug {args} {
    if {[cfg debug]} {
        puts {*}$args
    }
}


# helper --
#
#           Define a new helper
#
# Arguments:
#           name    Helper name
#           input   Key/value pairs of helper configuration data
#
# Results:
#           Defines a new helper, stores metadata in ::helpers, and creates the
#           proc.
#
proc helper {name input} {
    # Ensure the passed input payload can be read as key/value pairs
    if {[llength $input] % 2} {
        error Unbalanced helper definition
    }

    if {![dict exists $input body]} {
        error "Helper definition for '$name' does not have a valid body block."
    }

    if {![dict exists $input args]} {
        error "Helper definition for '$name' does not have a valid args block."
    }

    # Define the arbitrary proc (lol)
    proc "::helpers::$name" [dict get $input args] [dict get $input body]


    # Instantiate all expected metadata values
    foreach key {title description version} {
        dict set ::helpers $name $key ""
    }

    # Store metadata
    foreach {key value} $input {
        dict set ::helpers $name $key $value
    }

}


# findTbhFiles --
#
#           Locates TBH files that can be loaded
#
# Arguments:
#           type    TBH file type
#
# Results:
#           Returns a list of loadable files
#
proc findTbhFiles {type} {
    set results {}

    # File type vs. expected extension
    array set extensions {
        helpers     helper
        targets     target
        defaults    defaults
    }

    # Right off the bat, if the type isn't one we'd expect, bail
    if {[lsearch [array names extensions] $type] < 0} {
        error "'$type' is not a valid file type."
    }

    # Go through all defined Tbh search paths
    foreach tbhDir $::tbhDirs {

        if {[file isdirectory $tbhDir]} {

            # If we found a directory, let's look for expected subdirs
            foreach subDir [array names extensions] {
                set path [file join $tbhDir $subDir]

                # Find potential files
                set potentials [glob -nocomplain \
                    -directory $path \
                    "*.$extensions($type)"]

                foreach file [lsort $potentials]  {
                    # If these results are files, add them to the results
                    if {[file isfile $file]} {
                        lappend results $file
                    }
                }
            }
        }

    }

    return $results

}


# target --
#
#           Define a new target
#
# Arguments:
#           tgt     Target name
#           input   Key/value pairs of target configuration data
#
# Results:
#           Defines a new target and stores it in ::targets
#
proc target {tgt input} {
    # Ensure the passed input payload can be read as key/value pairs
    if {[llength $input] % 2} {
        error Unbalanced target definition
    }

    # Instantiate all expected values
    foreach key {title description version help run} {
        dict set ::targets $tgt $key ""
    }

    foreach {key value} $input {
        dict set ::targets $tgt $key $value
    }

}


# defaults --
#
#           Define defaults
#
# Arguments:
#           input   Key/value pairs of default configuration settings
#
# Results:
#           Updates ::defaults settings
#
proc defaults {input} {
    # Ensure the passed input payload can be read as key/value pairs
    if {[llength $input] % 2} {
        error Unbalanced defaults block
    }

    foreach {key value} $input {
        dict set ::defaults $key $value
    }
}


# cfg --
#
#           Get config value
#
# Arguments:
#           args    Config key (args so we can go any levels deep)
#
# Results:
#           Returns the value for the passed key.
#           If the key doesn't exist, returns an empty string.
#
proc cfg {args} {
    if {![dict exists $::config {*}$args]} {
        return {}
    }

    return [dict get $::config {*}$args]
}

# call --
#
#           Simple wrapper to call helper procs
#
# Arguments:
#           args    All arguments to pass to helper
#
# Results:
#           Runs the helper
#
proc call {args} {
    tailcall "::helpers::[lindex $args 0]" \
        {*}[lrange $args 1 end]
}

# title --
#
#           Write a title string
#
# Arguments:
#           text    Title text
#
# Results:
#           returns a "fancy" title line
#
proc title {text} {
    set char -
    set len [string length $text]
    set max [cfg term columns]

    # If the title is too long, be lazy and don't do any formatting
    if {$len >= $max} {
        return $text
    }

    set remainder [expr {$max - $len - 5}]

    return [format {%s %s %s} \
        [string repeat $char 3] \
        [string toupper $text] \
        [string repeat $char $remainder]]
}


# ------------------------------------------------------------------------------
# Execution Procedures


# run --
#
#           Run a target run payload
#
# Arguments:
#           tgt Target
#
# Results:
#           Runs target payload
#
proc run {tgt} {
    if {![dict exists $::targets $tgt run]} {
        error "Target '$tgt' does not exist."
    }

    if {[cfg debug]} {
        printConfig
        debug "Attempting to run '$tgt'..."
    }

    eval [dict get $::targets $tgt run]
}


# ------------------------------------------------------------------------------
# Interface Procedures


# help --
#
#           Print help payload for a target
#
# Arguments:
#           tgt Target
#
# Results:
#           Prints help payload for a target to stdout
#
proc help {tgt} {
    # Print title
    puts [string repeat - [cfg term columns]]
    puts [dict get $::targets $tgt title]
    puts [string repeat - [cfg term columns]]

    # Print help contents
    foreach line [split [dict get $::targets $tgt help] "\n"] {
        puts "[regsub -- {^[\t ]+} $line ""]"
    }
}


# printHelpers --
#
#           Print list of targets to stdout
#
# Arguments:
#           none
#
# Results:
#           Prints list of targets to stdout
#
proc printHelpers {} {
    dict for {helper config} $::helpers {
        puts "$helper:"
        dict with config {
            puts "\tTitle:       $title"
            puts "\tVersion:     $version"
            puts "\tDescription: $description\n"
        }
    }
}


# printTargets --
#
#           Print list of targets to stdout
#
# Arguments:
#           none
#
# Results:
#           Prints list of targets to stdout
#
proc printTargets {} {
    dict for {target config} $::targets {

        puts "$target:"
        dict with config {
            puts "\tTitle:       $title"
            puts "\tVersion:     $version"
            puts "\tDescription: $description\n"
        }
    }
}


# printDefaults --
#
#           Print default settings
#
# Arguments:
#           none
#
# Results:
#           Prints default settings to stdout
#
proc printDefaults {} {
    puts "defaults:"
    foreach {key value} $::defaults {
        puts "\t'$key': '$value'"
    }
}


# printConfig --
#
#           Print current config settings
#
# Arguments:
#           none
#
# Results:
#           Prints current config settings to stdout
#
proc printConfig {} {
    puts "config:"
    foreach {key value} $::config {
        puts "\t'$key': '$value'"
    }
}

# printHelp --
#
#           Print high-level invocation help
#
# Arguments:
#           none
#
# Results:
#           Prints high-level invocation help to stdout
#
proc printHelp {} {
    puts [string repeat - [cfg term columns]]
    puts "Tcl-based Build Helper (TBH)"
    puts [string repeat - [cfg term columns]]
    puts "Written completely in Tcl by CANNABLE.\n"

    puts "Available commands:\n"

    puts "\tTargets:\n"
    puts "\t\ttargets\t\tList targets"
    puts "\t\trun\t\tRun target"
    puts "\t\thelp\t\tPrint help content for a target\n"

    puts "\tHelpers:\n"
    puts "\t\thelpers\t\tList helpers\n"

    puts "\tOther:\n"
    puts "\t\tdefaults\tPrint default settings"
    puts "\t\tdebug\t\tPrint a bunch of debug info\n"
}


# ------------------------------------------------------------------------------
# 'Main'


if {[cfg debug]} {
    debug tbhDirs:
    foreach path $tbhDirs {
        puts "\t> $path"
    }
}

# Create the helpers namespace
namespace eval ::helpers {}

# Load helpers
foreach file [findTbhFiles helpers] {
    debug "Loading helper from $file."

    # TODO - Replace with something better than source
    source $file
}

# Load targets
foreach file [findTbhFiles targets] {
    debug "Loading target from $file."

    # TODO - Replace with something better than source
    source $file
}

# Load defaults
foreach file [findTbhFiles defaults] {
    debug "Loading defaults from $file."

    # TODO - Replace with something better than source
    source $file
}


# ------------------------------------------------------------------------------
# Terminal Initialization

# Try to get the particulars about the shell
if {[catch {exec stty -a} output]} {
    return
}

debug "Attempting to detect terminal particulars."

# Get lines
if {[regexp -- {lines (\d+)} $output match lines]} {
    dict set ::config term lines $lines
}

# Get columns
if {[regexp -- {columns (\d+)} $output match columns]} {
    dict set ::config term columns $columns
}

debug "\t> lines:   '[cfg term lines]'"
debug "\t> columns: '[cfg term columns]'"

# ------------------------------------------------------------------------------
# Script Argument Handling

# If no arguments were passed, pring help and bail
if {$argc == 0} {
    # Run the default command
    printHelp
    exit
}

# Load the default config
set config $::defaults

# The first argument is the command to run
set cmd [lindex $argv 0]

# Some commands expect 1 or 0 simple arguments
# (ex. like "run something -arg=value").
# With that in mind, let's tell the script how to handle those cases
switch -- $cmd {
    help        {set argsStartIdx 1}
    targets     {set argsStartIdx 1}
    helpers     {set argsStartIdx 1}
    defaults    {set argsStartIdx 1}
    debug       {set argsStartIdx 1}

    default {
        set argsStartIdx 2
        set tgt [lindex $argv 1]
    }
}

# Load command-line overrides
foreach {arg} [lrange $argv $argsStartIdx end] {
    debug "arg: '$arg'"

    # If the argument is malformed somehow, just ignore it.
    # If it's okay, then set it as a current config item
    if {[regexp -- {-(.*)=(.*)} $arg match key value]} {
        dict set ::config $key $value
    }
}

if {[cfg debug]} {
    debug "DEBUG is on"
}

# Main command switchboard
switch -- $cmd {
    help        {help {*}[lindex $argv 1]}
    run         {run $tgt}
    helpers     printHelpers
    targets     printTargets
    defaults    printDefaults
    debug       {printDefaults; printConfig}

    default {
        puts stderr "Eh?"
        printHelp
    }
}
