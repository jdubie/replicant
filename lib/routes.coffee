async   = require('async')
request = require('request')
_       = require('underscore')
debug   = require('debug')('replicant:routes')

config  = require('config')
rep     = require('lib/replicant')
h       = require('lib/helpers')
validators = require('validation')


exports.login = (req, res) ->
  return if h.verifyRequiredFields(req, res, ['username', 'password'])
  username = h.hash(req.body.username.toLowerCase())
  password = req.body.password
  debug "POST /user_ctx"
  debug "   username: #{username}"
  rep.auth {username, password}, (err, cookie) ->
    return h.sendError(res, err) if err
    res.set('Set-Cookie', cookie)
    h.getUserId {cookie, userCtx: name: username}, (err, userCtx) ->
      return h.sendError(res, err) if err
      res.json(userCtx)


exports.logout = (req, res) ->
  opts =
    url: "#{config.dbUrl}/_session"
    method: 'DELETE'
  request(opts).pipe(res)

# @name session
#
# @description gets the session information for the current user
exports.session = (req, res) ->
  opts =
    headers: req.headers
    url: "#{config.dbUrl}/_session"
    json: true
  headers = null
  cookie = req.headers.cookie

  updateCookie = (_headers) ->
    if _headers?['set-cookie']
      debug 'set-cookie', _headers
      headers = _headers
      cookie  = _headers['set-cookie']
      res.set('Set-Cookie', cookie)

  h.request opts, (err, body, _headers) ->
    updateCookie(_headers)
    return h.sendError(res, err) if err
    debug "GET /user_ctx"
    debug '   body', body
    userCtx = body.userCtx
    return res.json(200, userCtx) unless userCtx.name?
    h.getUserId {cookie, userCtx}, (err, userCtx, _headers) ->
      updateCookie(_headers)
      return h.sendError(res, err) if err
      res.json(200, userCtx)

# @name password
#
# @description change the password of the current user
exports.password = (req, res) ->

  return if h.verifyRequiredFields(req, res, ['name', 'oldPass', 'newPass'])
  {name, oldPass, newPass} = req.body
  cookie = req.headers.cookie
  debug "PUT /user_ctx"
  debug "   username: #{name}"
  newCookie = null
  async.waterfall [
    (next) ->
      rep.changePassword({name, oldPass, newPass, cookie}, next)
    (next) ->
      rep.auth({username: name, password: newPass}, next)
  ], (err, newCookie) ->
    return h.sendError(res, err) if err
    res.set('Set-Cookie', newCookie)
    res.send(201)


# @name zipcode
#
# @description get the zipcode mapping
exports.zipcode = (req, res) ->
  callback = (err, body) ->
    if body.rows.length == 0
      error =
        error : 'Not found'
        reason: zipcode: ['Not a valid zipcode']
      res.json(404, error)
    else res.json(body.rows[0].value)

  db = config.nano.use('zipcodes')
  db.view('zipcodes', 'zipcodes', {key: req.params.id}, h.nanoCallback(callback))

