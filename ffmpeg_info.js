var FFMPEG, FFmpegInfo, events, exec, ffmpeg_info;
exec = require('child_process').exec;
events = require('events');
FFMPEG = 'ffmpeg';
FFmpegInfo = (function() {
  function FFmpegInfo() {}
  FFmpegInfo.prototype.get_info = function(filename, callback) {
    try {
      return exec("" + FFMPEG + " -i \"" + filename + "\" 2>&1", function(err, stdout, stderr) {
        var audio_bitrate, audio_codec, audio_match, audio_sample, container, hour, info, input_match, length, length_match, minute, resolution, second, video_bitrate, video_bitrate_match, video_codec, video_match;
        input_match = stdout.match(/Input #\d+, ([a-zA-Z0-9]+),/);
        if (input_match) {
          container = input_match[1];
        }
        video_match = stdout.match(/Stream #.*: Video: ([a-zA-Z0-9]+?),.*, (\d+x\d+)/);
        video_bitrate_match = stdout.match(/Stream #.*: Video:.* (\d+) kb\/s/);
        if (video_match) {
          video_codec = video_match[1];
        }
        if (video_match) {
          resolution = video_match[2];
        }
        if (video_bitrate_match) {
          video_bitrate = parseInt(video_bitrate_match[1]);
        }
        audio_match = stdout.match(/Stream #.*: Audio: ([a-zA-Z0-9]+?),.* (\d+) Hz,.*, (\d+) kb\/s/);
        if (audio_match) {
          audio_codec = audio_match[1];
        }
        if (audio_match) {
          audio_sample = parseInt(audio_match[2]);
        }
        if (audio_match) {
          audio_bitrate = parseInt(audio_match[3]);
        }
        length_match = stdout.match(/Duration: (\d\d):(\d\d):(\d\d)/);
        hour = parseInt(length_match[1], 10) * 3600;
        minute = parseInt(length_match[2], 10) * 60;
        second = parseInt(length_match[3], 10);
        length = hour + minute + second;
        info = {
          container: container,
          video_codec: video_codec,
          resolution: resolution,
          video_bitrate: video_bitrate,
          audio_codec: audio_codec,
          audio_sample: audio_sample,
          audio_bitrate: audio_bitrate,
          length: length
        };
        return callback(err, info);
      });
    } catch (error) {
      console.log(filename);
      throw error;
    }
  };
  return FFmpegInfo;
})();
ffmpeg_info = new FFmpegInfo;
module.exports = ffmpeg_info;