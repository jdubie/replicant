_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
EmailAddressValidatorSync = require('crossing-guard').email_address

class EmailAddressValidator extends EmailAddressValidatorSync
  @extend BaseValidator

  db: => config.db.user(@userCtx.user_id)

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = EmailAddressValidator
