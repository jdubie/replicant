_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
ReviewValidatorSync = require('crossing-guard').review

class ReviewValidator extends ReviewValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = ReviewValidator