# @name createUser
#
# @description create a user
#              * creates user database
#              * creates preliminary user doc after signup on client
exports.createUser = (req, res) ->
  debug "POST /users"
  return if h.verifyRequiredFields req, res, [
    'email_address', 'password', '_id'
  ]
  user = req.body
  {email_address, password, _id} = user   # extract email and password
  user_id = _id
  # delete private data
  delete user.password
  delete user.email_address
  delete user.confirm_password
  email = email_address
  email = email.toString().toLowerCase()
  debug "   email: #{email}"

  user.name = name = h.hash(email)
  ctime = mtime = Date.now()
  user.ctime = ctime
  user.mtime = mtime
  response =
    name: name
    roles: []
    user_id: user_id
    ctime: ctime
    mtime: mtime
  cookie = null

  updateCookie = (_headers) ->
    if _headers?['set-cookie']?
      cookie = _headers['set-cookie']

  async.waterfall [
    (next) ->
      ## insert document to _users
      debug '   insert document to _users'
      rep.createUnderscoreUser({email, password, user_id}, next)

    (_res, _headers, next) ->
      ## auth to get cookie
      debug '   auth to get cookie'
      rep.auth({username: name, password: password}, next)

    (_cookie, next) ->
      cookie = _cookie
      ## create user database
      debug '   create user database'
      rep.createUserDb({userId: user_id, name: name}, next)

    (_res, next) ->
      ## create 'user' type document
      debug "   create 'user' type document"
      userNano = h.getDbWithCookie({dbName: 'lifeswap', cookie})
      userNano.insert(user, user_id, h.nanoCallback(next))

    (_res, headers, next) ->
      updateCookie(headers)
      response._rev = _res?.rev    # add _rev to response
      ## create 'email_address' type private document
      debug "   create 'email_address' type private document"
      userDbName = h.getUserDbName(userId: user_id)
      userPrivateNano = h.getDbWithCookie({dbName: userDbName, cookie})
      emailDoc =
        type: 'email_address'
        name: name
        user_id: user_id
        email_address: email
        ctime: ctime
        mtime: mtime
      userPrivateNano.insert(emailDoc, h.nanoCallback(next))

    (_res, headers, next) ->
      updateCookie(headers)
      data = {user, emailAddress: email}
      h.createNotification('user.create', data, next)

  ], (err, body, headers) ->    # w/ createNotification, will be (err?)
    return h.sendError(res, err) if err
    res.set('Set-Cookie', cookie)
    res.json(201, response)       # {name, roles, id}


exports.postPublic = (req, res) ->
  debug "POST #{req.url}"
  model   = h.getModelFromUrl(req.url)
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx   # from the app.all route
  doc     = req.body

  ctime = mtime = Date.now()
  doc.ctime = ctime
  doc.mtime = mtime

  async.series
    validate: (next) ->
      Validator = validators[type]
      return next() if not Validator?
      validator = new Validator(userCtx)
      validator.validateDoc(doc, next)
    _rev: (next) ->
      opts =
        method: 'POST'
        url: "#{config.dbUrl}/lifeswap"
        headers: req.headers
        json: doc
      h.request opts, (err, body, headers) ->
        h.setCookie(res, headers)
        return next(err) if err
        next(null, body.rev)
    notify: (next) ->
      h.createSimpleCreateNotification(model, doc, next)

  , (err, resp) ->
    return h.sendError(res, err) if err
    _rev = resp._rev
    res.json(201, {_rev, ctime, mtime})


exports.allPublic = (req, res) ->
  type = h.getTypeFromUrl(req.url)
  rep.getType type, (err, docs) ->
    return h.sendError(res, err) if err?
    res.json(200, docs)


exports.onePublic = (req, res) ->
  debug "#onePublic #{req.url}"
  id = req.params.id
  request("#{config.dbUrl}/lifeswap/#{id}").pipe(res)


exports.putPublic = (req, res) ->
  debug "#putPublic #{req.url}"
  id      = req.params.id
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx
  doc     = req.body

  mtime     = Date.now()
  doc.mtime = mtime

  async.series
    validate: (next) ->
      Validator = validators[type]
      return next() if not Validator?
      validator = new Validator(userCtx)
      validator.validateDoc(doc, next)
    _rev: (next) ->
      opts =
        method: 'PUT'
        url: "#{config.dbUrl}/lifeswap/#{id}"
        headers: req.headers
        json: doc
      h.request opts, (err, body, headers) ->
        h.setCookie(res, headers)
        return next(err) if err
        next(null, body.rev)
  , (err, resp) ->
    return h.sendError(res, err) if err
    _rev = resp._rev
    res.json(200, {_rev, mtime})


exports.forbidden = (req, res) ->
  debug "#forbidden: #{req.url}"
  res.send(403)


