request = require('request')
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
      db = config.nanoAdmin
      db.db.create(userDbName, h.nanoCallback(next, errorOpts))
    ## insert _security document
    (next) ->
      db = config.nanoAdmin.db.use(userDbName)
      errorOpts =
        error : "Error modifying db"
        reason: "Error modifying #{userDbName} db"
      db.insert(security, '_security', h.nanoCallback(next, errorOpts))
    ## replicate user design doc
    (next) ->
      db = config.nanoAdmin
      errorOpts =
        error : "Error replicating user ddoc"
        reason: "Error replicating userddoc to #{userDbName}"
      opts =
        doc_ids: [ "_design/#{userDdocName}" ]
      db.db.replicate(userDdocDbName, userDbName, opts, h.nanoCallback(next, errorOpts))
  ], callback


replicant.changePassword = ({name, oldPass, newPass, cookie}, callback) ->
  db = h.getDbWithCookie({cookie, dbName: '_users'})
  ## no need to watch for set-cookie header b/c will re-auth after
  ##    changing password
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
        errorOpts =
          error : "Error changing password"
          reason: "Error inserting _user #{name} with new password"
        db.insert(_user, _user._id, h.nanoCallback(next, errorOpts))
  ], (err, res) ->
    callback(err)


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
    debug '#createEvent user id:', _userId
    userDb = config.db.user(_userId)
    errorOpts =
      error : "Error creating event"
      reason: "Error inserting event doc #{event._id} for #{_userId}"
    userDb.insert(event, event._id, h.nanoCallback(cb, errorOpts))

  createInitialEventDoc = (next) ->
    createEventDoc userId, (err, res) ->
      _rev = res?.rev
      next(err)

  getMembers = (next) ->
    debug 'getMembers'
    db = config.db.main()
    db.get event.swap_id, (err, _swap) ->
      # @todo swap.user_id will be array in future
      if err?
        error =
          error : "Error creating event"
          reason: "Error finding swap (#{event.swap_id}) host #{event._id}"
      else
        swap = _swap
        hosts = [swap?.user_id]
      next(error)

  ## OR could just replicate from original user to these users
  createDocs = (next) ->
    ## create doc in mapping DB
    createMapping = (cb) ->
      mapper = config.db.mapper()
      debug 'createMapping', event._id, userId, hosts
      mapperDoc =
        _id: event._id
        guests: [userId]
        hosts: hosts
      errorOpts =
        error : "Error creating event"
        reason: "Error creating mapping document"
      mapper.insert(mapperDoc, event._id, h.nanoCallback(cb, errorOpts))
    ## create docs in other user DBs
    createEventDocs = (cb) ->
      otherUsers = (admin for admin in config.ADMINS)
      otherUsers.push(user) for user in hosts
      debug 'createEventDocs', otherUsers
      errorOpts =
        error : "Error creating event"
        reason: "Error creating event docs: #{otherUsers}"
      async.map(otherUsers, createEventDoc, h.nanoCallback(cb, errorOpts))
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
    callback(err, {_rev, mtime, ctime, guests, hosts})


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
  dsts = (h.getUserDbName({userId}) for userId in dsts)
  opts =
    create_target: true
    query_params: {eventId}
    filter: "#{userDdocName}/event_filter"
  params = ({src, dst, opts} for dst in dsts)
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
replicant.getTypeUserDb = ({type, userId, cookie, roles}, callback) ->
  roles ?= []

  # constables should fetch from drunk tank
  userDbName = h.getUserDbName({userId})
  dbName = if 'constable' in roles then 'drunk_tank' else userDbName
  db = h.getDbWithCookie({dbName, cookie})

  opts =
    key: type
    include_docs: true
  db.view 'userddoc', 'docs_by_type', opts, (err, res, headers) ->
    if err
      error =
        statusCode: err.status_code ? 500
        error     : err.error ? "GET error"
        reason    : err.reason ? "Error getting '#{type}' docs from #{userDbName} DB"
      return callback(error)
    docs = (row.doc for row in res.rows)
    callback(err, docs, headers)


