async   = require('async')
_       = require('underscore')
debug   = require('debug')('replicant:routes')

config  = require('config')
rep     = require('lib/replicant')
h       = require('lib/helpers')
validators = require('validation')


exports.login = (req, res) ->
  return if h.verifyRequiredFields(req, res, ['username', 'password'])
  {username, password} = req.body
  db = config.db._users()
  username = h.hash(username.toLowerCase())

  db.get h.getCouchUserName(username), (err, doc) ->
    return h.sendError(res, err) if err

    # look up user doc
    {salt, password_sha, name, roles, user_id} = doc
    userCtx = {name, roles, user_id}

    # hash their password with salt
    if h.hash(password + salt) isnt password_sha
      return h.sendError(res, {statusCode: 401, error: '', reason: ''})

    # start their session
    h.setCtx(req, userCtx)
    res.json(userCtx)


exports.logout = (req, res) ->
  delete req.session.userCtx
  res.send(200)

# @name session
#
# @description gets the session information for the current user
exports.session = (req, res) ->
  res.json(200, h.getCtx(req))

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
  user.user_id = _id
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
      ## get userCtx
      h.getUserCtxFromSession({headers: {cookie}}, next)

    (userCtx, headers, next) ->
      updateCookie(headers)
      ## validate user doc
      Validator = validators.user
      return next() if not Validator?
      validator = new Validator(userCtx)
      validator.validateDoc(user, next)

    (next) ->
      ## create 'user' type document
      debug "   create 'user' type document"
      userNano = config.db.main()
      userNano.insert(user, user_id, next)

    (_res, headers, next) ->
      updateCookie(headers)
      response._rev = _res?.rev    # add _rev to response
      ## create 'email_address' type private document
      debug "   create 'email_address' type private document"
      userPrivateNano = config.db.user(user_id)
      emailDoc =
        type: 'email_address'
        name: name
        user_id: user_id
        email_address: email
        ctime: ctime
        mtime: mtime
      userPrivateNano.insert(emailDoc, next)

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
  userCtx = req.userCtx   # from the app.all route
  doc     = req.body

  ctime = mtime = Date.now()
  doc.ctime = ctime
  doc.mtime = mtime

  async.series
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
  userCtx = req.userCtx
  doc     = req.body

  mtime     = Date.now()
  doc.mtime = mtime

  db = config.db.main()
  db.insert doc, id, (err, resp) ->
    return h.sendError(res, err) if err
    res.json(200, {_rev: resp.rev, mtime})


exports.forbidden = (req, res) ->
  debug "#forbidden: #{req.url}"
  res.send(403)


exports.deleteUser = (req, res) ->
  userId = req.params?.id
  debug "DELETE /users/#{userId}"

  async.waterfall [
    ## get user ctx
    (next) ->
      h.getUserCtxFromSession(req, next)
    (userCtx, _headers, next) ->
      if not ('constable' in userCtx.roles) then next(statusCode: 403)
      else next(null, userCtx)
    ## if a constable!
    (userCtx, next) ->
      userName = userRev = null
      userRev = null

      async.waterfall [
        (_next) ->
          debug 'get user document'
          db = config.db.main()
          db.get(userId, _next)
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
                  db.get(_username, done)
                (_userDoc, hdr, done) ->
                  debug 'destroying _user'
                  db.destroy(_username, _userDoc._rev, done)
              ], cb

            ## delete user type document
            (cb) ->
              debug 'delete user'
              db = config.db.main()
              db.destroy(userId, userRev, cb)

            ## delete user DB
            (cb) ->
              debug 'delete user db'
              userDbName = h.getUserDbName({userId})
              debug 'userDbName', userDbName
              config.couch().db.destroy(userDbName, cb)
          ], _next
      ], next
  ], (err, _res) ->
    return h.sendError(res, err) if err?
    res.send(200)


exports.deletePublic = (req, res) ->
  debug "DELETE #{req.url}"
  id      = req.params?.id
  userCtx = req.userCtx
  doc     = req.body
  debug "   req.body", doc
  return if h.verifyRequiredFields(req, res, ['_rev'])

  db = config.db.main()
  db.destroy doc._id, doc._rev, (err, resp) ->
    return h.sendError(err, res) if err
    res.json(200, _rev: resp.rev)


