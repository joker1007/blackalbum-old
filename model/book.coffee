mongoose = require 'mongoose'
Schema = mongoose.Schema
path = require 'path'
fs = require 'fs'
{spawn} = require 'child_process'
zipfile = require 'zipfile'
Seq = require 'seq'

IMAGEMAGICK = 'convert'
THUMBNAILS_PATH = "public/images/thumbs"

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
    fullpath = @path
    basename = path.basename(fullpath, ".zip")
    size = options[0] ? "160x120"
    zf = new zipfile.ZipFile fullpath
    image_files = zf.names.filter (name, i) ->
      name.match /\.(jpe?g|png)/
    if image_files.length > (count - 1)
      targets = image_files.filter (name, i) ->
        (i % parseInt(zf.count / (count - 1))) == 0
      cover = image_files.filter (name, i) ->
        name.match /cover\.(jpe?g|png)/
      if cover[0]
        targets.shift()
        targets.unshift cover[0]
    else
      targets = image_files

    Seq()
      .seq_((next) ->
        next(null, [1..count])
      )
      .flatten()
      .parEach_((next, i) ->
        target = targets[i-1]
        extname = path.extname(target)
        zf.readFile target, (err, f) ->
          cmd = IMAGEMAGICK
          args = []
          if extname.match(/\.jpe?g/)
            args.push '-define'
            args.push "jpeg:size=#{size}"
          args = args.concat ['-resize', size, '-background', 'black', '-compose', 'Copy', '-gravity', 'center', '-extent', size]
          args.push '-'
          args.push "#{THUMBNAILS_PATH}/#{basename}-#{i}.jpg"
          im = spawn cmd, args
          im.on 'exit', (code) ->
            if code == 0
              next()
            else
              next(code)

          im.stdin.write f
          im.stdin.end()
      )
      .seq_((next) =>
        console.log "[Success] Create Thumnails: #{@path}"
        this.merge_thumbnail count, basename
      )
      .catch((err) =>
        console.log "[Failed] Create Thumnails: #{@path}"
        this.clear_thumbnail count, basename
      )

  clear_thumbnail: (count = 6, basename) ->
    Seq()
      .seq_((next) ->
        next(null, [1..count])
      )
      .flatten()
      .seqEach_((next, i) ->
        fs.unlink "#{THUMBNAILS_PATH}/#{basename}-#{i}.jpg", next
      )
      .seq_((next) =>
        console.log "[Success] Clear Thumbnails: #{@path}"
      )
      .catch((err) =>
        console.log "[Failed] Clear Thumbnails: #{@path}"
      )

  merge_thumbnail: (count = 6, basename) ->
    Seq()
      .seq_((next) =>
        cmd = IMAGEMAGICK
        args = ["+append"]
        for i in [1..count]
          args.push "#{THUMBNAILS_PATH}/#{basename}-#{i}.jpg"
        args.push "#{THUMBNAILS_PATH}/#{basename}-#{@md5_hash}.jpg"
        im = spawn cmd, args
        im.on 'exit', (code) ->
          if code == 0
            next(null, code)
          else
            next(code)

        im.stdin.end()
      )
      .seq_((next) =>
        console.log "[Success] Merge Thumbnails: #{@path}"
        this.clear_thumbnail count, basename
      )
      .catch((err) =>
        console.log "[Failed] Merge Thumbnails: #{@path}"
        this.clear_thumbnail count, basename
      )
}

exports.Book = Book
