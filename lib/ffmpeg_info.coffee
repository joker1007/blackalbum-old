{exec} = require 'child_process'
events = require 'events'

FFMPEG = 'ffmpeg'

class FFmpegInfo
  constructor: ->

  get_info: (filename, callback) ->
    exec "#{FFMPEG} -i \"#{filename}\" 2>&1", (err, stdout, stderr) ->
      input_match = stdout.match /Input #\d+, ([a-zA-Z0-9]+),/
      container = if input_match then input_match[1] else "Unknown"
      video_match = stdout.match /Stream #.*: Video: ([a-zA-Z0-9]+?)(\s|,).*, (\d+x\d+)/
      video_codec = if video_match then video_match[1] else "Unknown"
      resolution = video_match[3] if video_match
      video_bitrate_match = stdout.match /Stream #.*: Video:.* (\d+) kb\/s/
      video_bitrate = parseInt(video_bitrate_match[1]) if video_bitrate_match

      audio_match = stdout.match /Stream #.*: Audio: ([a-zA-Z0-9]+?),.* (\d+) Hz/
      audio_codec = if audio_match then audio_match[1] else "Unknown"
      audio_sample = parseInt(audio_match[2]) if audio_match
      audio_bitrate_match = stdout.match /Stream #.*: Audio:.* (\d+) kb\/s/
      audio_bitrate = parseInt(audio_bitrate_match[1]) if audio_bitrate_match

      length_match = stdout.match /Duration: (\d\d):(\d\d):(\d\d)/
      hour = parseInt(length_match[1], 10) * 3600 if length_match
      minute = parseInt(length_match[2], 10) * 60 if length_match
      second = parseInt(length_match[3], 10) if length_match
      length =  hour + minute + second if length_match
      if input_match or video_match or video_bitrate_match or audio_match or length_match
        info = {container:container, video_codec: video_codec, resolution: resolution, video_bitrate: video_bitrate, audio_codec: audio_codec, audio_sample: audio_sample, audio_bitrate: audio_bitrate, length: length}
        callback(null, info)
      else
        callback(err)

ffmpeg_info = new FFmpegInfo
module.exports = ffmpeg_info
