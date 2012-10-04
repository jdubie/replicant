_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
PhoneNumberValidatorSync = require('crossing-guard').phone_number

class PhoneNumberValidator extends PhoneNumberValidatorSync
  @extend BaseValidator

  db: => config.db.constable()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = PhoneNumberValidator
