_ = require 'underscore'

config = require 'config'

BaseValidator = require 'validation/base'
CompanyRequestValidatorSync = require('crossing-guard').company_request

class CompanyRequestValidator extends CompanyRequestValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = CompanyRequestValidator
