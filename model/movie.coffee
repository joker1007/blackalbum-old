mongoose = require 'mongoose'
Schema = mongoose.Schema
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
Seq = require 'seq'
{spawn} = require 'child_process'
{FFmpegThumbnailer} = require '../lib/ffmpegthumbnailer'
ffmpeg_info = require '../lib/ffmpeg_info'

IMAGEMAGICK = 'convert'
THUMBNAILS_PATH = "public/images/thumbs"

Movie = new Schema {
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

Movie.static {
  find_or_new: (filename, callback) ->
    M = this
    Seq()
      .seq_((next) ->
        M.findOne {path: filename}, next
      )
      .seq_((next, movie) =>
        if !movie
          fs.stat filename, next
        else
          callback(null, movie)
      )
      .seq_((next, stat) ->
        movie = new M
        movie.path ?= filename
        movie.name ?= path.basename filename
        movie.title ?= path.basename(filename).replace /\.[a-zA-Z0-9]+$/, ""
        movie.size ?= stat.size
        movie.regist_date ?= Date.now()
        callback(null, movie)
      )
      .catch((err) ->
        callback(err)
      )
}

Movie.method {
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
    movie = this
    md5sum = crypto.createHash 'md5'
    rs = fs.createReadStream @path, {start: 0, end: 100 * 1024}

    rs.on 'data', (d) ->
      md5sum.update d

    rs.on 'end', =>
      md5 = md5sum.digest 'hex'
      movie.md5_hash = md5
      callback(null, movie)

    rs.on 'error', (exception) ->
      console.log "[Failed] Get MD5 Error: #{movie.path}"
      rs.destroy()
      callback(exception)

  get_info: (callback) ->
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


  create_thumbnail: (count = 6, options..., callback) ->
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

exports.Movie = Movie