exports.deleteUser = (req, res) ->
  userId = req.params?.id
  debug "DELETE /users/#{userId}"
  headers = null
  cookie = req.headers.cookie

  updateCookie = (_headers) ->
    if _headers?['set-cookie']?
      debug 'set-cookie', _headers
      headers = _headers
      cookie = _headers['set-cookie']

  async.waterfall [
    ## get user ctx
    (next) ->
      h.getUserCtxFromSession(req, next)
    (userCtx, _headers, next) ->
      updateCookie(_headers)
      if not ('constable' in userCtx.roles) then next(statusCode: 403)
      else next(null, userCtx)
    ## if a constable!
    (userCtx, next) ->
      userName = userRev = null
      userRev = null

      async.waterfall [
        (_next) ->
          debug 'get user document'
          db = h.getDbWithCookie({dbName: 'lifeswap', cookie})
          db.get(userId, h.nanoCallback(_next))
        (userDoc, _headers, _next) ->
          userRev = userDoc._rev
          userName = userDoc.name

          async.series [
            ## delete _user document
            (cb) ->
              debug 'delete _user'
              db = config.db._users()
              _username = h.getCouchUserName(userName)
              async.waterfall [
                (done) ->
                  debug 'getting _user', _username
                  db.get(_username, h.nanoCallback(done))
                (_userDoc, hdr, done) ->
                  debug 'destroying _user'
                  db.destroy(_username, _userDoc._rev, h.nanoCallback(done))
              ], cb

            ## delete user type document
            (cb) ->
              debug 'delete user'
              db = h.getDbWithCookie({dbName: 'lifeswap', cookie})
              updateCookieCallback = (err, _res, _headers) ->
                updateCookie(_headers)
                cb(err, _res, _headers)

              db.destroy(userId, userRev, h.nanoCallback(updateCookieCallback))

            ## delete user DB
            (cb) ->
              debug 'delete user db'
              userDbName = h.getUserDbName({userId})
              debug 'userDbName', userDbName
              config.couch().db.destroy(userDbName, h.nanoCallback(cb))
          ], _next
      ], next
  ], (err, _res) ->
    return h.sendError(res, err) if err?
    h.setCookie(res, headers)
    res.send(200)


exports.deletePublic = (req, res) ->
  debug "DELETE #{req.url}"
  id = req.params?.id
  doc = req.body
  debug "   req.body", doc
  return if h.verifyRequiredFields(req, res, ['_rev'])
  opts =
    method: 'DELETE'
    url: "#{config.dbUrl}/lifeswap/#{id}"
    headers: req.headers
    qs: rev: req.body._rev
    json: req.body
  request(opts).pipe(res)


# @name createEvent
#
# @description creates a swap event and initializes involved users
# @body event {object} event to create
# @headers cookie {cookie} authenticates user
# 
# @return {_rev, ctime, mtime, hosts, guests}
exports.createEvent = (req, res) ->
  event = req.body    # {_id, type, state, swap_id}
  userCtx = req.userCtx

  debug "POST /events"
  debug "   event" , event
  return if h.verifyRequiredFields(req, res, ['swap_id', '_id', 'state'])

  delete event.hosts
  delete event.guests
  mtime = ctime = Date.now()
  event.ctime = ctime
  event.mtime = mtime
  event["#{event.state}_time"] = ctime

  # global boy
  swap = null

  async.parallel

    # insert event document into constable db
    _rev: (done) ->
      extractRev = (err, body) -> done(err, body?.rev)
      config.db.constable().insert(event, h.nanoCallback(extractRev))

    # put all users assosciated with swap and return them
    mapping: (done) ->
      async.waterfall [
        (next) ->
          config.db.main().get(event.swap_id, h.nanoCallback2(next))
        (_swap, next) ->
          swap = _swap
          mapping = _id: event._id, guests: [userCtx.user_id], hosts: [_swap.user_id]
          returnUsers = (err) ->
            return next(err) if err
            next(null, mapping) # return users
          config.db.mapper().insert(mapping, h.nanoCallback(returnUsers))
      ], done

  , (err, body) ->
    return h.sendError(res, err) if err
    {_rev, mapping} = body
    {guests, hosts} = mapping

    h.replicateOut _.union(guests, hosts), [event._id], (err) ->
      return h.sendError(res, err) if err
      h.createNotification 'event.create', {title: "event #{event._id}: event created", guests, hosts, event, swap}, (err) ->
        return h.sendError(err, body) if err
        result = {_rev, hosts, guests, ctime, mtime}
        result["#{event.state}_time"] = event["#{event.state}_time"]
        res.json(201, result)