# @name createEvent
#
# @description creates a swap event and initializes involved users
# @body event {object} event to create
# 
# @return {_rev, ctime, mtime, hosts, guests}
exports.createEvent = (req, res) ->
  event   = req.body    # {_id, type, state, swap_id}
  userCtx = req.userCtx

  debug "POST /events"
  debug "   event" , event

  delete event.hosts
  delete event.guests
  mtime = ctime = Date.now()
  event.ctime = ctime
  event.mtime = mtime
  event["#{event.state}_time"] = ctime

  # global boy
  swap = _rev = hosts = guests = null

  async.series [

    (next) ->
      async.parallel [

        # insert event document into constable db
        (done) ->
          config.db.constable().insert event, (err, body) ->
            _rev = body?.rev
            done(err)

        # put all users associated with swap and return them
        (done) ->
          async.waterfall [
            (next) ->
              config.db.main().get(event.swap_id, next)
            (_swap, headers, next) ->
              swap    = _swap
              guests  = [userCtx.user_id]
              hosts   = [_swap.user_id]
              mapping = {_id: event._id, guests, hosts}
              config.db.mapper().insert(mapping, next)
          ], done

      ], next
    (next) ->
      h.replicateOut(_.union(guests, hosts), [event._id], next)
    (next) ->
      notifyData = {title: "event #{event._id}: event created", guests, hosts, event, swap}
      h.createNotification('event.create', notifyData, next)
  ], (err) ->
    return h.sendError(res, err) if err
    result = {_rev, hosts, guests, ctime, mtime}
    result["#{event.state}_time"] = event["#{event.state}_time"]
    res.json(201, result)


exports.getEvents = (req, res) ->
  debug "GET /events"
  userCtx = req.userCtx   # from the app.all route
  debug 'userCtx', userCtx
  headers = null
  async.waterfall [
    (next) ->
      rep.getTypeUserDb {
        type: 'event'
        userId: userCtx.user_id
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
  userPrivateNano = config.db.user(userCtx.user_id)
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

  userCtx     = req.userCtx   # from the app.all route
  userDbName  = h.getUserDbName(userId: userCtx.user_id)
  event       = req.body
  mtime       = Date.now()
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
        isConstable = 'constable' in userCtx.roles
        if not isConstable
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

      userId = if isConstable then 'drunk_tank' else userCtx.user_id
      db = config.db.user(userId)
      db.insert(event, event._id, next)

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
  debug 'userCtx', userCtx
  rep.getTypeUserDb {type, userId: userCtx.user_id, roles: userCtx.roles}, (err, docs, headers) ->
    h.setCookie(res, headers)
    return h.sendError(res, err) if err
    res.json(200, docs)


exports.onePrivate = (req, res) ->
  id = req.params?.id
  debug "GET #{req.url}"
  userCtx = req.userCtx
  userDbName = h.getUserDbName(userId: userCtx.user_id)

  db = config.db.user(userCtx.user_id)
  db.get(id).pipe(res)


exports.deletePrivate = (req, res) ->
  id      = req.params?.id
  userCtx = req.userCtx   # from the app.all route
  debug "DELETE #{req.url}: userCtx", userCtx

  isConstable = 'constable' in userCtx.roles
  constableDb = config.db.constable()
  docRev = null

  async.waterfall [
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
        userDb = config.db.user(userId)

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
  userCtx = req.userCtx   # from the app.all route
  doc     = req.body

  _id   = doc._id
  ctime = mtime = Date.now()
  doc.ctime = ctime
  doc.mtime = mtime

  async.series
    _rev: (next) ->
      db = config.db.user(userCtx.user_id)
      db.insert doc, doc._id, (err, body) ->
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
  userCtx = req.userCtx   # from the app.all route
  doc     = req.body

  mtime     = Date.now()
  doc.mtime = mtime

  async.series
    _rev: (next) ->
      db = config.db.user(userCtx.user_id)
      db.insert doc, doc._id, (err, body) ->
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
  message = req.body
  rep.markReadStatus message, userCtx.user_id, (err, _res) ->
    return h.sendError(res, err) if err
    res.send(201)


exports.getMessages = (req, res) ->
  debug "GET #{req.url}"
  type = h.getTypeFromUrl(req.url)
  userCtx =  req.userCtx
  rep.getMessages {
    userId: userCtx.user_id
    roles: userCtx.roles
    type
  }, (err, messages) ->
    return h.sendError(res, err) if err
    res.json(200, messages)


exports.getMessage = (req, res) ->
  id = req.params?.id
  debug "GET #{req.url}"
  userCtx =  req.userCtx
  rep.getMessage {
    id, userId: userCtx.user_id, roles: userCtx.roles
  }, (err, message) ->
    return h.sendError(res, err) if err
    res.json(200, message)


exports.sendMessage = (req, res) ->
  debug "POST /message"

  userCtx = req.userCtx
  message = req.body

  # should be fixed by Validator call
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
      db = config.db.user(message.user_id)
      doc =
        type: 'read'
        message_id: message._id
        event_id: message.event_id
        ctime: ctime
      db.insert doc, (err) ->
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
