request = require('request').defaults(jar: false)
async   = require('async')
debug   = require('debug')('replicant:lib')

config = require('config')
h = require('lib/helpers')

{EVENT_STATE} = require('../../lifeswap/userdb/shared/constants')

replicant = {}

###
  createUnderscoreUser - creates user in _users DB
  @param email {string}
  @param password {string}
  @param user_id {uuid string}
###
replicant.createUnderscoreUser = ({email, password, user_id}, callback) ->
  name = h.hash(email)
  underscoreUser =
    _id: "org.couchdb.user:#{name}"
    name: name
    password: password
    roles: []
    type: 'user'
    user_id: user_id
  opts =
    url: "#{config.dbUrl}/_users"
    body: JSON.stringify(underscoreUser)
    method: 'POST'
    json: true
  h.request(opts, callback)


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

  userDbName = h.getUserDbName({userId})
  async.series [
    ## create user DB
    (next) ->
      errorOpts =
        error: "Error creating db file"
        reason: "Error creating #{userDbName} db"
      config.couch().db.create(
        userDbName, h.nanoCallback(next, errorOpts)
      )
    ## insert _security document
    (next) ->
      db = config.db.user(userId)
      errorOpts =
        error : "Error modifying db"
        reason: "Error modifying #{userDbName} db"
      db.insert(security, '_security', h.nanoCallback(next, errorOpts))
    ## replicate user design doc
    (next) ->
      errorOpts =
        error : "Error replicating user ddoc"
        reason: "Error replicating userddoc to #{userDbName}"
      opts =
        doc_ids: [ "_design/#{userDdocName}" ]
      config.couch().db.replicate(
        userDdocDbName, userDbName, opts, h.nanoCallback(next, errorOpts)
      )
  ], callback


replicant.changePassword = ({name, oldPass, newPass}, callback) ->
  db = config.db._users()
  ## no need to watch for set-cookie header b/c will re-auth after
  ##    changing password
  async.waterfall [
    ## get _user document
    (next) ->
      db.get(h.getCouchUserName(name), next)

    ## check that old password was correct
    (_user, hdrs, next) ->
      if _user.password_sha isnt h.hash(oldPass + _user.salt)
        debug 'Incorrect current password'
        error =
          statusCode: 403
          error     : 'Bad password'
          reason    : oldPass: ["Incorrect current password."]
        next(error)
      else
        _user.password_sha = h.hash(newPass + _user.salt)
        debug 'Inserting _user w/ new password'
        errorOpts =
          error : "Error changing password"
          reason: "Error inserting _user #{name} with new password"
        db.insert(_user, _user._id, h.nanoCallback(next, errorOpts))
  ], (err, res) ->
    callback(err)


###
  getEventUsers
  @param eventId {string}
###
replicant.getEventUsers = ({eventId}, callback) ->
  mapper = config.db.mapper()
  mapper.get eventId, (err, mapperDoc) ->
    if err?
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "Error getting event mapping"
        reason    : err.reason ? "Error getting event mapping #{eventId}"
      callback(error)
    else
      users = (user for user in mapperDoc.guests)
      users.push(user) for user in mapperDoc.hosts
      callback(null, users)

###
  getEventHostsAndGuests
  @param event {Object - event}
###
replicant.addEventHostsAndGuests = (event, callback) ->
  mapper = config.db.mapper()
  mapper.get event._id, (err, mapperDoc) ->
    if err?
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "Error getting event mapping"
        reason    : err.reason ? "Error getting event mapping #{eventId}"
      callback(error)
    else
      {hosts, guests} = mapperDoc
      event.hosts = hosts
      event.guests = guests
      callback(null, event)

###
  replicate - replicates from one users db to others
  @param src {string} dbname of source database
  @param dst {string} dbname of destination database
###
replicant.replicate = ({src, dsts, eventId}, callback) ->
  userDdocName = 'userddoc'
  src = h.getUserDbName({userId: src})
  dsts = (h.getUserDbName({userId}) for userId in dsts)
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/event_filter"
  params = ({src, dst, opts} for dst in dsts)
  debug 'replicating', src, dsts
  replicateEach = ({src,dst,opts}, cb) ->
    config.couch().db.replicate(src, dst, opts, cb)
  async.map params, replicateEach, (err, res) ->
    if err?
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "Error replicating"
        reason    : err.reason ? "Error replicating #{src} => #{dsts}"
    callback(error)


replicant.auth = ({username, password}, callback) ->
  config.nano.auth username, password, (err, body, headers) ->
    if err or not headers
      error =
        statusCode: err?.status_code ? 403
        error     : err?.error ? "unauthorized"
        reason    : err?.reason ? "Error authorizing"
    debug '#auth \'set-cookie\'', headers?['set-cookie']
    callback(error, headers?['set-cookie'])


