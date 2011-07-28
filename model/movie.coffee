mongoose = require 'mongoose'
Schema = mongoose.Schema
{spawn} = require 'child_process'

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
      io.sockets.emit 'player_exit', msg
}

exports.Movie = Movie
