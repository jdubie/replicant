async = require('async')
request = require('request')
_ = require('underscore')
async = require('async')
debug = require('debug')('replicant:lib')

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
      config.nanoAdmin.db.create userDbName, (err, res) ->
        if err?
          debug "Error creating #{userDbName} db", err
          error =
            statusCode: err.statusCode ? err.status_code ? 500
            error     : err.error ? 'Error creating db file'
            reason    : err.reason ? "Error creating #{userDbName} db"
        next(error)
    ## insert _security document
    (next) ->
      userdb = config.nanoAdmin.db.use(userDbName)
      userdb.insert security, '_security', (err, res) ->
        if err?
          debug "Error inserting _security doc (#{userDbName})", err
          error =
            statusCode: err.statusCode ? err.status_code ? 500
            error     : err.error ? 'Error modifying db'
            reason    : err.reason ? "Error modifying #{userDbName} db"
        next(error)
    ## replicate user design doc
    (next) ->
      opts =
        doc_ids: [ "_design/#{userDdocName}" ]
      config.nanoAdmin.db.replicate userDdocDbName, userDbName, opts, (err, res) ->
        if err?
          debug "Error replicating user designdoc (#{userDbName})", err
          error =
            statusCode: err.statusCode ? err.status_code ? 500
            error     : err.error ? "Error replicating user ddoc"
            reason    : err.reason ? "Error replicating userddoc to #{userDbName}"
        next(error)
  ], callback


replicant.changePassword = ({name, oldPass, newPass, cookie}, callback) ->
  nanoOpts =
    url: "#{config.dbUrl}/_users"
    cookie: cookie
  db = require('nano')(nanoOpts)
  async.waterfall [
    ## get _user document
    (next) ->
      db.get("org.couchdb.user:#{name}", next)
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
        db.insert(_user, _user._id, next)
  ], (err, res) ->
    if err?
      error =
        statusCode: err.statusCode ? err.status_code ? 500
        error     : err.error ? 'Error changing password'
        reason    : err.reaons ? 'Error changing password'
    callback(error)


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
  swap = null
  hosts = null
  guests = [userId]

  createEventDoc = (_userId, cb) ->
    # @todo replace with getting this from cookies
    userDbName = h.getUserDbName(userId: _userId)
    debug 'userDbName:', userDbName
    userDb = config.nanoAdmin.db.use(userDbName)
    userDb.insert(event, event._id, cb)

  createInitialEventDoc = (next) ->
    createEventDoc userId, (err, res) ->
      _rev = res?.rev
      next(err)

  getMembers = (next) ->
    debug 'getMembers'
    db = config.nano.db.use('lifeswap')
    db.get event.swap_id, (err, _swap) ->
      # @todo swap.user_id will be array in future
      swap = _swap
      hosts = [swap?.user_id]
      next(err)

  ## OR could just replicate from original user to these users
  createDocs = (next) ->
    ## create doc in mapping DB
    createMapping = (cb) ->
      mapper = config.nanoAdmin.db.use('mapper')
      debug 'createMapping', event._id, userId, hosts
      mapperDoc =
        _id: event._id
        guests: [userId]
        hosts: hosts
      mapper.insert(mapperDoc, event._id, cb)
    ## create docs in other user DBs
    createEventDocs = (cb) ->
      otherUsers = (admin for admin in config.ADMINS)
      otherUsers.push(user) for user in hosts
      debug 'createEventDocs', otherUsers
      async.map(otherUsers, createEventDoc, cb)
    ## in parallel
    async.parallel([createMapping, createEventDocs], next)

  queueNotifications = (next) ->
    h.createNotification('event.create', {title: "event #{event._id}: event created", guests, hosts, event, swap}, next)

  async.series [
    createInitialEventDoc
    getMembers
    createDocs
    queueNotifications
  ], (err, res) ->
    if err?
      error =
        statusCode: err.statusCode ? err.status_code ? 500
        error     : err.error ? "Error creating event"
        reason    : err.reason ? "Error creating event #{eventId} for #{userId}"
      callback(error)
    else
      callback(null, {_rev, mtime, ctime, guests, hosts})


###
  getEventUsers
  @param eventId {string}
