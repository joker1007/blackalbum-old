{exec} = require 'child_process'
events = require 'events'

FFMPEG = 'ffmpeg'

class FFmpegInfo
  constructor: ->

  get_info: (filename, callback) ->
    try
      exec "#{FFMPEG} -i \"#{filename}\" 2>&1", (err, stdout, stderr) ->
        input_match = stdout.match /Input #\d+, ([a-zA-Z0-9]+),/
        container = input_match[1] if input_match
        video_match = stdout.match /Stream #.*: Video: ([a-zA-Z0-9]+?),.*, (\d+x\d+)/
        video_codec = video_match[1] if video_match
        resolution = video_match[2] if video_match
        video_bitrate_match = stdout.match /Stream #.*: Video:.* (\d+) kb\/s/
        video_bitrate = parseInt(video_bitrate_match[1]) if video_bitrate_match

        audio_match = stdout.match /Stream #.*: Audio: ([a-zA-Z0-9]+?),.* (\d+) Hz,.*, (\d+) kb\/s/
        audio_codec = audio_match[1] if audio_match
        audio_sample = parseInt(audio_match[2]) if audio_match
        audio_bitrate = parseInt(audio_match[3]) if audio_match

        length_match = stdout.match /Duration: (\d\d):(\d\d):(\d\d)/
        hour = parseInt(length_match[1], 10) * 3600
        minute = parseInt(length_match[2], 10) * 60
        second = parseInt(length_match[3], 10)
        length =  hour + minute + second
        info = {container:container, video_codec: video_codec, resolution: resolution, video_bitrate: video_bitrate, audio_codec: audio_codec, audio_sample: audio_sample, audio_bitrate: audio_bitrate, length: length}
        callback(err, info)
    catch error
      console.log filename
      throw error

ffmpeg_info = new FFmpegInfo
module.exports = ffmpeg_info
