async = require('async')
request = require('request')
debug = require('debug')('replicant:helpers')
crypto = require('crypto')

config = require('config')

h = {}

###
  @param userId {string}
  @return {string}
###
h.getUserDbName = ({userId}) -> "users_#{userId}"

###
  @description returns _user id given name
  @param userId {string}
  @return {string}
###
h.getCouchUserName = (name) -> "org.couchdb.user:#{name}"

###
  gets login
###
h.getUserId = ({cookie, userCtx}, callback) ->

  res = (err, _userDoc) ->
    userCtx.roles = _userDoc?.roles
    userCtx.user_id = _userDoc?.user_id
    callback(err, userCtx)

  nanoOpts =
    url: "#{config.dbUrl}/_users"
    cookie: cookie
  userPrivateNano = require('nano')(nanoOpts)
  userPrivateNano.get("org.couchdb.user:#{userCtx.name}", h.nanoCallback(res))

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
      h.request(opts, next)   ## returns body object with userCtx key
    ({userCtx}, next) ->
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
    swaps   : 'swap'
    users   : 'user'
    reviews : 'review'
    likes   : 'like'
    requests: 'request'
    # user db
    events         : 'event'
    messages       : 'message'
    cards          : 'card'
    payments       : 'payment'
    email_addresses: 'email_address'
    phone_numbers  : 'phone_number'
    refer_emails   : 'refer_email'
  return mapping[model]

h.pluralizeType = (type) ->
  mapping =
    # lifeswap db
    swap   : 'swaps'
    user   : 'users'
    review : 'reviews'
    like   : 'likes'
    request: 'requests'
    # user db
    event        : 'events'
    message      : 'messages'
    card         : 'cards'
    payment      : 'payments'
    email_address: 'email_addresses'
    phone_number : 'phone_numbers'
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

###
  @name createNotification
###
h.createNotification = (name, data, callback) ->
  config.jobs.create("notification.#{name}", data).save (err) ->
    return callback() unless err
    callback(statusCode: 500, error: 'Notification error', reason: err)


###
  @name nanoCallback
  @description normalizes nano responses to resopnses that ROCK
###
h.nanoCallback = (next, opts) ->
  {error, reason} = opts if opts?
  (err, res...) ->
    if err?
      debug '#nanoCallback: err', err
      errorRes =
        statusCode: err.status_code ? 500
        error: err.error ? error
        reason: err.reason ? reason
    next(errorRes, res...)

###
  @param model {string} plural model
  @param doc {object} model doc just created
  @param callback {function}
###
h.createSimpleCreateNotification = (model, doc, callback) ->
  notableEvents = [ 'swap', 'like', 'refer_email' ]
  model = h.singularizeModel(model)
  debug 'helpers#createNotification', model
  return callback() unless model in notableEvents
  debug 'adding to kue', model, doc
  notification = title: "user_id: #{doc.user_id}"
  notification.title += ", swap_id: #{doc.swap_id}" if doc.swap_id?
  notification[model] = doc
  h.createNotification "#{model}.create", notification, (err) ->
    error = undefined
    if err
      error =
        statusCode: 500
        error: 'Notification error'
        reason: err
    callback(error) # should be undefined


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


# createUser
#
#
h.createUser = ({user, roles}, callback) ->

  mainDb = config.nanoAdmin.db.use('lifeswap')
  usersDb = config.nanoAdmin.db.use('_users')
  userDbName = h.getUserDbName(userId: user._Id)

  user.name = h.hash(user.email_address)
  couchUser = "org.couchdb.user:#{user.name}"

  insertUser = (_callback) ->
    async.parallel
      _userDoc: (cb) ->
        userDoc =
          _id: couchUser
          type: 'user'
          name: user.name
          password: user.password
          roles: roles
          user_id: user._id
        usersDb.insert(userDoc, cb)
      _rev: (cb) ->
        mainDb.insert user, user._id, (err, res) ->
          return cb(err) if err
          cb(null, res.rev)
      admin: (cb) ->
        config.nanoAdmin.db.create("users_#{user._id}", cb)
        #, _callback
    , (err, res) ->
      debug '#createUser err, res', err, res
      _callback(err, res)

  authUser = (res, _callback) ->
    {_rev} = res
    user._rev = _rev
    config.nano.auth user.name, user.password, (err, body, hdr) ->
      debug '#createUser err, body, hdr', err, body, hdr
      return _callback(err) if err
      cookie = hdr['set-cookie'][0] if hdr['set-cookie']
      return _callback('no cookie') unless cookie
      debug '#createUser cookie, _rev', cookie, _rev
      _callback(null, {cookie, _rev, couchUser})

  async.waterfall([insertUser, authUser], callback)


# destroyUser
#
#
h.destroyUser = ({_id, name}, callback) ->
  _userId = _id
  userDbName = h.getUserDbName(userId: _userId)
  usersDb = config.nanoAdmin.db.use('_users')
  mainDb = config.nanoAdmin.db.use('lifeswap')

  couchUser = "org.couchdb.user:#{name}"

  destroyUser = (callback) ->
    usersDb.get couchUser, (err, userDoc) ->
      return callback() if err?   # should error
      usersDb.destroy(couchUser, userDoc._rev, callback)
  destroyLifeswapUser = (callback) ->
    mainDb.get _userId, (err, userDoc) ->
      return callback() if err?   # should error
      mainDb.destroy(_userId, userDoc._rev, callback)
  destroyUserDb = (callback) ->
    config.nanoAdmin.db.list (err, dbs) ->
      return callback() if not (userDbName in dbs)  # should callback
      config.nanoAdmin.db.destroy(userDbName, callback)

  async.parallel [
    destroyUser
    destroyLifeswapUser
    destroyUserDb
  ], callback

module.exports = h
