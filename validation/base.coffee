_ = require 'underscore'

config = require 'config'

Include =

  # @name db
  # @description returns the database used to get the old document
  #              overwrite in subclasses!
  db: -> config.db.main()

  # @name done
  # @description calls back errors in the couchdb/replicant format
  #              if no errors exist, then calls back with null
  # @param callback {Function} callback function
  done: (callback) ->
    return callback() if _.isEmpty(@errors)
    callback(statusCode: 403, error: 'forbidden', reason: @errors)

  getOldDoc: (doc, callback) ->
    return callback() if not doc._id
    @db().get doc._id, (err, doc) ->
      callback(null, doc ? null)    # ignore the error (not found)

  # @name ensureUserCtx
  # @description throws error if userCtx is not defined or does not
  #              have all requisite fields
  # @returns {Bool} whether validation passed
  #                 (true if it passed, false if it failed validation)
  ensureUserCtx: ->
    userCtxKeys = ['name', 'roles', 'user_id']
    if not @userCtx?
      @throw('userCtx', 'No user context specified')
      return false
    else
      existingKeys = (key for key of @userCtx)
      for key in userCtxKeys when key not in existingKeys
        @throw('userCtx', "User context missing key: #{key}")
        return false
    return true

  # @name validateDoc
  # @description validates a database document server-side (in express)
  #              will callback(errors) if there are errors
  #
  # @param newDoc {Object} the new document
  # @param options {Object} (optional) options to validate with
  # @param callback {Function} function to call after validation
  validateDoc: (doc, options, callback) ->
    if not callback?
      callback = options
      options = {}
    return @done(callback) if not @ensureUserCtx()
    @getOldDoc doc, (err, oldDoc) =>
      @validate(doc, oldDoc, options)
      return @done(callback) if not _.isEmpty(@errors)
      @validateAsync doc, oldDoc, options, () => @done(callback)


  # @name validateAsync
  # @description the asynchronous part of validateDoc
  #              subclasses should call `super` then perform validation
  # TODO: do `not` call `super`, just overwrite
  #       figure out how this all works
  #       does it make sense to call `super` when the `super` function
  #         has been gotten by `extend`?
  validateAsync: (newDoc, oldDoc, options, callback) ->
    if not callback?
      callback = options
      options = {}

    ## perform the validation (accumulating errors) ##
    ## callback() ##


BaseValidator =
  extended: ->
    @include Include

module.exports = BaseValidator