## gets all of a type (e.g. type = 'user' or 'swap')
replicant.getType = (type, callback) ->
  db = config.db.main()
  opts =
    key: type
    include_docs: true
  db.view 'lifeswap', 'docs_by_type', opts, (err, res) ->
    if err
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "GET error"
        reason    : err.reason ? "Error getting '#{type}' docs from main DB"
      callback(error)
    else
      docs = (row.doc for row in res.rows)
      callback(err, docs)

## gets all of a type from a user DB
replicant.getTypeUserDb = ({type, userId, roles}, callback) ->
  debug "#getTypeUserDb type: #{type}"
  roles ?= []

  # constables should fetch from drunk tank
  dbUserId = if 'constable' in roles then 'drunk_tank' else userId
  db = config.db.user(dbUserId)

  opts =
    key: type
    include_docs: true
  db.view 'userddoc', 'docs_by_type', opts, (err, res, headers) ->
    if err
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "GET error"
        reason    : err.reason ? "Error getting '#{type}' docs from #{dbUserId}'s DB"
      return callback(error)
    docs = (row.doc for row in res.rows)
    callback(err, docs)


## marks a message read/unread if specified
# TODO: don't get read status with view anymore!!
#       (differences when using constable)
replicant.markReadStatus = (message, userId, callback) ->
  markRead = message.read   # true/false
  debug '#markReadStatus markRead', markRead
  if not markRead?
    return callback {
      statusCode: 403
      error: "Error message status"
      reason: "Read/unread status undefined"
    }

  delete message.read
  db = config.db.user(userId)

  ## mark a message read
  markMessageRead = (callback) ->
    readDoc =
      type: 'read'
      message_id: message._id
      ctime: Date.now()
    readDoc.event_id = message.event_id if message.event_id?
    db.insert(readDoc, callback)

  ## destroy 'read' document
  destroyReadDoc = (row, callback) ->
    doc = row.doc
    return callback() if doc.type isnt 'read'
    db.destroy(doc._id, doc._rev, callback)

  ## mark a message unread
  markMessageUnread = (callback) ->
    opts = key: message._id, include_docs: true
    db.view 'userddoc', 'read', opts, (err, res, _headers) ->
      if err?
        error =
          statusCode: err.status_code ? 500
          error     : err.error ? "Error getting message status"
          reason    : err.reason ? "message #{message._id} for #{userId}"
        return callback(error)
      async.map(res.rows, destroyReadDoc, callback)

  async.waterfall [
    (next) ->
      opts = key: message._id
      errorOpts =
        error : "Error getting message status"
        reason: "For message #{message._id}, user #{userId}, event #{message.event_id ? 'none'}"
      db.view('userddoc', 'read', opts, h.nanoCallback(next, errorOpts)) # (err, res, headers)
    (res, _headers, next) ->
      isRead = res.rows.length > 0
      if markRead isnt isRead then next()
      else
        next(statusCode: 403, error: "Error message status", reason: "Can only change read/unread status of message")
    (next) ->
      if markRead then markMessageRead(next)
      else markMessageUnread(next)
  ], callback


## gets all messages and tacks on 'read' status (true/false)
replicant.getMessages = ({userId, roles, type}, callback) ->
  type ?= 'message'
  isConstable = 'constable' in roles

  async.parallel
    messages: (callback) ->
      replicant.getTypeUserDb({type, userId, roles}, callback)
    reads: (callback) ->
      replicant.getTypeUserDb({type: 'read', userId}, callback)
    events: (callback) ->
      return callback() if isConstable
      async.waterfall [
        (next) ->
          replicant.getTypeUserDb({type: 'event', userId}, next)
        (events, next) ->
          async.map(events, replicant.addEventHostsAndGuests, next)
      ], callback
  , (err, body) ->
    return callback(err) if err
    {reads, messages} = body
    reads = (read.message_id for read in reads)
    message.read = message._id in reads for message in messages
    if not isConstable
      {events} = body
      preEvents = {}
      preEvents[ev._id] = ev for ev in events when ev.state in ['prefilter', 'predenied']

      filterOut = (message) ->
        if type is 'notification'
          return false if message.object_type isnt 'event'
          eventId = message.object_id
        else if type is 'message'
          eventId = message.event_id
        return false if not preEvents[eventId]?
        return userId in preEvents[eventId].hosts

      messages = (msg for msg in messages when not filterOut(msg))
    callback(null, messages)


## gets a message and tacks on its 'read' status (true/false)
replicant.getMessage = ({id, userId, roles}, callback) ->

  isConstable = 'constable' in roles
  dbUserId    = if isConstable then 'drunk_tank' else userId
  dbRead      = config.db.user(userId)
  db          = config.db.user(dbUserId)

  message = null
  async.waterfall [
    (next) -> db.get(id, next)
    (_message, _headers, next) ->
      message = _message
      dbRead.view('userddoc', 'read', {key: message._id}, next)
    (res, _headers, next) ->
      message.read = res.rows.length > 0
      next(null, message)
  ], callback


module.exports = replicant