###
replicant.getEventUsers = ({eventId}, callback) ->
  mapper = config.nanoAdmin.db.use('mapper')
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
  mapper = config.nanoAdmin.db.use('mapper')
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
  dsts = _.map dsts, (userId) -> return h.getUserDbName({userId})
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/event_filter"
  params = _.map dsts, (dst) ->
    return {src, dst, opts}
  debug 'replicating', src, dsts
  replicateEach = ({src,dst,opts}, cb) ->
    config.nanoAdmin.db.replicate(src, dst, opts, cb)
  async.map params, replicateEach, (err, res) ->
    if err?
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "Error replicating"
        reason    : err.reason ? "Error replicating #{src} => #{dsts}"
    callback(error)


  # send emails
  #replicant.sendNotifications({dsts, eventId})

  #replicant.sendNotifications = ({dsts, eventId}) ->
  #_.each dsts, (dst) ->
  #  getDbName

replicant.auth = ({username, password}, callback) ->
  config.nano.auth username, password, (err, body, headers) ->
    if err or not headers
      error =
        statusCode: err?.status_code ? 403
        error     : err?.error ? "unauthorized"
        reason    : err?.reason ? "Error authorizing"
    else error = null
    callback(error, headers?['set-cookie'])


## gets all of a type (e.g. type = 'user' or 'swap')
replicant.getType = (type, callback) ->
  db = config.nanoAdmin.db.use('lifeswap')
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
replicant.getTypeUserDb = (type, userId, cookie, callback) ->
  userDbName = h.getUserDbName(userId: userId)
  nanoOpts =
    url: "#{config.dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)
  opts =
    key: type
    include_docs: true
  db.view 'userddoc', 'docs_by_type', opts, (err, res) ->
    if err
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "GET error"
        reason    : err.reason ? "Error getting '#{type}' docs from #{userDbName} DB"
      callback(error)
    else
      docs = (row.doc for row in res.rows)
      callback(err, docs)


## marks a message read/unread if specified
replicant.markReadStatus = (message, userId, cookie, callback) ->
  markRead = message.read   # true/false
  debug 'markReadStatus', markRead
  delete message.read
  userDbName = h.getUserDbName(userId: userId)
  nanoOpts =
    url: "#{config.dbUrl}/#{userDbName}"
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
  ], (err, res) ->
    if err?
      debug "Error changing message read status: #{message?._id} of user #{userId}"
      error =
        statusCode: err.statusCode ? err.status_code ? 500
        error     : err.error ? "Error changing message read status"
        reason    : err.reason ? "Error changing message read status - #{message?._id}"
    callback(error)


## gets all messages and tacks on 'read' status (true/false)
replicant.getMessages = (userId, cookie, callback) ->
  userDbName = h.getUserDbName(userId: userId)
  nanoOpts =
    url: "#{config.dbUrl}/#{userDbName}"
    cookie: cookie
  db = require('nano')(nanoOpts)
  opts = group_level: 2
  db.view 'userddoc', 'messages', opts, (err, res) ->
    getMessageDoc = (row, cb) ->
      messageId = row.key[1]
      db.get messageId, (err, message) ->
        if err?
          error =
            statusCode: err.statusCode ? err.status_code
            error     : err.error ? "Error getting message"
            reason    : err.reason ? "Error getting message: #{userId}"
        else
          message.read = if row.value is 1 then false else true
        cb(error, message)
    if err?
      error =
        statusCode: err.statusCode ? err.status_code
        error     : err.error ? "Error getting messages"
        reason    : err.reason ? "Error getting messages: #{userId}"
      callback(error)
    else async.map(res.rows, getMessageDoc, callback)  # messages


## gets a message and tacks on its 'read' status (true/false)
replicant.getMessage = (messageId, userId, cookie, callback) ->
  userDbName = h.getUserDbName(userId: userId)
  nanoOpts =
    url: "#{config.dbUrl}/#{userDbName}"
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
  ], (err, message) ->
    if err?
      debug "Error getting message #{messageId} for #{userId}"
      error =
        statusCode: err.statusCode ? err.status_code
        error     : err.error ? "Error getting message"
        reason    : err.reason ? "Error getting message #{messageId}"
    callback(error, message)

## gets an event and tacks on 'hosts'/'guests' arrays


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  # @todo close db connection
  process.exit()