exports.getEvents = (req, res) ->
  debug "GET /events"
  userCtx = req.userCtx   # from the app.all route
  cookie = req.headers.cookie
  debug 'userCtx', userCtx
  headers = null
  async.waterfall [
    (next) ->
      rep.getTypeUserDb {
        type: 'event'
        userId: userCtx.user_id
        cookie
        roles: userCtx.roles
      }, next
    (events, _headers, next) ->
      headers = _headers
      async.map(events, rep.addEventHostsAndGuests, next)
  ], (err, events) ->
    return h.sendError(res, err) if err
    h.setCookie(res, headers)
    res.json(200, events)

exports.getEvent = (req, res) ->
  id = req.params?.id
  debug "GET /events/#{id}"
  userCtx = req.userCtx   # from the app.all route
  cookie = req.headers.cookie
  userDbName = h.getUserDbName(userId: userCtx.user_id)
  userPrivateNano = h.getDbWithCookie({dbName: userDbName, cookie})
  headers = null
  async.waterfall [
    (next) -> userPrivateNano.get(id, h.nanoCallback(next))
    (event, _headers, next) ->
      headers = _headers
      rep.addEventHostsAndGuests(event, next)
  ], (err, event) ->
    return h.sendError(res, err) if err
    h.setCookie(res, headers)
    res.json(200, event)


exports.putEvent = (req, res) ->
  id = req.params?.id
  debug "PUT /events/#{id}"
  return if h.verifyRequiredFields(req, res, ['_rev'])

  userCtx = req.userCtx   # from the app.all route
  userDbName = h.getUserDbName(userId: userCtx.user_id)
  event = req.body
  mtime = Date.now()
  event.mtime = mtime

  _rev = _users = null
  isConstable = stateChange = false
  
  async.waterfall [
    (next) ->
      debug 'get users'
      rep.getEventUsers({eventId: id}, next)    # (err, users)

    (users, next) ->
      debug 'got users'
      if userCtx.user_id not in users
        if 'constable' in userCtx.roles
          isConstable = true
        else
          error =
            statusCode: 403
            reason: "Not authorized to modify this event"
          return next(error)
      _users = users
      userDbName = 'drunk_tank' if isConstable

      debug 'get old event'
      userId = if isConstable then 'drunk_tank' else userCtx.user_id
      db = config.db.user(userId)
      db.get(id, h.nanoCallback(next))

    (oldEvent, headers, next) ->
      if oldEvent.state isnt event.state
        unless oldEvent.state is 'overdue' and event.state is 'confirmed'
          stateChange = true
          event["#{event.state}_time"] = mtime
      debug 'put event', event
      opts =
        method: 'PUT'
        url: "#{config.dbUrl}/#{userDbName}/#{id}"
        headers: req.headers
        json: event
      h.request(opts, next) # (err, resp, body)

    (body, headers, next) ->
      debug 'replicate'
      _rev = body.rev
      eventId = id

      if isConstable
        dsts = _users
        src = 'drunk_tank'
      else
        _users.push('drunk_tank')
        src = userCtx.user_id
        dsts = (xx for xx in _users when xx isnt src)

      rep.replicate({src, dsts, eventId}, next)   # (err)

    (next) ->
      data = {event, rev: event._rev, userId: userCtx.user_id}
      h.createNotification('event.update', data, next)

  ], (err, resp) ->
    return h.sendError(res, err) if err
    result = {_rev, mtime}
    result["#{event.state}_time"] = mtime if stateChange
    res.json(201, result)


exports.allPrivate = (req, res) ->
  type = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx
  cookie  = req.headers.cookie
  debug 'userCtx', userCtx
  rep.getTypeUserDb {type, userId: userCtx.user_id, cookie, roles: userCtx.roles}, (err, docs, headers) ->
    h.setCookie(res, headers)
    return h.sendError(res, err) if err
    res.json(200, docs)