## marks a message read/unread if specified
# TODO: don't get read status with view anymore!!
#       (differences when using constable)
replicant.markReadStatus = (message, userId, cookie, callback) ->
  markRead = message.read   # true/false
  debug 'markReadStatus', markRead
  if not markRead?
    return callback {
      statusCode: 403
      error: "Error message status"
      reason: "Read/unread status undefined"
    }

  delete message.read
  userDbName = h.getUserDbName({userId})
  db = h.getDbWithCookie({cookie, dbName: userDbName})
  headers = null    # in case a set-cookie header is sent in response

  ## ensure that we have the right cookie set on the database
  resetDbWithHeaders = (_headers) ->
    if _headers?['set-cookie']?
      headers = _headers                # update headers
      cookie = _headers['set-cookie']   # update cookie
      db = h.getDbWithCookie({dbName: userDbName, cookie})  # reset db
    db

  ## mark a message read
  markMessageRead = (callback) ->
    readDoc =
      type: 'read'
      message_id: message._id
      event_id: message.event_id
      ctime: Date.now()
    errorOpts =
      error : "Error marking message read"
      reason: "Error marking message #{message._id} read for #{userId}"

    getHeaders = (err, _headers, res) ->
      db = resetDbWithHeaders(_headers)
      callback(err, _headers, res)

    db.insert(readDoc, h.nanoCallback(getHeaders, errorOpts))

  ## destroy 'read' document
  destroyReadDoc = (row, callback) ->
    doc = row.doc
    return callback() if doc.type isnt 'read'

    errorOpts =
      error : "Error marking message unread"
      reason: "Error removing 'read' doc read for #{userId} (#{message._id})"

    getHeaders = (err, _headers, res) ->
      db = resetDbWithHeaders(_headers)
      callback(err, _headers, res)

    db.destroy(doc._id, doc._rev, h.nanoCallback(getHeaders, errorOpts))

  ## mark a message unread
  markMessageUnread = (callback) ->
    opts =
      include_docs: true
      reduce: false
      key: [message.event_id, message._id]
    db.view 'userddoc', 'messages', opts, (err, res, _headers) ->
      if err?
        error =
          statusCode: err.status_code ? 500
          error     : err.error ? "Error getting message status"
          reason    : err.reason ? "message #{message._id} for #{userId}"
        return callback(error)
      db = resetDbWithHeaders(_headers)
      async.map(res.rows, destroyReadDoc, callback)

  async.waterfall [
    (next) ->
      opts = key: [message.event_id, message._id]
      errorOpts =
        error : "Error getting message status"
        reason: "For message #{message._id}, user #{userId}, event #{message.event_id}"
      db.view('userddoc', 'messages', opts, h.nanoCallback(next, errorOpts)) # (err, res, headers)
    (res, _headers, next) ->
      db = resetDbWithHeaders(_headers)
      if res.rows.length < 1
        return next(statusCode: 404, error: "Error message status", reason: "Too many messages found.")

      row = res.rows[0]
      isRead = if row.value is 1 then false else true
      if markRead isnt isRead then next()
      else
        next(statusCode: 403, error: "Error message status", reason: "Can only change read/unread status of message")
    (next) ->
      if markRead then markMessageRead(next)
      else markMessageUnread(next)
  ], (err, res) ->
    callback(err, res, headers)


## gets all messages and tacks on 'read' status (true/false)
replicant.getMessages = ({userId, cookie, roles}, callback) ->
  headers = null
  updateCookie = (_headers) ->
    headers = _headers if _headers?['set-cookie']?

  async.parallel
    messages: (callback) ->
      replicant.getTypeUserDb {type: 'message', userId, cookie, roles}, (err, messages, _headers) ->
        updateCookie(_headers)
        callback(err, messages)
    reads: (callback) ->
      replicant.getTypeUserDb {type: 'read', userId, cookie}, (err, reads, _headers) ->
        updateCookie(_headers)
        callback(err, reads) # not constable
  , (err, body) ->
    return callback(err) if err
    {reads, messages} = body
    reads = (read.message_id for read in reads)
    message.read = message._id in reads for message in messages
    callback(null, messages, headers)


## gets a message and tacks on its 'read' status (true/false)
replicant.getMessage = ({id, userId, cookie, roles}, callback) ->

  userDbName = h.getUserDbName({userId})
  dbRead  = h.getDbWithCookie({dbName: userDbName, cookie})

  dbName  = if 'constable' in roles then 'drunk_tank' else userDbName
  db      = h.getDbWithCookie({dbName, cookie})
  headers = null

  ## ensure that we have the right cookie set on the databases
  resetDbs = (_headers) ->
    if _headers?['set-cookie']?
      headers = _headers                        # update headers
      cookie = _headers['set-cookie']           # update cookie
      # reset DBs
      db     = h.getDbWithCookie({dbName, cookie})
      dbRead = h.getDbWithCookie({dbName: userDbName, cookie})

  message = null
  async.waterfall [
    (next) -> db.get(id, next)
    (_message, _headers, next) ->
      resetDbs(_headers)
      message = _message
      errorOpts =
        error : "Error getting message"
        reason: "Error getting message #{id}"
      dbRead.view('userddoc', 'read', {key: message._id}, h.nanoCallback(next, errorOpts))
    (res, _headers, next) ->
      resetDbs(_headers)
      message.read = if res.rows.length is 0 then false else true
      next(null, message, headers)
  ], callback


module.exports = replicant
