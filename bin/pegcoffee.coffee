#!/usr/bin/env node

fs   = require 'fs'
PEG  = require 'pegjs'
PEGjsCoffeePlugin = require '../index'

# Helpers


printVersion = -> console.log("PEG.js CoffeeScript Plugin #{PEGjsCoffeePlugin.VERSION}")


printHelp = ->
  console.log """
    Usage: pegcoffee [options] [--] [<input_file>] [<output_file>]

    Generates a parser from the PEG grammar specified in the <input_file> and
    writes it to the <output_file>.
    
    If the <output_file> is omitted, its name is generated by changing the
    <input_file> extension to \".js\". If both <input_file> and <output_file> are
    omitted, standard input and output are used.
    
    Options:
      -e, --export-var <variable>  name of the variable where the parser object
                                   will be stored (default: \"module.exports\")
          --cache                  make generated parser cache results
          --allowed-start-rules    comma separated rules to start parsing from
          --optimize               size or speed
          --js                     use plain JavaScript in actions
      -v, --version                print version information and exit
      -h, --help                   print help and exit
  """

exitSuccess = -> process.exit(0)

exitFailure = -> process.exit(1)

abort = (message) ->
  console.error message
  exitFailure()

# Arguments

#Trim "node" and the script path.
args = process.argv.slice 2
argv = require("minimist") args,
          string: ["export-var", "allowed-start-rules", "optimize"]
          boolean: ["cache", "version", "help", "js"]
          alias:
            "export-var": "e"
            "version": "v"
            "help": "h"
          "--": true
          unknown: (arg) ->
            return false

# Files 

readStream = (inputStream, callback) ->
  input = ""
  inputStream.on("data", (data) -> input += data )
  inputStream.on("end", -> callback input )


# Main 

# This makes the generated parser a CommonJS module by default.
exportVar = "module.exports"
# Set the usage of CoffeeScript as default
options = 
  cache: false
  output: "source"

if args.length > 0
  if argv["export-var"]
    exportVar = argv["export-var"]
    if typeof exportVar isnt "string"
      abort "Missing parameter of the -e/--export-var option."

  if argv.js
    options.js = true

  if argv.cache
    options.cache = true

  if allowedStartRules = argv["allowed-start-rules"]
    if typeof allowedStartRules isnt "string"
      abort "Missing parameter of the --allowed-start-rules option."
    options.allowedStartRules = allowedStartRules

  if optimize = argv.optimize
    if typeof optimize isnt "string"
      abort "Missing parameter of the --optimize option."
    options.optimize = optimize

  if argv.version
    printVersion()
    exitSuccess()

  if argv.help
    printHelp()
    exitSuccess()

switch args.length
  when 0
    process.stdin.resume()
    inputStream = process.stdin
    outputStream = process.stdout

  when 1, 2
    inputFile = args[0]
    inputStream = fs.createReadStream inputFile
    inputStream.on "error", ->
      abort "Can't read from file \"#{inputFile}\"."

    outputFile =
      if args.length is 1 then args[0].replace(/\.[^.]*$/, ".js") else args[1]
    outputStream = fs.createWriteStream outputFile
    outputStream.on "error", ->
      abort "Can't write to file \"#{outputFile}\"."
  else abort "Too many arguments."


readStream inputStream, (input) ->
  if not options.js
    options.plugins = [PEGjsCoffeePlugin]
  try 
    parser = PEG.buildParser(input, options)
  catch e
    if e.line? and e.column?
      abort "#{e.line}:#{e.column}:#{e.message}"
    else
      abort e.message

  outputStream.write "#{exportVar} = #{parser};\n"
  outputStream.end() if outputStream isnt process.stdout
