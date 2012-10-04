config = require 'config'

BaseValidator = require('validation/base')
MessageValidatorSync = require('crossing-guard').message

class MessageValidator extends MessageValidatorSync
  @extend BaseValidator

  db: => config.db.constable()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = MessageValidator
