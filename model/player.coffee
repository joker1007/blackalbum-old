mongoose = require 'mongoose'
Schema = mongoose.Schema

Player = new Schema {
  name: {type: String, required: true}
  path: {type: String, required: true}
}

Player.method {
  form_action_url: ->
    if this.isNew
      return "/player"
    else
      return "/player/#{this._id}"
  form_mode: ->
    if this.isNew
      return "new"
    else
      return "edit"
}

exports.Player = Player
