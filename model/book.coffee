mongoose = require 'mongoose'
Schema = mongoose.Schema
path = require 'path'
{spawn} = require 'child_process'
zipfile = require 'zipfile'
Seq = require 'seq'

IMAGEMAGICK = 'convert'

Book = new Schema {
  name: {type: String, required: true, index: true}
  path: {type: String, required: true, index: {unique: true, dropDups: true}}
  size: {type: Number, required: true}
  regist_date: {type: Date, index: true}
  view_count: {type: Number, default: 0}
  container: {type: String}
  tag: [String]
  md5_hash: {type: String, required: true}
  title: {type: String}
  artist: {type: String}
  genre: {type: String}
}

Book.method {
  create_thumbnail: (count = 6, options...) ->
    size = options[0] ? "160x120"
    zf = new zipfile.ZipFile @path
    if zf.count > (count - 1)
      targets = zf.names.filter (name, i) ->
        (i % parseInt(zf.count / (count - 1))) == 0
    else
      targets = zf.names

    Seq()
      .seq_((next) ->
        next(null, [1..count])
      )
      .flatten()
      .parEach_((next, i) ->
        target = targets[i-1]
        extname = path.extname(target)
        basename = path.basename(target, '.*')
        zf.readFile target, (err, f) ->
          cmd = IMAGEMAGICK
          args = []
          if extname.match(/\.jpe?g/)
            args.push '-define'
            args.push "jpeg:size=#{size}"
          args.push '-resize'
          args.push size
          args.push '-'
          args.push "public/images/thumbs/#{basename}-#{i}"
          im = spawn cmd, args
          im.on 'exit', (code) ->
            if code == 0
              next(null, code)
            else
              next(code)

          im.stdin.write f
          im.stdin.end()
      )
      .seq_((next) =>
        console.log "[Success] Create Thumnails: #{@path}"
      )
}

exports.Book = Book
