var Movie, Schema, mongoose;
mongoose = require('mongoose');
Schema = mongoose.Schema;
Movie = new Schema({
  name: {
    type: String,
    required: true,
    index: true
  },
  path: {
    type: String,
    required: true,
    index: {
      unique: true,
      dropDups: true
    }
  },
  length: {
    type: Number
  },
  size: {
    type: Number,
    required: true
  },
  regist_date: {
    type: Date,
    index: true
  },
  view_count: {
    type: Number,
    "default": 0
  },
  container: {
    type: String
  },
  resolution: {
    type: String
  },
  video_codec: {
    type: String
  },
  video_bitrate: {
    type: Number
  },
  audio_codec: {
    type: String
  },
  audio_bitrate: {
    type: Number
  },
  audio_sample: {
    type: Number
  },
  tag: [String],
  md5_hash: {
    type: String,
    required: true
  },
  title: {
    type: String
  },
  artist: {
    type: String
  },
  album: {
    type: String
  },
  genre: {
    type: String
  },
  track: {
    type: String
  }
});
exports.Movie = Movie;