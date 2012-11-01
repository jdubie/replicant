async   = require('async')
request = require('request').defaults(jar: false)
debug   = require('debug')('replicant:helpers')
crypto  = require('crypto')

config     = require('config')
validators = require('validation')

h = {}

###
  @param userId {string}
  @return {string}
###
h.getUserDbName = ({userId}) ->
  if userId is 'drunk_tank' then 'drunk_tank' else "users_#{userId}"

h.getCtx = (req) ->
  req.session.userCtx ? name: null, roles: [], user_id: null

h.setCtx = (req, value) ->
  req.session.userCtx = value

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

  res = (err, _userDoc, headers) ->
    userCtx.roles = _userDoc?.roles
    userCtx.user_id = _userDoc?.user_id
    callback(err, userCtx, headers)

  userPrivateNano = config.db._users(cookie)
  userPrivateNano.get("org.couchdb.user:#{userCtx.name}", h.nanoCallback(res))

###
  getUserCtxFromSession - helper that gets userCtx from session cookie
  @params headers {object.<string, {string|object}>} http headers object
###
h.getUserCtxFromSession = ({headers}, callback) ->
  unless headers?.cookie?
    return callback(statusCode: 403, reason: "No session")
  cookie = headers.cookie
  async.waterfall [
    (next) ->
      opts =
        method: 'get'
        url: "#{config.dbUrl}/_session"
        headers: headers
        json: true
      h.request(opts, next)   # (err, {userCtx}, headers)
    ({userCtx}, _headers, next) ->
      debug '#getUserCtxFromSession userCtx, headers', userCtx, _headers
      if _headers?['set-cookie']
        debug '#getUserCtxFromSession set-cookie', _headers
        headers = _headers
        cookie = headers['set-cookie']
      h.getUserId({cookie, userCtx}, next)  # (err, userCtx, headers)
  ], (err, userCtx, _headers) ->
    headers = _headers if _headers?['set-cookie']
    callback(err, userCtx, headers)

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
    swaps     : 'swap'
    users     : 'user'
    reviews   : 'review'
    likes     : 'like'
    requests  : 'request'
    entities  : 'entity'
    shortlinks: 'shortlink'
    # user db
    events         : 'event'
    messages       : 'message'
    cards          : 'card'
    payments       : 'payment'
    email_addresses: 'email_address'
    phone_numbers  : 'phone_number'
    refer_emails   : 'refer_email'
    notifications  : 'notification'
  return mapping[model]

h.pluralizeType = (type) ->
  mapping =
    # lifeswap db
    swap     : 'swaps'
    user     : 'users'
    review   : 'reviews'
    like     : 'likes'
    request  : 'requests'
    entity   : 'entities'
    shortlink: 'shortlinks'
    # user db
    event        : 'events'
    message      : 'messages'
    card         : 'cards'
    payment      : 'payments'
    email_address: 'email_addresses'
    phone_number : 'phone_numbers'
    notifications: 'notification'
  return mapping[type]

h.getModelFromUrl = (url) -> url.split('/')[1]
h.getTypeFromUrl  = (url) -> h.singularizeModel(h.getModelFromUrl(url))


#
# @name createNotification
#
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


# nanoCallback
#
# @description normalizes nano responses that actually ROCK
#
h.nanoCallback2 = (next, opts) ->
  {error, reason} = opts if opts?
  (err, res) ->
    if err?
      debug '#nanoCallback: err', err
      errorRes =
        statusCode: err.status_code ? 500
        error: err.error ? error
        reason: err.reason ? reason
    next(errorRes, res)

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
  statusCode = err.statusCode ? err.status_code ? 500
  error =
    reason: err.reason
    error : err.error
  res.json(statusCode, error)


