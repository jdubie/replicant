_ = require('underscore')

class BaseValidator
  # @name validateDoc
  # @description validates a database document server-side (in express)
  #              will callback(errors) if there are errors
  #
  # @param newDoc {Object} the new document
  # @param oldDoc {Object} the old document
  # @param options {Object} (optional) options to validate with
  # @param callback {Function} function to call after validation
  validateDoc: (newDoc, oldDoc, options, callback) ->
    if not callback?
      callback = options
      options = {}
    @validate(newDoc, oldDoc, options)
    return callback(@errors) if not _.isEmpty(@errors)
    @validateAsync(newDoc, oldDoc, options, callback)


  # @name validateAsync
  # @description the asynchronous part of validateDoc
  #              subclasses should call `super` then perform validation
  validateAsync: (newDoc, oldDoc, options, callback) ->
    if not callback?
      callback = options
      options = {}


module.exports = BaseValidator
