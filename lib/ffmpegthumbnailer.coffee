{exec} = require 'child_process'
events = require 'events'
Seq = require 'seq'

FFMPEGTHUMBNAILER = 'ffmpegthumbnailer'

class FFmpegThumbnailer extends events.EventEmitter
  constructor: ->

  create: (input, output, options...) ->
    size = options[0] ? "160x120"
    offset = options[1] ? "10%"
    args = {input: input, output: output, size: size, offset: offset}
    unless output.match(/\.(png|jpe?g)$/)
      err = new Error "Output Format Error"
      console.log "Create Thumbnail Error: #{input}"
      process.nextTick =>
        this.emit 'error', err
    else
      exec "#{FFMPEGTHUMBNAILER} -q 10 -s #{size} -t #{offset} -i \"#{input}\" -o \"#{output}\"", {maxBuffer: 1000*1024}, (err, stdout, stderr) =>
        if !err
          this.emit 'end', args
        else
          console.log "Create Thumbnail Error: #{input}"
          this.emit 'error', err

  multi_create: (count, input, output, options...) ->
    size = options[0] ? "160x120"
    offset_base = parseInt(100 / count)
    finish_count = 0
    args = {count:count, input: input, output: output, size: size, offset: "#{offset_base}%"}
    unless output.match(/\.(png|jpe?g)$/)
      err = new Error "Output Format Error"
      console.log "Multi Create Thumbnail Error: #{input}"
      process.nextTick =>
        this.emit 'error', err
    else
      Seq()
        .seq_((next) ->
          next(null, [1..count])
        )
        .flatten()
        .seqEach_((next, i) ->
          seq_output = output.replace /(.*)\.(png|jpe?g)$/, "$1-#{i}.$2"
          exec "#{FFMPEGTHUMBNAILER} -q 10 -s #{size} -t #{i * offset_base} -i \"#{input}\" -o \"#{seq_output}\"", {maxBuffer: 1000*1024}, next
        )
        .seq_((next) =>
          this.emit 'multi_end', args
        )
        .catch((err) =>
          console.log "Create Multi Thumbnail Error: #{input}"
          this.emit 'multi_error', err
        )


thumbnailer = new FFmpegThumbnailer
module.exports = thumbnailer
