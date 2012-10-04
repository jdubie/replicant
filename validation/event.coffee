config = require 'config'

BaseValidator = require('validation/base')
EventValidatorSync = require('crossing-guard').event

class EventValidator extends EventValidatorSync
  @extend BaseValidator

  db: => config.db.constable()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = EventValidator
