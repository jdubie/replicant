_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
ReferEmailValidatorSync = require('crossing-guard').refer_email

class ReferEmailValidator extends ReferEmailValidatorSync
  @extend BaseValidator

  db: => config.db.constable()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = ReferEmailValidator