exports.onePrivate = (req, res) ->
  id = req.params?.id
  debug "GET #{req.url}"
  userCtx = req.userCtx
  userDbName = h.getUserDbName(userId: userCtx.user_id)
  endpoint =
    url: "#{config.dbUrl}/#{userDbName}/#{id}"
    headers: req.headers
  request(endpoint).pipe(res)


exports.deletePrivate = (req, res) ->
  id      = req.params?.id
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx   # from the app.all route
  cookie  = req.headers.cookie
  debug "DELETE #{req.url}: userCtx, cookie", userCtx, cookie

  isConstable = 'constable' in userCtx.roles
  constableDb = config.db.constable()
  docRev = null

  async.waterfall [
    (next) ->
      Validator = validators[type]
      return next() if not Validator?
      validator = new Validator(userCtx)
      # return constable db if this is a constable
      validator.validateDoc(_id: id, _deleted: true, next)

    ## get the document to get the userId
    (next) ->
      debug '#deletePrivate get doc'
      constableDb.get(id, h.nanoCallback(next))

    ## get the userId and delete from user db then constable db
    (doc, _headers, next) ->
      debug '#deletePrivate delete doc from user DB'
      userId = doc.user_id
      docRev = doc._rev

      if isConstable
        userDb = config.db.user(userId)
      else
        userDbName = h.getUserDbName({userId})
        userDb = h.getDbWithCookie({dbName: userDbName, cookie})

      userDb.destroy(doc._id, doc._rev, h.nanoCallback(next))

    ## delete from the constable db if it passed the last part
    (res, _headers, next) ->
      debug '#deletePrivate delete doc from drunk_tank'
      constableDb.destroy(id, docRev, h.nanoCallback(next))
  ], (err, resp) ->
    return h.sendError(res, err) if err
    res.send(200)


exports.postPrivate = (req, res) ->
  debug "POST #{req.url}"
  debug "   req.userCtx", req.userCtx
  model   = h.getModelFromUrl(req.url)
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx   # from the app.all route
  return if h.verifyRequiredFields(req, res, ['_id', 'user_id'])

  doc = req.body
  _id = doc._id
  ctime = mtime = Date.now()
  doc.ctime = ctime
  doc.mtime = mtime

  async.series
    validate: (next) ->
      Validator = validators[type]
      return next() if not Validator?
      validator = new Validator(userCtx)
      validator.validateDoc(doc, next)
    _rev: (next) ->
      userDbName = h.getUserDbName(userId: userCtx.user_id)
      opts =
        method: 'POST'
        url: "#{config.dbUrl}/#{userDbName}"
        headers: req.headers
        json: doc
      h.request opts, (err, body, headers) ->
        h.setCookie(res, headers)
        return next(err) if err
        next(null, body.rev)
    replicate: (next) ->
      h.replicateIn(doc.user_id, [doc._id],next)
    notify: (next) ->
      h.createSimpleCreateNotification(model, doc, next)
  , (err, resp) ->
    return h.sendError(res, err) if err
    _rev = resp._rev
    res.json(201, {_id, _rev, mtime, ctime})


exports.putPrivate = (req, res) ->
  debug "PUT #{req.url}"
  id      = req.params?.id
  type    = h.getTypeFromUrl(req.url)
  userCtx = req.userCtx   # from the app.all route
  doc     = req.body

  mtime     = Date.now()
  doc.mtime = mtime

  async.series
    validate: (next) ->
      Validator = validators[type]
      return next() if not Validator?
      validator = new Validator(userCtx)
      validator.validateDoc(doc, next)
    _rev: (next) ->
      userDbName = h.getUserDbName(userId: userCtx.user_id)
      opts =
        method: 'PUT'
        url: "#{config.dbUrl}/#{userDbName}/#{id}"
        headers: req.headers
        json: doc
      h.request opts, (err, body, headers) ->
        h.setCookie(res, headers)
        return next(err) if err
        next(null, body.rev)
    replicate: (next) ->
      h.replicateIn(userCtx.user_id, [id],next)
  , (err, resp) ->
    return h.sendError(res, err) if err
    _rev = resp._rev
    res.json(201, {_rev, mtime})


