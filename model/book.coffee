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
  find_or_new: (filename, callback) ->
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
        callback(null, book)
      )
      .catch((err) ->
        callback(err)
      )

}

Book.method {
  get_md5: (callback) ->
    book = this
    md5sum = crypto.createHash 'md5'
    rs = fs.createReadStream @path, {start: 0, end: 100 * 1024}

    rs.on 'data', (d) ->
      md5sum.update d

    rs.on 'end', ->
      md5 = md5sum.digest 'hex'
      book.md5_hash = md5
      callback(null, book)

    rs.on 'error', (exception) ->
      console.log "[Failed] Get MD5 Error: #{book.path}"
      callback(exception)

  play: (player, args) ->
    pl = spawn player, args
    pl.on 'exit', (code) ->
      msg = "Player process exited with code #{code}"
      console.log msg


  image_files: (count = 6) ->
    zf = new zipfile.ZipFile @path
    targets = []
    image_files = zf.names.map((name, i) ->
      if name.match /\.(jpe?g|png)/
        return {name: name, idx: i}
    ).filter (files, i) ->
      !!files
    if image_files.length > (count - 1)
      for i in [0..count-1]
        targets.push image_files[(i * parseInt(image_files.length / count))].idx
    else
      last = image_files.length - 1
      if image_files.length > 0
        i = 0
        while targets.length < count
          targets.push image_files[i].idx
          i++ if i < last
    return targets

  create_thumbnail: (count = 6, options..., callback) ->
    book = this
    size = options[0] ? "160x120"
    zf = new zipfile.ZipFile @path
    targets = this.image_files count

    fs.stat path.join(THUMBNAILS_PATH, "#{@title}-#{@md5_hash}.jpg"), (err) =>
      if err
        if targets.length < 1
          return callback("[Failed] Image File is nothing: #{@path}")
        Seq()
          .seq_((next) ->
            next(null, [1..count])
          )
          .flatten()
          .parEach_((next, i) ->
            target = targets[i-1]
            extname = path.extname(zf.names[target])
            zf.readFileIndex target, (err, f) ->
              if err
                return next(err)

              # エラーじゃないけど、ファイルサイズが0になる場合ダミー画像を利用する
              unless f.length > 0
                cp = spawn "cp", ["public/images/dummy.jpg", path.join(THUMBNAILS_PATH, "#{book.title}-#{i}.jpg")]
                cp.on 'exit', (code) ->
                  if code == 0 then next() else next(code)
                cp.stdin.end()
              else
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
                  if code == 0 then next() else next(code)

                if f.length > 200 * 1024
                  start = 0
                  end = 200 * 1024
                  while end <= f.length
                    buf = f.slice(start, end)
                    im.stdin.write buf
                    start = end
                    end += 200 * 1024
                  buf = f.slice(start)
                  im.stdin.write buf
                else
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
      else
        console.log "Thumbnail Already Exist: #{@path}"
        callback(null, this)

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
