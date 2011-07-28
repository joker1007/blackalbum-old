mongoose = require 'mongoose'
Schema = mongoose.Schema

Watch = new Schema {
  dir: {type: String, required: true}
}

exports.Watch = Watch
