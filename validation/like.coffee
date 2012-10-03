_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
LikeValidatorSync = require('crossing-guard').like

class LikeValidator extends LikeValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = LikeValidator
