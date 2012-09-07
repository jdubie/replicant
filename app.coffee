express = require('express')
path = require('path')
async = require('async')
_ = require('underscore')
debug = require('debug')('replicant:app')
request = require('request')
util = require('util')

config = require('config')
rep = require('lib/replicant')
h = require('lib/helpers')

app = express()
app.use(express.static(__dirname + '/public'))

shouldParseBody = (req) ->
  if req.method is 'DELETE'
    if req.url.match /^\/likes\/.*$/ then return true
  if req.url is '/user_ctx' then return true
  if req.method is 'POST'
    # lifeswap db
    if req.url is '/users' then return true
    if req.url is '/swaps' then return true
    if req.url is '/reviews' then return true
    if req.url is '/likes' then return true
    if req.url is '/requests' then return true
    # user db
    if req.url is '/events' then return true
    if req.url is '/messages' then return true
    if req.url is '/cards' then return true
    if req.url is '/payments' then return true
    if req.url is '/email_addresses' then return true
    if req.url is '/phone_numbers' then return true
    if req.url is '/refer_emails' then return true
  if req.method is 'PUT'
    # lifeswap db
    if /^\/users\/.*$/.test(req.url) then return true
    if /^\/swaps\/.*$/.test(req.url) then return true
    if /^\/reviews\/.*$/.test(req.url) then return true
    if /^\/likes\/.*$/.test(req.url) then return true
    if /^\/requests\/.*$/.test(req.url) then return true
    # user db
    if /^\/events\/.*$/.test(req.url) then return true
    if /^\/messages\/.*$/.test(req.url) then return true
    if /^\/cards\/.*$/.test(req.url) then return true
    if /^\/payments\/.*$/.test(req.url) then return true
    if /^\/email_addresses\/.*$/.test(req.url) then return true
    if /^\/phone_numbers\/.*$/.test(req.url) then return true
  return false

app.use (req, res, next) ->
  if shouldParseBody(req)
    debug 'using body parser'
    express.bodyParser()(req, res, next)
  else next()

userCtxRegExp = /^\/(events|messages|cards|payments|email_addresses|phone_numbers|refer_emails)(\/.*)?$/
app.all userCtxRegExp, (req, res, next) ->
  h.getUserCtxFromSession req, (err, userCtx) ->
    if err then res.json(err.statusCode ? err.status_code ? 500, err)
    else
      req.userCtx = userCtx
      next()

###
  Login
###
app.post '/user_ctx', (req, res) ->
  username = h.hash(req.body.username)
  password = req.body.password
  debug "POST /user_ctx"
  debug "   username: #{username}"
  rep.auth {username, password}, (err, cookie) ->
    return h.sendError(res, err) if err
    res.set('Set-Cookie', cookie)
    h.getUserId {cookie, userCtx: name: username}, (err, userCtx) ->
      return h.sendError(res, err) if err
      res.json(userCtx)

###
  Logout
###
app.delete '/user_ctx', (req, res) ->
  opts =
    url: "#{config.dbUrl}/_session"
    method: 'DELETE'
  request(opts).pipe(res)

###
  Get user session
###
app.get '/user_ctx', (req, res) ->
  opts =
    headers: req.headers
    url: "#{config.dbUrl}/_session"
    json: true
  h.request opts, (err, body) ->
    return h.sendError(res, err) if err
    debug "GET /user_ctx"
    debug '   body', body
    userCtx = body.userCtx
    return res.json(200, userCtx) unless userCtx.name?
    cookie = req.headers.cookie
    h.getUserId {cookie, userCtx}, (err, userCtx) ->
      return h.sendError(res, err) if err
      res.json(200, userCtx)

###
  Change password
###
app.put '/user_ctx', (req, res) ->
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

#
# Get zipcode mapping
#
app.get '/zipcodes/:id', (req, res) ->
  callback = (err, body) ->
    if body.rows.length == 0
      error =
        error : 'Not found'
        reason: zipcode: ['Not a valid zipcode']
      res.json(404, error)
    else res.json(body.rows[0].value)

  db = config.nano.use('zipcodes')
  db.view('zipcodes', 'zipcodes', {key: req.params.id}, h.nanoCallback(callback))

###
  POST /users
  CreateUser
    This creates a user database and preliminary doc after user signups on client
    using user.signup and session.login on client
    @param session {cookie} authenicates user
    @method POST
    @url /users

    userId = getIdFromSession()
    POST / userId # creates users database
    POST /userId {firstname, lastname, ...}
    replicate /userId /lifeswap filter(public)
