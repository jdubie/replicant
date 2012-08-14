async = require('async')
request = require('request')
_ = require('underscore')
async = require('async')
debug = require('debug')('replicant:lib')
{nanoAdmin, dbUrl} = require('config')
{getUserDbName, getStatusFromCouchError, hash} = require('lib/helpers')

{EVENT_STATE} = require('../../lifeswap/userdb/shared/constants')

replicant = {}

###
  createUnderscoreUser - creates user in _users DB
  @param email {string}
  @param password {string}
  @param user_id {uuid string}
###
replicant.createUnderscoreUser = ({email, password, user_id}, callback) ->
  name = hash(email)
  underscoreUser =
    _id: "org.couchdb.user:#{name}"
    name: name
    password: password
    roles: []
    type: 'user'
    user_id: user_id
  opts =
    url: "#{dbUrl}/_users"
    body: JSON.stringify(underscoreUser)
    method: 'POST'
    json: true
  request opts, (err, res, body) ->
    if err then error =
      status: 403
      error: "unauthorized"
      reason: "Error authorizing"
    else if body.error? # {error, reason}
      error = body
      error.status = getStatusFromCouchError(body.error)
    else
      error = null
    callback(error, body)



###
  createUserDb - creates usersDB and replicates ddocs to it also sends notification
  @param userId {string}
  @param callback {function}
###
replicant.createUserDb = ({userId, name}, callback) ->

  userDdocDbName = 'userddocdb'
  userDdocName = 'userddoc'

  security =
    admins:
      names: []
      roles: []
    members:
      names: [name]
      roles: []

  userDbName = getUserDbName({userId})
  nanoAdmin.db.create userDbName, (err, res) ->
    if err
      if err.status_code then err.status = err.status_code
      else err.status = getStatusFromCouchError(err)
      debug err
      callback(err)
    else
      userdb = nanoAdmin.db.use(userDbName)
      userdb.insert security, '_security', (err, res) ->
        if err
          debug err
          err.status = getStatusFromCouchError(err)
          callback(err)
        else
          opts =
            doc_ids: [ "_design/#{userDdocName}" ]
          nanoAdmin.db.replicate userDdocDbName, userDbName, opts, (err, res) ->
            if err then err.status = getStatusFromCouchError(err)
            callback(err, res)

###
  createEvent - creates event -> [users] mapping and writes initial events docs to users db
  @param swapId {string}
  @param userId {string}
  @param callback {function}
###
replicant.createEvent = ({swapId, userId}, callback) ->

  getMembers = (next) ->
    members = [userId]  # @todo replace with getting this from cookies
    db = nanoAdmin.db.use('lifeswap')
    db.get swapId, (err, swapDoc) ->
      if not err then members.push(swapDoc.host)  # @todo swapDoc.host will be array in future
      debug 'getMembers', members
      next(err, members)

  createMapping = (users, next) ->
    mapper = nanoAdmin.db.use('mapper')
    mapper.insert {users}, (err, res) ->
      eventId = res.id
      ok = true
      debug 'createMapping', eventId, users, ok
      next(err, {eventId, users, ok})


  createEventDocs = ({eventId, users, ok}, next) ->
    eventDoc =
      _id: eventId
      type: 'event'
      state: EVENT_STATE.requested
      swap_id: swapId

    createEventDoc = (userId, cb) ->
      userDbName = getUserDbName(userId: userId)
      userDb = nanoAdmin.db.use(userDbName)
      userDb.insert(eventDoc, eventDoc._id, cb)

    async.map users, createEventDoc, (err, res) ->
      debug 'createEventDocs', users
      next(err, {eventId, users, ok})

  async.waterfall [
    getMembers
    createMapping
    createEventDocs
  ], (err, res) ->
    if err then err.statusCode = err.status_code if err.status_code else 500
    callback(err, res)


###
  getEventUsers
  @param eventId {string}
###
replicant.getEventUsers = ({eventId}, callback) ->
  mapper = nanoAdmin.db.use('mapper')
  mapper.get eventId, (err, eventDoc) ->
    if err
      if err.error is 'not_found'
        callback(status: 404, reason: "No such event")
      else
        callback(status: 500, reason: "Internal Server Error")
    else
      callback(null, {ok: true, status: 200, users: eventDoc.users})


###
  replicate - replicates from one users db to others
  @param src {string} dbname of source database
  @param dst {string} dbname of destination database
###
replicant.replicate = ({src, dsts, eventId}, callback) ->
  userDdocName = 'userddoc'
  src = getUserDbName({userId: src})
  dsts = _.map dsts, (userId) -> return getUserDbName({userId})
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/eventFilter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  replicateEach = ({src,dst,opts}, cb) ->
    nanoAdmin.db.replicate(src, dst, opts, cb)
  async.map(params, replicateEach, callback)

  # send emails
  #replicant.sendNotifications({dsts, eventId})

  #replicant.sendNotifications = ({dsts, eventId}) ->
  #_.each dsts, (dst) ->
  #  getDbName

replicant.auth = ({username, password}, callback) ->
  nanoAdmin.auth username, password, (err, body, headers) ->
    if err or not headers
      error =
        status: 403
        error: "unauthorized"
        reason: "Error authorizing"
      callback(error)
    else
      callback(null, headers['set-cookie'])


## gets all of a type (e.g. type = 'users' or 'swaps')
replicant.getType = (type, callback) ->
  db = nanoAdmin.db.use('lifeswap')
  opts = include_docs: true
  db.view 'lifeswap', type, opts, (err, res) ->
    debug err, res
    if not err then docs = (row.doc for row in res.rows)
    callback(err, docs)


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  # @todo close db connection
  process.exit()
