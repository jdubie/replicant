async = require('async')
request = require('request')
debug = require('debug')('lifeswap:helpers')
crypto = require('crypto')

config = require('config')

h = {}

###
  @param userId {string}
  @return {string}
###
h.getUserDbName = ({userId}) ->
  return "users_#{userId}"

###
  gets login
###
h.getUserId = ({cookie, userCtx}, callback) ->
  nanoOpts =
    url: "#{config.dbUrl}/_users"
    cookie: cookie
  userPrivateNano = require('nano')(nanoOpts)
  userPrivateNano.get "org.couchdb.user:#{userCtx.name}", (err, _userDoc) ->
    userCtx.roles = _userDoc?.roles
    userCtx.user_id = _userDoc?.user_id
    if err
      err.statusCode = err.status_code ? 403
      err.reason = err.reason ? "Error finding user in database."
    callback(err, userCtx)

###
  getUserCtxFromSession - helper that gets userCtx from session cookie
  @params headers {object.<string, {string|object}>} http headers object
###
h.getUserCtxFromSession = ({headers}, callback) ->
  unless headers?.cookie?
    callback(statusCode: 403, reason: "No session")
    return
  cookie = headers.cookie
  async.waterfall [
    (next) ->
      opts =
        method: 'get'
        url: "#{config.dbUrl}/_session"
        headers: headers
        json: true
      request opts, (err, res, body) ->
        userCtx = body?.userCtx
        if userCtx? then next(null, userCtx)
        else next(statusCode: 403, reason: "No user context.")
    (userCtx, next) ->
      h.getUserId({cookie, userCtx}, next)
  ], callback

###
  @param message {string}
  @return {string}
###
h.hash = (message) ->
  shasum = crypto.createHash('sha1')
  shasum.update(message)
  return shasum.digest('hex')


h.singularizeModel = (model) ->
  mapping =
    # lifeswap db
    swaps:      'swap'
    users:      'user'
    reviews:    'review'
    likes:      'like'
    requests:   'request'
    # user db
    events:           'event'
    messages:         'message'
    cards:            'card'
    email_addresses:  'email_address'
    phone_numbers:    'phone_number'
  return mapping[model]

h.pluralizeType = (type) ->
  mapping =
    # lifeswap db
    swap:       'swaps'
    user:       'users'
    review:     'reviews'
    like:       'likes'
    request:    'requests'
    # user db
    event:          'events'
    message:        'messages'
    card:           'cards'
    email_address:  'email_addresses'
    phone_number:   'phone_numbers'
  return mapping[type]

###
  @param error {string}
  @return {number}
###
## TODO: stoopid - just get err.status_code from (err, res) ->
h.getStatusFromCouchError = (error) ->
  switch error
    when "unauthorized" then return 401
    when "forbidden" then return 403
    when "conflict" then return 409
    when "file_exists" then return 409      # database already exists
    else return 500

h.createNotification = (name, data, callback) ->
  config.jobs.create("notification.#{name}", data).save(callback)


###
  @description send an error
###
h.sendError = (res, err) ->
  debug '## ERROR ##', err
  statusCode = err.statusCode ? 500
  error =
    reason: err.reason
    error : err.error
  res.json(statusCode, error)


h.request = (opts, callback) ->
  request opts, (err, res, body) ->
    if err?                         ## request error
      error =
        statusCode: 500
        error     : 'Request error'
        reason    : err
    else if res.statusCode >= 400   ## couch error
      error =
        statusCode: res.statusCode
        error     : body.error
        reason    : body.reason
    else
      error = null
    callback(error, body)


module.exports = h
