_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
RequestValidatorSync = require('crossing-guard').request

class RequestValidator extends RequestValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = RequestValidator