###
app.post '/users', (req, res) ->
  debug "POST /users"
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

  async.waterfall [
    (next) ->
      ## insert document to _users
      debug '   insert document to _users'
      rep.createUnderscoreUser({email, password, user_id}, next)

    (_res, next) ->
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
      nanoOpts =
        url: "#{config.dbUrl}/lifeswap"
        cookie: cookie
      debug 'nanoOpts', nanoOpts
      userNano = require('nano')(nanoOpts)
      userNano.insert(user, user_id, h.nanoCallback(next))

    (_res, headers, next) ->
      response._rev = _res?.rev    # add _rev to response
      ## create 'email_address' type private document
      debug "   create 'email_address' type private document"
      nanoOpts =
        url: "#{config.dbUrl}/#{h.getUserDbName(userId: user_id)}"
        cookie: cookie
      userPrivateNano = require('nano')(nanoOpts)
      emailDoc =
        type: 'email_address'
        name: name
        user_id: user_id
        email_address: email
        ctime: ctime
        mtime: mtime
      userPrivateNano.insert(emailDoc, h.nanoCallback(next))

    (_res, headers, next) ->
      data = {user, emailAddress: email}
      h.createNotification('user.create', data, next)

  ], (err, body, headers) ->
    return h.sendError(res, err) if err
    res.set('Set-Cookie', cookie)
    res.json(201, response)       # {name, roles, id}


###
  POST
    /swaps
    /reviews
    /likes
    /requests
###
_.each ['swaps', 'reviews', 'likes', 'requests'], (model) ->
  app.post "/#{model}", (req, res) ->
    debug "POST /#{model}"
    doc = req.body
    ctime = mtime = Date.now()
    doc.ctime = ctime
    doc.mtime = mtime
    opts =
      method: 'POST'
      url: "#{config.dbUrl}/lifeswap"
      headers: req.headers
      json: doc
    h.request opts, (err, body) ->
      return h.sendError(res, err) if err
      h.createSimpleCreateNotification model, doc, (err) ->
        return h.sendError(res, err) if err
        _rev = body.rev
        res.json(201, {_rev, ctime, mtime})


###
  GET, GET/:id, PUT
    /users
    /swaps
    /reviews
    /likes
    /requests
###
_.each ['users', 'swaps', 'reviews', 'likes', 'requests'], (model) ->
  ## GET /model
  app.get "/#{model}", (req, res) ->
    debug "GET /#{model}"
    type = h.singularizeModel(model)
    rep.getType type, (err, docs) ->
      return h.sendError(res, err) if err?
      res.json(200, docs)

  ## GET /model/:id
  app.get "/#{model}/:id", (req, res) ->
    debug "GET /#{model}/:id"
    id = req.params.id
    debug "   id = #{id}"
    request("#{config.dbUrl}/lifeswap/#{id}").pipe(res)

  ## PUT /model/:id
  app.put "/#{model}/:id", (req, res) ->
    debug "PUT /#{model}/:id"
    id = req.params.id
    debug "   id = #{id}"

    doc = req.body
    mtime = Date.now()
    doc.mtime = mtime
    opts =
      method: 'PUT'
      url: "#{config.dbUrl}/lifeswap/#{id}"
      headers: req.headers
      json: doc
    h.request opts, (err, body) ->
      return h.sendError(res, err) if err
      _rev = body.rev
      res.json(200, {_rev, mtime})


###
  DELETE
    /swaps
    /reviews
    /requests
###
_.each ['swaps', 'reviews', 'requests'], (model) ->
  ## DELETE /model/:id
  app.delete "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "DELETE /#{model}/#{id}"
    res.send(403)

###
  DELETE
    /likes
###
_.each ['likes'], (model) ->
  app.delete "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "DELETE /#{model}/#{id}"
    doc = req.body
    debug "   req.body", doc
    opts =
      method: 'DELETE'
      url: "#{config.dbUrl}/lifeswap/#{id}"
      headers: req.headers
      qs: rev: req.body._rev
      json: req.body
    request(opts).pipe(res)


###
  DELETE /users/:id
###
app.delete "/users/:id", (req, res) ->
  userId = req.params?.id
  debug "DELETE /users/#{userId}"
  async.waterfall [
    ## get user ctx
    (next) ->
      h.getUserCtxFromSession(req, next)
    (userCtx, next) ->
      if not ('constable' in userCtx.roles) then next(statusCode: 403)
      else next(null, userCtx)
    ## if a constable!
    (userCtx, next) ->
      cookie = req.headers.cookie
      userName = userRev = null
      userRev = null

      async.waterfall [
        (_next) ->
          debug 'get user document'
          nanoOpts =
            url: "#{config.dbUrl}/lifeswap"
            cookie: cookie
          db = require('nano')(nanoOpts)
          db.get(userId, h.nanoCallback(_next))
        (userDoc, hdr, _next) ->
          userRev = userDoc._rev
          userName = userDoc.name

          async.series [
            ## delete _user document
            (cb) ->
              debug 'delete _user'
              db = config.nanoAdmin.use('_users')
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
              nanoOpts =
                url: "#{config.dbUrl}/lifeswap"
                cookie: cookie
              db = require('nano')(nanoOpts)
              db.destroy(userId, userRev, h.nanoCallback(cb))

            ## delete user DB
            (cb) ->
              debug 'delete user db'
              userDbName = h.getUserDbName({userId})
              debug 'userDbName', userDbName
              config.nanoAdmin.db.destroy(userDbName, h.nanoCallback(cb))
          ], _next
      ], next
  ], (err, _res) ->
    return h.sendError(res, err) if err?
    res.send(200)


