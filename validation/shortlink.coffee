_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
ShortlinkValidatorSync = require('crossing-guard').shortlink

class ShortlinkValidator extends ShortlinkValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = ShortlinkValidator
