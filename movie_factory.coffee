{FileSearcher} = require './search_file'
thumbnailer = require './ffmpegthumbnailer'
ffmpeg_info = require './ffmpeg_info'
fs = require 'fs'
path = require 'path'
events = require 'events'
crypto = require 'crypto'
{exec} = require 'child_process'
mongoose = require 'mongoose'

{Movie} = require './movie'
movieModel = mongoose.model('Movie', Movie)

class MovieFactory extends events.EventEmitter
  constructor: (@filename) ->
    @movie = new movieModel
    @stats_finish = false
    @md5_finish = false
    @info_finish = false

  get_movie: (thumbnail_count, callback)->
    this.on 'stats_finish', ->
      @stats_finish = true
      if @stats_finish && @md5_finish && @info_finish
        this.create_thumbnail thumbnail_count

    this.on 'md5_finish', ->
      @md5_finish = true
      if @stats_finish && @md5_finish && @info_finish
        this.create_thumbnail thumbnail_count

    this.on 'info_finish', ->
      @info_finish = true
      if @stats_finish && @md5_finish && @info_finish
        this.create_thumbnail thumbnail_count

    this.on 'thumbnail_finish', ->
      callback(@movie)
      

    this.get_stats()
    this.get_md5_hash()
    this.get_info()

  get_stats: ->
    try
      fs.stat @filename, (err, stats) =>
        if !err
          @movie.path = @filename
          @movie.name = path.basename @filename
          @movie.title = path.basename(@filename).replace /\.[a-zA-Z0-9]+$/, ""
          @movie.size = stats.size
          @movie.regist_date = Date.now()
        this.emit 'stats_finish'
    catch error
      console.log error
      console.log error.stack
      this.emit 'stats_finish'

  get_md5_hash: ->
    md5sum = crypto.createHash 'md5'
    try
      rs = fs.createReadStream @filename, {start: 0, end: 100 * 1024}
      rs.on 'data', (d) ->
        md5sum.update d

      rs.on 'end', =>
        md5 = md5sum.digest 'hex'
        @movie.md5_hash = md5
        this.emit 'md5_finish'
    catch error
      console.log error
      console.log error.stack
      this.emit 'md5_finish'

  get_info: ->
    try
      ffmpeg_info.get_info @filename, (err, info) =>
        @movie.container = info.container ? "Unknown"
        @movie.video_codec = info.video_codec ? "Unknown"
        @movie.audio_codec = info.audio_codec ? "Unknown"
        @movie.length = info.length ? 0
        @movie.video_bitrate = info.video_bitrate
        @movie.audio_bitrate = info.audio_bitrate
        @movie.audio_sample = info.audio_sample
        this.emit 'info_finish'
    catch error
      console.log "[Failed] Get Info: #{@filename}"
      this.emit 'info_finish'

  create_thumbnail: (count)->
    fs.stat "thumbs/#{@movie.title}-#{@movie.md5_hash}.jpg", (err) =>
      if err
        try
          thumbnailer.multi_create count, @filename, "thumbs/#{@movie.title}.jpg", "200x150", (err2, args) =>
            if err2
              console.log "[Failed] Create Thumbnail: #{@filename}"
              this.emit 'thumbnail_finish'
            else
              console.log "[Success] Create Thumbnail: #{@filename}"
              this.merge_thumbnail args.count
        catch error
          console.log error
          for j in [1..count]
            fs.unlink "thumbs/#{@movie.title}-#{j}.jpg", (err4) =>
              if err4
                console.log err4
          this.emit 'thumbnail_finish'
      else
        console.log "Thumbnail Already Exist: #{@filename}"
        this.emit 'thumbnail_finish'


  merge_thumbnail: (count) ->
    files = ''
    for i in [1..count]
      files += "\"thumbs/#{@movie.title}-#{i}.jpg\" "

    try
      exec "convert +append #{files} \"thumbs/#{@movie.title}-#{@movie.md5_hash}.jpg\"", (err, stdout, stderr) =>
        throw "[Failed] Merge Thumbnails: #{@filename}" if err
        console.log "[Success] Merge Thumbnails: #{@filename}"
    catch errmsg
      console.log errmsg
    finally
      for j in [1..count]
        fs.unlink "thumbs/#{@movie.title}-#{j}.jpg", (err2) =>
          if err2
            console.log err2

      this.emit 'thumbnail_finish'

exports.MovieFactory = MovieFactory
