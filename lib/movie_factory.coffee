{FFmpegThumbnailer} = require './ffmpegthumbnailer'
ffmpeg_info = require './ffmpeg_info'
fs = require 'fs'
path = require 'path'
events = require 'events'
crypto = require 'crypto'
{exec} = require 'child_process'
mongoose = require 'mongoose'
Seq = require 'seq'

{Movie} = require '../model/movie'
movieModel = mongoose.model('Movie', Movie)

class MovieFactory extends events.EventEmitter
  constructor: (@filename) ->
    @stats_finish = false
    @md5_finish = false
    @info_finish = false
    @error = null

  get_movie: (thumbnail_count, force = false, callback)->
    movieModel.findOne {path: @filename}, (err, movie) =>
      if !force and movie
        @movie = movie
        this.emit 'md5_finish'
        this.emit 'stats_finish'
        this.emit 'info_finish'
      else
        @movie = new movieModel
        this.get_md5_hash()
        this.get_stats()
        this.get_info()

    this.on 'stats_finish', (err) ->
      @error = err if err
      @stats_finish = true
      if @stats_finish && @md5_finish && @info_finish
        if @error
          callback(@error)
        else
          this.create_thumbnail thumbnail_count

    this.on 'md5_finish', (err) ->
      @error = err if err
      @md5_finish = true
      if @stats_finish && @md5_finish && @info_finish
        if @error
          callback(@error)
        else
          this.create_thumbnail thumbnail_count

    this.on 'info_finish', (err) ->
      @error = err if err
      @info_finish = true
      if @stats_finish && @md5_finish && @info_finish
        if @error
          callback(@error)
        else
          this.create_thumbnail thumbnail_count

    this.on 'thumbnail_finish', ->
      callback(null, @movie)


  get_stats: ->
    fs.stat @filename, (err, stats) =>
      if !err
        @movie.path ?= @filename
        @movie.name ?= path.basename @filename
        @movie.title ?= path.basename(@filename).replace /\.[a-zA-Z0-9]+$/, ""
        @movie.size ?= stats.size
        @movie.regist_date ?= Date.now()
      else
        console.log "[Failed] Get Stats Error: #{@filename}"
      this.emit 'stats_finish', err

  get_md5_hash: ->
    md5sum = crypto.createHash 'md5'
    rs = fs.createReadStream @filename, {start: 0, end: 100 * 1024}
    rs.on 'data', (d) ->
      md5sum.update d

    rs.on 'end', =>
      md5 = md5sum.digest 'hex'
      @movie.md5_hash = md5
      this.emit 'md5_finish'

    rs.on 'error', (exception) =>
      console.log "[Failed] Get MD5 Error: #{@filename}"
      this.emit 'md5_finish', exception

  get_info: ->
    ffmpeg_info.get_info @filename, (err, info) =>
      if !err
        @movie.container = info.container ? "Unknown"
        @movie.video_codec = info.video_codec ? "Unknown"
        @movie.audio_codec = info.audio_codec ? "Unknown"
        @movie.length = info.length ? 0
        @movie.resolution = info.resolution
        @movie.video_bitrate = info.video_bitrate
        @movie.audio_bitrate = info.audio_bitrate
        @movie.audio_sample = info.audio_sample
      else
        console.log "[Failed] Get Info: #{@filename}"
      this.emit 'info_finish', err

  create_thumbnail: (count)->
    fs.stat "public/images/thumbs/#{@movie.title}-#{@movie.md5_hash}.jpg", (err) =>
      if err
        thumbnailer = new FFmpegThumbnailer
        thumbnailer.multi_create count, @filename, "public/images/thumbs/#{@movie.title}.jpg", "200x150"
        thumbnailer.on 'multi_end', (args) =>
          console.log "[Success] Create Thumbnail: #{@filename}"
          this.merge_thumbnail args.count
        thumbnailer.on 'multi_error', (err) =>
          console.log "[Failed] Create Thumbnail: #{@filename}"
          Seq()
            .seq_((next) ->
              next(null, [1..count])
            )
            .flatten()
            .seqEach_((next, i) =>
              fs.unlink "public/images/thumbs/#{@movie.title}-#{i}.jpg", next
            )
            .seq((next) =>
              this.emit 'thumbnail_finish'
            )
            .catch((err) =>
              this.emit 'thumbnail_finish', err
            )

      else
        console.log "Thumbnail Already Exist: #{@filename}"
        this.emit 'thumbnail_finish'


  merge_thumbnail: (count) ->
    files = ''
    for i in [1..count]
      files += "\"public/images/thumbs/#{@movie.title}-#{i}.jpg\" "

    Seq()
      .seq_((next) =>
        cmd = "convert +append #{files} \"public/images/thumbs/#{@movie.title}-#{@movie.md5_hash}.jpg\""
        exec cmd, {maxBuffer: 1000*1024}, next
      )
      .seq_((next) =>
        console.log "[Success] Merge Thumbnails: #{@filename}"
        next(null, [1..count])
      )
      .flatten()
      .seqEach_((next, i) =>
        fs.unlink "public/images/thumbs/#{@movie.title}-#{i}.jpg", next
      )
      .seq_((next) =>
        this.emit 'thumbnail_finish'
      )
      .catch((err) =>
        console.log "[Failed] Merge Thumbnails: #{@filename}"
        console.log err
        this.emit 'thumbnail_finish'
      )

exports.MovieFactory = MovieFactory