# verifyRequiredFields
#
# @description ensures that required fields exist in the request body
#              if any fields do not exist, sends an error and returns false
#              otherwise, returns true
h.verifyRequiredFields = (req, res, fields) ->
  existMissing = false
  error =
    error : 'Missing required request body data'
    reason: {}
  for field in fields
    if not req.body[field]?
      error.reason[field] = ["Missing #{field}"]
      existMissing = true
  if existMissing
    missingFields = (xx for xx of error.reason)
    debug '#verifyRequiredFields missing fields:', missingFields
    res.json(400, error)
  existMissing


# setCookie
#
# @description sets the set-cookie field in a response if set-cookie
#              field is set in headers
# @param res {object} express response object
# @param headers {object} the headers given in a (couchdb) response
h.setCookie = (res, headers) ->
  if headers?['set-cookie']?
    debug 'Set-Cookie', headers
    res.set('Set-Cookie', headers?['set-cookie'])


h.request = (opts, callback) ->
  request opts, (err, res, body) ->
    debug 'h.request headers', res?.headers
    if err?                         ## request error
      debug '#h.request err:', err
      error =
        statusCode: 500
        error     : 'Request error'
        reason    : err
    else if res.statusCode >= 400   ## couch error
      debug '#h.request couch err:', res
      error =
        statusCode: res.statusCode
        error     : body.error
        reason    : body.reason
    else
      error = null
    callback(error, body, res?.headers)   # emulates nano


# replicateOut
#
# @description replicate from constable DB out to user databases
# @param userIds {Array.<String>}
# @param docIds {Array.<String>}
#
h.replicateOut = (userIds, docIds, callback) ->
  replicate = (userId, cb) ->
    userDbName = h.getUserDbName({userId})
    opts = create: true, doc_ids: docIds
    config.couch().db.replicate('drunk_tank', userDbName, opts, h.nanoCallback(cb))
  async.map(userIds, replicate, callback)

# replicateIn
#
# @description replicate from user database to constable DB
# @param userId {String}
# @param docIds {Array.<String>}
#
h.replicateIn = (userId, docIds, callback) ->
  userDbName = h.getUserDbName({userId})
  opts = create: true, doc_ids: docIds
  config.couch().db.replicate(userDbName, 'drunk_tank', opts, h.nanoCallback(callback))


# replicateEvent
#
# @description replicate all event-related docs from constable to users
# @param userIds {Array.<String>} users to replicate to
# @param eventId {String} the event id
#
h.replicateEvent = (userIds, eventId, callback) ->
  userDdocName = 'userddoc'
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/event_filter"
  debug 'replicating event to', userIds
  replicateOne = (userId, cb) ->
    userDbName = h.getUserDbName({userId})
    config.couch().db.replicate('drunk_tank', userDbName, opts, h.nanoCallback(cb))
  async.map(userIds, replicateOne, callback)


h.getUserCtx = (req, res, next) ->
  debug 'req.headers.cookie', req.headers.cookie
  debug 'here', h.getCtx(req)
  debug 'here', req.session
  req.userCtx = h.getCtx(req)
  next()
# h.getUserCtxFromSession req, (err, userCtx, headers) ->
#   return res.json(err.statusCode ? err.status_code ? 500, err) if err
#   debug '#getUserCtxFromSession before: userCtx', userCtx
#   req.userCtx = userCtx
#   h.setCookie(res, headers)   # set-cookie if necessary
#   next()

h.validate = (req, res, next) ->
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx
  doc     = req.body
  ## validate user doc
  Validator = validators[type]
  #return next() if not Validator?
  validator = new Validator(userCtx)
  if req.route.method is 'delete'
    doc = _id: req.params.id, _deleted: true
  validator.validateDoc doc, (err) ->
    return h.sendError(res, err) if err
    next()

# @name getDotComSubdomain
# @description extracts the subdomain from a .com-ending url
#              (for use with req.host)
# @param url {String} the ".com"-ending url
h.getDotComSubdomain = (url) ->
  regex = /(.*)\.[^\.]*\.com/
  url.match(regex)?[1]

module.exports = h
