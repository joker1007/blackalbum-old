mongoose = require 'mongoose'
Schema = mongoose.Schema

Player = new Schema {
  name: {type: String, required: true}
  path: {type: String, required: true}
}

exports.Player = Player
