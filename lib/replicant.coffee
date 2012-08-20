async = require('async')
request = require('request')
_ = require('underscore')
async = require('async')
debug = require('debug')('replicant:lib')
{nanoAdmin, dbUrl, ADMINS} = require('config')
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
replicant.createEvent = ({event, userId}, callback) ->

  _rev = null
  ctime = Date.now()
  mtime = ctime
  event.ctime = ctime
  event.mtime = mtime
  hosts = null
  guests = [userId]

  createEventDoc = (_userId, cb) ->
    # @todo replace with getting this from cookies
    userDbName = getUserDbName(userId: _userId)
    debug 'userDbName:', userDbName
    userDb = nanoAdmin.db.use(userDbName)
    userDb.insert(event, event._id, cb)

  createInitialEventDoc = (next) ->
    createEventDoc userId, (err, res) ->
      _rev = res?.rev
      next(err)

  getMembers = (next) ->
    debug 'getMembers'
    db = nanoAdmin.db.use('lifeswap')
    db.get event.swap_id, (err, swap) ->
      # @todo swap.user_id will be array in future
      hosts = [swap?.user_id]
      next(err)

  ## OR could just replicate from original user to these users
  createDocs = (next) ->
    ## create doc in mapping DB
    createMapping = (cb) ->
      mapper = nanoAdmin.db.use('mapper')
      debug 'createMapping', event._id, userId, hosts
      mapperDoc =
        _id: event._id
        guests: [userId]
        hosts: hosts
      mapper.insert(mapperDoc, event._id, cb)
    ## create docs in other user DBs
    createEventDocs = (cb) ->
      otherUsers = (admin for admin in ADMINS)
      otherUsers.push(user) for user in hosts
      debug 'createEventDocs', otherUsers
      async.map(otherUsers, createEventDoc, cb)
    ## in parallel
    async.parallel([createMapping, createEventDocs], next)

  async.series [
    createInitialEventDoc
    getMembers
    createDocs
  ], (err, res) ->
    if err
      err.statusCode = err.status_code ? 500
      callback(err)
    else
      callback(null, {_rev, mtime, ctime, guests, hosts})


###
  getEventUsers
  @param eventId {string}
###
replicant.getEventUsers = ({eventId}, callback) ->
  mapper = nanoAdmin.db.use('mapper')
  mapper.get eventId, (err, mapperDoc) ->
    if err
      err.statusCode = err.status_code ? 500
      callback(err)
    else
      users = (user for user in mapperDoc.guests)
      users.push(user) for user in mapperDoc.hosts
      callback(null, users)

###
  getEventHostsAndGuests
  @param event {Object - event}
###
replicant.addEventHostsAndGuests = (event, callback) ->
  mapper = nanoAdmin.db.use('mapper')
  mapper.get event._id, (err, mapperDoc) ->
    if mapperDoc then {hosts, guests} = mapperDoc
    event.hosts = hosts
    event.guests = guests
    callback(err, event)

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
    filter: "#{userDdocName}/event_filter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  debug 'replicating', src, dsts
  replicateEach = ({src,dst,opts}, cb) ->
    nanoAdmin.db.replicate(src, dst, opts, cb)
  async.map params, replicateEach, (err, res) ->
    if err then err.statusCode = err.status_code ? 500
    callback(err, res)

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


## gets all of a type (e.g. type = 'user' or 'swap')
replicant.getType = (type, callback) ->
  db = nanoAdmin.db.use('lifeswap')
  opts =
    key: type
    include_docs: true
  db.view 'lifeswap', 'docs_by_type', opts, (err, res) ->
    if not err then docs = (row.doc for row in res.rows)
    callback(err, docs)

## gets all of a type from a user DB
replicant.getTypeUserDb = (type, userId, cookie, callback) ->
  userDbName = getUserDbName(userId: userId)
  nanoOpts =
    url: "#{dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)
  opts =
    key: type
    include_docs: true
  db.view 'userddoc', 'docs_by_type', opts, (err, res) ->
    if not err then docs = (row.doc for row in res.rows)
    callback(err, docs)


## marks a message read/unread if specified
replicant.markReadStatus = (message, userId, cookie, callback) ->
  markRead = message.read   # true/false
  debug 'markReadStatus', markRead
  delete message.read
  userDbName = getUserDbName(userId: userId)
  nanoOpts =
    url: "#{dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)

  ## mark a message read
  markMessageRead = (callback) ->
    readDoc =
      type: 'read'
      message_id: message._id
      event_id: message.event_id
      ctime: Date.now()
    db.insert(readDoc, callback)
  ## destroy 'read' document
  destroyReadDoc = (row, callback) ->
    doc = row.doc
    if doc.type is 'read'
      db.destroy(doc._id, doc._rev, callback)
    else callback()
  ## mark a message unread
  markMessageUnread = (callback) ->
    opts =
      include_docs: true
      reduce: false
      key: [message.event_id, message._id]
    db.view 'userddoc', 'messages', opts, (err, res) ->
      async.map(res.rows, destroyReadDoc, callback)

  async.waterfall [
    (next) ->
      if not markRead?
        next(statusCode: 403, reason: "Read/unread status undefined")
      else
        opts = key: [message.event_id, message._id]
        db.view('userddoc', 'messages', opts, next) # (err, res, hdr)
    (res, hdr, next) ->
      if res.rows.length < 1
        next(statusCode: 404, reason: "Too many messages found.")
      else
        row = res.rows[0]
        isRead = if row.value is 1 then false else true
        if markRead isnt isRead then next()
        else
          next(statusCode: 403, reason: "Can only change read/unread status of message")
    (next) ->
      if markRead then markMessageRead(next)
      else markMessageUnread(next)
  ], callback


## gets all messages and tacks on 'read' status (true/false)
replicant.getMessages = (userId, cookie, callback) ->
  userDbName = getUserDbName(userId: userId)
  nanoOpts =
    url: "#{dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)
  opts = group_level: 2
  db.view 'userddoc', 'messages', opts, (err, res) ->
    getMessageDoc = (row, cb) ->
      messageId = row.key[1]
      db.get messageId, (err, message) ->
        if not err
          message.read = if row.value is 1 then false else true
        cb(err, message)
    if err then callback(err)
    else async.map(res.rows, getMessageDoc, callback)  # messages


## gets a message and tacks on its 'read' status (true/false)
replicant.getMessage = (messageId, userId, cookie, callback) ->
  userDbName = getUserDbName(userId: userId)
  nanoOpts =
    url: "#{dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)
  message = null
  async.waterfall [
    (next) -> db.get(messageId, next)
    (_message, headers, next) ->
      message = _message
      opts = key: [message.event_id, message._id]
      db.view('userddoc', 'messages', opts, next)
    (res, headers, next) ->
      if res.rows.length < 1 then next(statusCode: 404)
      else
        message.read = if res.rows[0].value is 1 then false else true
        next(null, message)
  ], callback   # (err, message)

## gets an event and tacks on 'hosts'/'guests' arrays


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  # @todo close db connection
  process.exit()
