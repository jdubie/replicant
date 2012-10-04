_ = require('underscore')

config = require 'config'

BaseValidator = require('validation/base')
EntityValidatorSync = require('crossing-guard').entity

class EntityValidator extends EntityValidatorSync
  @extend BaseValidator

  db: => config.db.main()

  validateAsync: (newDoc, oldDoc, options, callback) =>
    if not callback?
      callback = options
      options = {}
    callback()


module.exports = EntityValidator
