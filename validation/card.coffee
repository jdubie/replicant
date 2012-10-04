_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
CardValidatorSync = require('crossing-guard').card

class CardValidator extends CardValidatorSync
  @extend BaseValidator

  db: => config.db.constable()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = CardValidator
