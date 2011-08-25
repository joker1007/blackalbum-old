mongoose = require 'mongoose'
Schema = mongoose.Schema
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
Seq = require 'seq'
{spawn} = require 'child_process'
{FFmpegThumbnailer} = require '../lib/ffmpegthumbnailer'
ffmpeg_info = require '../lib/ffmpeg_info'
zipfile = require 'zipfile'

IMAGEMAGICK = 'convert'
THUMBNAILS_PATH = "public/images/thumbs"

EntrySchema = new Schema {
  name: {type: String, required: true, index: true}
  path: {type: String, required: true, index: {unique: true, dropDups: true}}
  length: {type: Number}
  size: {type: Number, required: true}
  regist_date: {type: Date, index: true}
  view_count: {type: Number, default: 0}
  container: {type: String}
  resolution: {type: String}
  video_codec: {type: String}
  video_bitrate: {type: Number}
  audio_codec: {type: String}
  audio_bitrate: {type: Number}
  audio_sample: {type: Number}
  tag: [String]
  md5_hash: {type: String, required: true}
  title: {type: String}
  artist: {type: String}
  album: {type: String}
  genre: {type: String}
  track: {type: String}
}

EntrySchema.static {
  find_or_new: (filename, callback) ->
    M = this
    Seq()
      .seq_((next) ->
        M.findOne {path: filename}, next
      )
      .seq_((next, entry) =>
        if !entry
          fs.stat filename, next
        else
          callback(null, entry)
      )
      .seq_((next, stat) ->
        entry = new M
        entry.path ?= filename
        entry.name ?= path.basename filename
        entry.title ?= path.basename(filename).replace /\.[a-zA-Z0-9]+$/, ""
        entry.size ?= stat.size
        entry.regist_date ?= Date.now()
        callback(null, entry)
      )
      .catch((err) ->
        callback(err)
      )
}

EntrySchema.method {
  length_str: ->
    if this.length
      hour = parseInt(this.length / 3600)
      hour = if hour < 10 then "0#{hour}" else "#{hour}"
      min = parseInt((this.length % 3600) / 60)
      min = if min < 10 then "0#{min}" else "#{min}"
      sec = this.length % 60
      sec = if sec < 10 then "0#{sec}" else "#{sec}"
      return "#{hour}:#{min}:#{sec}"
    else
      return "00:00:00"

  play: (player, args) ->
    pl = spawn player, args
    pl.on 'exit', (code) ->
      msg = "Player process exited with code #{code}"
      console.log msg

  get_md5: (callback) ->
    entry = this
    md5sum = crypto.createHash 'md5'
    rs = fs.createReadStream @path, {start: 0, end: 100 * 1024}

    rs.on 'data', (d) ->
      md5sum.update d

    rs.on 'end', =>
      md5 = md5sum.digest 'hex'
      entry.md5_hash = md5
      callback(null, entry)

    rs.on 'error', (exception) ->
      console.log "[Failed] Get MD5 Error: #{entry.path}"
      rs.destroy()
      callback(exception)

  get_info_movie: (callback) ->
    movie = this
    ffmpeg_info.get_info @path, (err, info) ->
      if !err
        movie.set('container', info.container) unless movie.container == info.container
        movie.set('video_codec', info.video_codec) unless movie.video_codec == info.video_codec
        movie.set('audio_codec', info.audio_codec) unless movie.audio_codec == info.audio_codec
        movie.set('length', info.length) unless movie.length == info.length
        movie.set('resolution', info.resolution) unless movie.resolution == info.resolution
        movie.set('video_bitrate', info.video_bitrate) unless movie.video_bitrate == info.video_bitrate
        movie.set('audio_bitrate', info.audio_bitrate) unless movie.audio_bitrate == info.audio_bitrate
        movie.set('audio_sample', info.audio_sample) unless movie.audio_sample == info.audio_sample
        callback(null, movie)
      else
        callback(err)


  create_thumbnail_movie: (count = 6, options..., callback) ->
    size = options[0] ? "200x150"
    fs.stat path.join(THUMBNAILS_PATH, "#{@title}-#{@md5_hash}.jpg"), (err) =>
      if err
        thumbnailer = new FFmpegThumbnailer
        thumbnailer.multi_create count, @path, path.join(THUMBNAILS_PATH, "#{@title}.jpg"), size
        thumbnailer.on 'multi_end', (args) =>
          console.log "[Success] Create Thumbnail: #{@path}"
          this.merge_thumbnail count, callback
        thumbnailer.on 'multi_error', (err) =>
          console.log "[Failed] Create Thumbnail: #{@path}"
          this.clear_thumbnail count, callback
      else
        callback(null, this)

  image_files_zip: (count = 6) ->
    zf = new zipfile.ZipFile @path
    targets = []
    image_files = zf.names.map((name, i) ->
      if name.match /\.(jpe?g|png)/i
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

  create_thumbnail_zip: (count = 6, options..., callback) ->
    book = this
    size = options[0] ? "160x120"
    zf = new zipfile.ZipFile @path
    targets = this.image_files_zip count

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
            f = zf.readFileSyncIndex target
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
      .seq((next) =>
        console.log "[Success] Clear Thumbnails: #{@path}"
        callback(null, this)
      )
      .catch((err) =>
        console.log "[Failed] Clear Thumbnails: #{@path}"
        callback(null, this)
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

exports.EntrySchema = EntrySchema
