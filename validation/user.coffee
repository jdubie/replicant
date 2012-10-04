config = require 'config'

BaseValidator = require('validation/base')
UserValidatorSync = require('crossing-guard').user

class UserValidator extends UserValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = UserValidator
