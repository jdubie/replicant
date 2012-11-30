_ = require 'underscore'

config = require 'config'

BaseValidator            = require 'validation/base'
EndorsementValidatorSync = require('crossing-guard').endorsement

module.exports = class EndorsementValidator extends EndorsementValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()
