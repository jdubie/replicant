_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
ApplicationValidatorSync = require('crossing-guard').application

class ApplicationValidator extends ApplicationValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = ApplicationValidator
