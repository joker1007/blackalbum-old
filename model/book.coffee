mongoose = require 'mongoose'
Schema = mongoose.Schema
path = require 'path'
fs = require 'fs'
crypto = require 'crypto'
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

Book.static {
  get_book: (filename, callback) ->
    B = this
    Seq()
      .seq_((next) ->
        B.findOne {path: filename}, next
      )
      .seq_((next, book) =>
        if !book
          fs.stat filename, next
        else
          callback(null, book)
      )
      .seq_((next, stat) ->
        book = new B
        book.path ?= filename
        book.name ?= path.basename filename
        book.title ?= path.basename(filename).replace /\.[a-zA-Z0-9]+$/, ""
        book.size ?= stat.size
        book.regist_date ?= Date.now()
        next(null, book)
      )
      .seq_((next, book) ->
        md5sum = crypto.createHash 'md5'
        rs = fs.createReadStream filename, {start: 0, end: 100 * 1024}

        rs.on 'data', (d) ->
          md5sum.update d

        rs.on 'end', =>
          md5 = md5sum.digest 'hex'
          book.md5_hash = md5
          next(null, book)

        rs.on 'error', (exception) =>
          console.log "[Failed] Get MD5 Error: #{filename}"
          next(exception)
      )
      .seq_((next, book) ->
        callback(null, book)
      )
      .catch((err) ->
        callback(err)
      )

}

Book.method {
  image_files: (count = 6) ->
    zf = new zipfile.ZipFile @path
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
    return targets

  create_thumbnail: (count = 6, options..., callback) ->
    book = this
    size = options[0] ? "160x120"
    zf = new zipfile.ZipFile @path
    targets = this.image_files count

    Seq()
      .seq_((next) ->
        next(null, [1..count])
      )
      .flatten()
      .parEach_((next, i) ->
        target = targets[i-1]
        extname = path.extname(target)
        zf.readFile target, (err, f) ->
          if err
            return next(err)
          cmd = IMAGEMAGICK
          args = []
          if extname.match(/\.jpe?g/)
            args.push '-define'
            args.push "jpeg:size=#{size}"
          args = args.concat ['-resize', size, '-background', 'black', '-compose', 'Copy', '-gravity', 'center', '-extent', size]
          args.push '-'
          args.push path.join(THUMBNAILS_PATH, "#{book.title}-#{i}.jpg")
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
        this.merge_thumbnail count, callback
      )
      .catch((err) =>
        console.log "[Failed] Create Thumnails: #{@path}"
        this.clear_thumbnail count, callback
      )

  clear_thumbnail: (count = 6, callback) ->
    Seq()
      .seq_((next) ->
        next(null, [1..count])
      )
      .flatten()
      .seqEach_((next, i) =>
        fs.unlink path.join(THUMBNAILS_PATH, "#{@title}-#{i}.jpg"), next
      )
      .seq_((next) =>
        console.log "[Success] Clear Thumbnails: #{@path}"
        if callback
          callback(null, this)
      )
      .catch((err) =>
        console.log "[Failed] Clear Thumbnails: #{@path}"
        callback(err)
      )

  merge_thumbnail: (count = 6, callback) ->
    Seq()
      .seq_((next) =>
        cmd = IMAGEMAGICK
        args = ["+append"]
        for i in [1..count]
          args.push path.join(THUMBNAILS_PATH, "#{@title}-#{i}.jpg")
        args.push path.join(THUMBNAILS_PATH, "#{@title}-#{@md5_hash}.jpg")
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
        this.clear_thumbnail count, callback
      )
      .catch((err) =>
        console.log "[Failed] Merge Thumbnails: #{@path}"
        this.clear_thumbnail count, callback
      )
}

exports.Book = Book
