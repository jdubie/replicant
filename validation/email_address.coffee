_ = require('underscore')

BaseValidator = require('validation/base')
EmailAddressValidatorSync = require('crossing-guard').email_address

class EmailAddressValidator extends EmailAddressValidatorSync
  @include BaseValidator

  validateAsync: (newDoc, oldDoc, options, callback) =>
    callback()


module.exports = EmailAddressValidator
