{exec} = require 'child_process'
events = require 'events'

FFMPEGTHUMBNAILER = 'ffmpegthumbnailer'

class FFmpegThumbnailer extends events.EventEmitter
  constructor: ->

  create: (input, output, options..., callback) ->
    try
      size = options[0] ? "160x120"
      offset = options[1] ? "10%"
      args = {input: input, output: output, size: size, offset: offset}
      throw new Error "Output Format Error" unless output.match(/\.(png|jpe?g)$/)

      exec "#{FFMPEGTHUMBNAILER} -q 10 -s #{size} -t #{offset} -i \"#{input}\" -o \"#{output}\"", (err, stdout, stderr) ->
        callback(err, args, stdout, stderr)
    catch error
      console.log input
      callback(error, args)

  multi_create: (count, input, output, options..., callback) ->
    size = options[0] ? "160x120"
    offset_base = parseInt(100 / count)
    finish_count = 0
    args = {count:count, input: input, output: output, size: size, offset: "#{offset_base}%"}
    for i in [1..count]
      seq_output = output.replace /(.*)\.(png|jpe?g)$/, "$1-#{i}.$2"
      this.create input, seq_output, size, "#{i * offset_base}%", (err, args2, stdout, stderr) ->
        throw err if err
        finish_count += 1
        if finish_count == count
          callback(err, args, stdout, stderr)

thumbnailer = new FFmpegThumbnailer
module.exports = thumbnailer