exports.changeReadStatus = (req, res) ->
    ## TODO: _allow_ change only when read => true (write 'read' doc)
    id = req.params?.id
    debug "PUT #{req.url}"
    return if h.verifyRequiredFields(req, res, ['_id', 'read'])

    userCtx = req.userCtx
    cookie  = req.headers.cookie
    message = req.body
    rep.markReadStatus message, userCtx.user_id, cookie, (err, _res, headers) ->
      return h.sendError(res, err) if err
      h.setCookie(res, headers)
      res.send(201)


exports.getMessages = (req, res) ->
  debug "GET #{req.url}"
  type = h.getTypeFromUrl(req.url)
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  rep.getMessages {
    userId: userCtx.user_id
    cookie
    roles: userCtx.roles
    type
  }, (err, messages, headers) ->
    return h.sendError(res, err) if err
    h.setCookie(res, headers)
    res.json(200, messages)


exports.getMessage = (req, res) ->
  id = req.params?.id
  debug "GET #{req.url}"
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  rep.getMessage {
    id, userId: userCtx.user_id, cookie, roles: userCtx.roles
  }, (err, message, headers) ->
    return h.sendError(res, err) if err
    h.setCookie(res, headers)
    res.json(200, message)


exports.sendMessage = (req, res) ->
  debug "POST /message"
  return if h.verifyRequiredFields req, res, [
    'name', 'user_id', 'event_id'
  ]

  userCtx = req.userCtx   # from the app.all route
  message = req.body

  if (message.name isnt userCtx.name or message.user_id isnt userCtx.user_id) and 'constable' not in userCtx.roles
    return res.send(403)

  delete message.read # don't delete this line
  ctime = mtime = Date.now()
  message.ctime = ctime
  message.mtime = mtime
  eventId = message.event_id
  userDbName = h.getUserDbName(userId: message.user_id)

  async.series
    _rev: (done) ->
      debug 'insert into constable db (drunk_tank)'
      extractRev = (err, body) ->
        return done(err) if err
        done(null, body.rev)
      config.db.constable().insert(message, h.nanoCallback(extractRev))

    markRead: (done) ->
      debug 'mark message read'
      opts =
        method: 'POST'
        url: "#{config.dbUrl}/#{userDbName}"
        headers: req.headers
        json:
          type: 'read'
          message_id: message._id
          event_id: message.event_id
          ctime: ctime
      h.request opts, (err, _res, headers) ->
        h.setCookie(res, headers)
        done(err)

    # replicate message
    replicate: (done) ->
      debug 'get users'
      rep.getEventUsers {eventId}, (err, users) ->
        debug 'replicate'
        src = userCtx.user_id
        if not (src in users) and not ('constable' in userCtx.roles)
          return next(statusCode: 403, reason: "Not authorized to write messages to this event")
        dsts = _.without(users, src)
        async.series [
          (cb) ->
            debug 'actually replicating...'
            h.replicateEvent(users, eventId, cb)
          ## add email jobs to messaging queue
          (cb) ->
            debug 'adding message email to email jobs queue'
            data = {title: "event #{eventId}: message from #{src}", src, dsts, message, eventId}
            h.createNotification('message', data, cb)
        ], done
  , (err, resp) ->
    return h.sendError(res, err) if err
    debug 'DONE! No error'
    {_rev} = resp
    res.json(201, {_rev, ctime, mtime})


# @name shortlink
#
# @description redirect to the shortlink (if it exists)
exports.shortlink = (req, res, next) ->
  if req.headers?['x-requested-with'] is 'XMLHttpRequest'
    debug "#{req.url}: XMLHttpRequest"
    return next()
  debug 'shortlinkRedirect originalUrl:', req.originalUrl
  return next() if req.url is '/'
  path = req.path[1...req.path.length]

  db = config.db.main()
  db.get path, (err, doc) ->
    url  = doc?.target_url
    type = doc?.type
    replacement = if err or type isnt 'shortlink' then '' else "#!#{url}"
    newUrl = req.originalUrl.replace(path, replacement)
    debug "Redirect: #{req.originalUrl} => #{newUrl}"
    res.redirect(newUrl)