###
  POST /events
  CreateEvent
    This service creates a swap event and initializes involved users 
    @body event {object} event to create
    @headers cookie {cookie} authenicates user
    @method POST

    return {_rev, ctime, mtime, hosts, guests}
###
app.post '/events', (req, res) ->
  ## TODO: validate that event has _id, type, state, swap_id
  event = req.body    # {_id, type, state, swap_id}
  userCtx = req.userCtx

  debug "POST /events"
  debug "   event" , event

  ctime = Date.now()
  mtime = ctime
  event.ctime = ctime
  event.mtime = mtime

  # global boy
  swap = null

  async.parallel

    # insert event document into constable db
    _rev: (done) ->
      extractRev = (err, body) ->
        return done(err) if err
        done(null, body.rev)
      config.db.constable().insert(event, h.nanoCallback(extractRev))

    # put all users assosciated with swap and return them
    mapping: (done) ->
      async.waterfall [
        (next) ->
          config.db.main().get(event.swap_id, h.nanoCallback2(next))
        (swap, next) ->
          mapping = _id: event._id, guests: [userCtx.user_id], hosts: [swap.user_id]
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
      #h.createNotification 'event.create', {title: "event #{event._id}: event created", guests, hosts, event, swap}, (err) ->
      #  return h.sendError(err, body) if err
      res.json(201, {_rev, hosts, guests, ctime, mtime})


###
  GET /events
###
app.get '/events', (req, res) ->
  debug "GET /events"
  userCtx = req.userCtx   # from the app.all route
  cookie = req.headers.cookie
  debug 'userCtx', userCtx
  async.waterfall [
    (next) ->
      rep.getTypeUserDb({type: 'event', userId: userCtx.user_id, cookie, roles: userCtx.roles}, next)
    (events, next) ->
      async.map(events, rep.addEventHostsAndGuests, next)
  ], (err, events) ->
    return h.sendError(res, err) if err
    res.json(200, events)

###
  GET /events/:id
###
app.get "/events/:id", (req, res) ->
  id = req.params?.id
  debug "GET /events/#{id}"
  userCtx = req.userCtx   # from the app.all route
  cookie = req.headers.cookie
  nanoOpts =
    url: "#{config.dbUrl}/#{h.getUserDbName(userId: userCtx.user_id)}"
    cookie: cookie
  userPrivateNano = require('nano')(nanoOpts)
  async.waterfall [
    (next) -> userPrivateNano.get(id, h.nanoCallback(next))
    (event, hdrs, next) ->
      rep.addEventHostsAndGuests(event, next)
  ], (err, event) ->
    return h.sendError(res, err) if err
    res.json(200, event)

###
  Some routes for:
    /cards
    /payments
    /email_addresses
    /phone_numbers
###
_.each ['cards', 'payments', 'email_addresses', 'phone_numbers'], (model) ->
  ## GET /model
  app.get "/#{model}", (req, res) ->
    debug "GET /#{model}"
    userCtx = req.userCtx   # from the app.all route
    cookie = req.headers.cookie
    type = h.singularizeModel(model)
    debug 'userCtx', userCtx
    rep.getTypeUserDb {type, userId: userCtx.user_id, cookie, roles: userCtx.roles}, (err, docs) ->
      return h.sendError(res, err) if err
      res.json(200, docs)

  ## GET /model/:id
  app.get "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "GET /#{model}/#{id}"
    userCtx = req.userCtx   # from the app.all route
    userDbName = h.getUserDbName(userId: userCtx.user_id)
    endpoint =
      url: "#{config.dbUrl}/#{userDbName}/#{id}"
      headers: req.headers
    request(endpoint).pipe(res)

###
  DELETE
    /events
    /messages
    /cards
    /payments
    /email_addresses
    /phone_numbers
###
_.each ['events', 'messages', 'cards', 'payments', 'email_addresses', 'phone_numbers'], (model) ->
  app.delete "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "DELETE /#{model}/#{id}"
    res.send(403)

###
  POST/PUT
    /cards/:id
    /payments/:id
    /email_addresses/:id
    /phone_numbers/:id
###
_.each ['cards', 'payments', 'email_addresses', 'phone_numbers', 'refer_emails'], (model) ->
  ## POST /models
  app.post "/#{model}", (req, res) ->
    debug "POST /#{model}"
    debug "   req.userCtx", req.userCtx
    userCtx = req.userCtx   # from the app.all route
    doc = req.body
    _id = doc._id
    ctime = mtime = Date.now()
    doc.ctime = ctime
    doc.mtime = mtime

    async.series
      _rev: (next) ->
        userDbName = h.getUserDbName(userId: userCtx.user_id)
        opts =
          method: 'POST'
          url: "#{config.dbUrl}/#{userDbName}"
          headers: req.headers
          json: doc
        h.request opts, (err, body) ->
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

  ## PUT /models/:id
  app.put "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "PUT /#{model}/#{id}"
    userCtx = req.userCtx   # from the app.all route
    doc = req.body
    mtime = Date.now()
    doc.mtime = mtime

    async.series
      _rev: (next) ->
        userDbName = h.getUserDbName(userId: userCtx.user_id)
        opts =
          method: 'PUT'
          url: "#{config.dbUrl}/#{userDbName}/#{id}"
          headers: req.headers
          json: doc
        h.request opts, (err, body) ->
          return next(err) if err
          next(null, body.rev)
      replicate: (next) ->
        h.replicateIn(userCtx.user_id, [doc._id],next)
    , (err, resp) ->
      return h.sendError(res, err) if err
      _rev = resp._rev
      res.json(201, {_rev, mtime})


###
  PUT /events/:id
###
app.put '/events/:id', (req, res) ->
  id = req.params?.id
  debug "PUT /events/#{id}"
  userCtx = req.userCtx   # from the app.all route
  userDbName = h.getUserDbName(userId: userCtx.user_id)
  event = req.body
  mtime = Date.now()
  event.mtime = mtime
  _rev = null
  
  async.waterfall [
    (next) ->
      debug 'put event'
      opts =
        method: 'PUT'
        url: "#{config.dbUrl}/#{userDbName}/#{id}"
        headers: req.headers
        json: event
      request(opts, next) # (err, resp, body)
    (resp, body, next) ->
      debug 'get users'
      statusCode = resp.statusCode
      if statusCode isnt 201 then next(statusCode: statusCode)
      else
        _rev = body.rev
        rep.getEventUsers({eventId: event._id}, next)   # (err, users)
    (users, next) ->
      debug 'replicate'
      src = userCtx.user_id
      eventId = event._id
      if not (src in users) and not (src in config.ADMINS)
        next(statusCode: 403, reason: "Not authorized to modify this event")
      else
        users.push(admin) for admin in config.ADMINS
        dsts = _.without(users, src)
        rep.replicate({src, dsts, eventId}, next)   # (err)

    (next) ->
      data = {event, rev: event._rev, userId: userCtx.user_id}
      h.createNotification('event.update', data, next)

  ], (err, resp) ->
    return h.sendError(res, err) if err
    res.json(201, {_rev, mtime})


app.post '/messages', (req, res) ->
  debug "POST /message"
  userCtx = req.userCtx   # from the app.all route
  message = req.body

  if (message.name isnt userCtx.name or message.user_id isnt userCtx.user_id) and not ('constable' in userCtx.roles)
    return res.send(403)

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
      h.request(opts, done)

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


app.put '/messages/:id', (req, res) ->
  ## TODO: _allow_ change only when read => true (write 'read' doc)
  id = req.params?.id
  debug "PUT /messages/#{id}"
  userCtx = req.userCtx
  cookie = req.headers.cookie
  message = req.body
  rep.markReadStatus message, userCtx.user_id, cookie, (err, _res) ->
    return h.sendError(res, err) if err
    res.send(201)

app.get '/messages', (req, res) ->
  debug "GET /messages"
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  rep.getMessages userCtx.user_id, cookie, (err, messages) ->
    return h.sendError(res, err) if err
    res.json(200, messages)

app.get '/messages/:id', (req, res) ->
  id = req.params?.id
  debug "GET /messages/#{id}"
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  rep.getMessage id, userCtx.user_id, cookie, (err, message) ->
    return h.sendError(res, err) if err
    res.json(200, message)

# fire up HTTP server
app.listen(config.port)

# fire up server listening to send out admin actions
#adminNotifications.listen()

## recruiting
app.get '/they-took-our-jobs', (req, res) ->
  res.end('am9icyticm9ncmFtbWVyQHRoZWxpZmVzd2FwLmNvbQ==')

module.exports = app
