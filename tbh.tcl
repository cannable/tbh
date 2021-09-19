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

# defaults - Stores the default configuration

set defaults [dict create]

# targets - A single dict that will contain all target data

set targets [dict create]


# ------------------------------------------------------------------------------
# App Default Settings

# You can set debug to on in command line arguments, but because loading those
# happens fairly late, you can't really debug command or argument handling. To
# do that, set debug to 1 here.
dict set ::defaults debug 1

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


# shell --
#
#           Run a shell command
#
# Arguments:
#           args    command and arguments to execute
#
# Results:
#           Runs command and prints output to stdout
#
proc shell {args} {
    puts "SHELL: '$args'"

    if {[cfg debug]} {
        foreach arg $args {
            debug "\t> '$arg'"
        }
    }

    # Run the command line
    catch {exec -- {*}$args <@stdin >@stdout 2>@stderr}
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
    puts [dict get $::targets $tgt help]
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

        puts "'$target'"
        puts "  > [cfg title], [cfg version]"
        puts "  > [cfg description]"
        puts {}
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
    puts Nothing
}


# Load Config Files

foreach cfgDir $tbhDirs {
    debug "cfgDir: '$cfgDir'"

    set tgtDir [file join $cfgDir "targets"]
    set defDir [file join $cfgDir "defaults"]

    foreach file [lsort [glob -nocomplain -directory $tgtDir *.target]] {
        debug "Loading target from $file..."

        # TODO - Replace with something better than source
        if {[file exists $file]} {
            source $file
        }
        debug "Success... probably... I'm still alive for now."
    }

    foreach file [lsort [glob -nocomplain -directory $defDir *.defaults]] {
        debug "Loading defaults from $file."

        # TODO - Replace with something better than source
        if {[file exists $file]} {
            source $file
        }
        debug "Success... probably... I'm still alive for now."
    }
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
    targets     printTargets
    defaults    printDefaults
    debug       {printDefaults; printConfig}

    default {
        puts stderr "Eh?"
        printHelp
    }
}
