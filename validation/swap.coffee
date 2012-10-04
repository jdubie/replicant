_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
SwapValidatorSync = require('crossing-guard').swap

class SwapValidator extends SwapValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = SwapValidator
