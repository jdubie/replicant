express = require('express')
async = require('async')
_ = require('underscore')
debug = require('debug')('replicant:app')
request = require('request')
util = require('util')

{getUserIdFromSession, getUserCtxFromSession, hash, getUserDbName} = require('./lib/helpers')
{auth, getType, getTypeUserDb, createUserDb, createUnderscoreUser, createEvent, getEventUsers, replicate, getMessages, getMessage, markReadStatus} = require('./lib/replicant')
adminNotifications = require('./lib/adminNotifications')
config = require('./config')

app = express()
app.use(express.static(__dirname + '/public'))

shouldParseBody = (req) ->
  if req.url is '/user_ctx' then return true
  if req.url is '/users' and req.method is 'POST' then return true
  if req.url is '/swaps' and req.method is 'POST' then return true
  if req.url is '/events' and req.method is 'POST' then return true
  if req.url is '/messages' and req.method is 'POST' then return true
  if req.url is '/cards' and req.method is 'POST' then return true
  if /^\/swaps\/.*$/.test(req.url) and req.method is 'PUT' then return true
  if /^\/users\/.*$/.test(req.url) and req.method is 'PUT' then return true
  if /^\/events\/.*$/.test(req.url) and req.method is 'PUT' then return true
  if /^\/messages\/.*$/.test(req.url) and req.method is 'PUT' then return true
  if /^\/cards\/.*$/.test(req.url) and req.method is 'PUT' then return true
  return false

app.use (req, res, next) ->
  if shouldParseBody(req)
    debug 'using body parser'
    express.bodyParser()(req, res, next)
  else next()


app.all /^\/(events|messages|cards)(\/.*)?$/, (req, res, next) ->
  getUserCtxFromSession headers: req.headers, (err, _res) ->
    if err then res.send(403)
    else
      userCtx = _res.userCtx
      if not userCtx or not userCtx.name then res.send(403)
      else
        req.userCtx = userCtx
        next()


###
  Login
###
app.post '/user_ctx', (req, res) ->
  username = req.body.username
  password = req.body.password
  debug "POST /user_ctx"
  debug "   username: #{username}"
  auth {username, password}, (err, cookie) ->
    if err or not cookie
      res.send(403, 'Invalid credentials')
    else
      res.set('Set-Cookie', cookie)
      res.end()

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
  {email, password, _id} = user   # extract email and password
  user_id = _id
  # delete private data
  delete user.password
  delete user.email
  debug "   email: #{email}"

  name = hash(email)
  response =
    name: name
    roles: []
    user_id: user_id
  cookie = null

  async.waterfall [
    (next) ->
      ## insert document to _users
      debug '   insert document to _users'
      createUnderscoreUser({email, password, user_id}, next)

    (_res, next) ->
      ## auth to get cookie
      debug '   auth to get cookie'
      auth({username: name, password: password}, next)

    (_cookie, next) ->
      ## create user database
      debug '   create user database'
      cookie = _cookie
      createUserDb({userId: user_id, name: name}, next)

    (_res, next) ->
      ## create 'user' type document
      debug "   create 'user' type document"
      nanoOpts =
        url: "#{config.dbUrl}/lifeswap"
        cookie: cookie
      debug 'nanoOpts', nanoOpts
      userNano = require('nano')(nanoOpts)
      userNano.insert(user, user_id, next)

    (_res, headers, next) ->
      ## create 'email_address' type private document
      #debug JSON.stringify(_res), headers
      debug "   create 'email_address' type private document"
      nanoOpts =
        url: "#{config.dbUrl}/#{getUserDbName(userId: user_id)}"
        cookie: cookie
      userPrivateNano = require('nano')(nanoOpts)
      emailDoc =
        type: 'email_address'
        email_address: email
        user_id: user_id
      userPrivateNano.insert(emailDoc, next)

  ], (err, body, headers) ->
    if err
      debug '   ERROR', err
      res.json(err.status ? 500, err)
    else
      res.set('Set-Cookie', cookie)
      res.json(201, response)       # {name, roles, id}


###
  POST /swaps
###
app.post '/swaps', (req, res) ->
  debug 'POST /swaps'
  swap = req.body
  swap.ctime = Date.now()
  swap.mtime = swap.ctime
  opts =
    method: 'POST'
    url: "#{config.dbUrl}/lifeswap"
    headers: req.headers
    json: swap
  request opts, (err, resp, body) ->
    statusCode = resp.statusCode
    if statusCode isnt 201 then res.send(statusCode)
    else
      _rev = body.rev
      ctime = swap.ctime
      mtime = swap.mtime
      res.json(statusCode, {_rev, ctime, mtime})

_.each ['users', 'swaps'], (model) ->
  ## GET /model
  app.get "/#{model}", (req, res) ->
    debug "GET /#{model}"
    getType model, (err, docs) ->
      res.json(200, docs)
      res.end()

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
    request opts, (err, resp, body) ->
      statusCode = resp.statusCode
      if statusCode isnt 201 then res.send(statusCode)
      else
        _rev = body.rev
        res.json(statusCode, {_rev, mtime})

  ## DELETE /model/:id
  app.delete "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "DELETE /#{model}/#{id}"
    res.send(403)

###
  POST /events
  CreateEvent
    This service creates a swap event and initializes involved users 
    @body event {object} event to create
    @headers cookie {cookie} authenicates user
    @method POST

    return {_rev, ctime, mtime}
###
app.post '/events', (req, res) ->
  event = req.body    # {_id, type, state, swap_id}
  userCtx = req.userCtx
  ## TODO: validate that event has _id, type, state, swap_id
  debug "POST /events"
  debug "   event: #{event}"
  createEvent {event, userId: userCtx.name}, (err, _res) ->
    if err then res.send(err.statusCode)
    else res.send(201, _res)    # {_rev, mtime, ctime}


###
  Some routes for:
    /events
    /cards
###
_.each ['events', 'cards'], (model) ->
  ## GET /model
  app.get "/#{model}", (req, res) ->
    debug "GET /#{model}"
    userCtx = req.userCtx   # from the app.all route
    cookie = req.headers.cookie
    getTypeUserDb model, userCtx.name, cookie, (err, docs) ->
      if err
        statusCode = err.status_code ? 500
        res.json(statusCode, err)
      else
        res.json(200, docs)
  ## GET /model/:id
  app.get "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "GET /#{model}/#{id}"
    userCtx = req.userCtx   # from the app.all route
    userDbName = getUserDbName(userId: userCtx.name)
    endpoint =
      url: "#{config.dbUrl}/#{userDbName}/#{id}"
      headers: req.headers
    request(endpoint).pipe(res)

###
  DELETE
    /events
    /cards
    /messages
###
_.each ['events', 'cards', 'messages'], (model) ->
  app.delete "/#{model}/:id", (req, res) ->
    id = req.params?.id
    debug "DELETE /#{model}/#{id}"
    res.send(403)

###
  PUT /cards/:id
###
app.put "/cards/:id", (req, res) ->
  id = req.params?.id
  debug "PUT /cards/#{id}"
  userCtx = req.userCtx   # from the app.all route
  userDbName = getUserDbName(userId: userCtx.name)
  card = req.body
  mtime = Date.now()
  card.mtime = mtime
  opts =
    method: 'PUT'
    url: "#{config.dbUrl}/#{userDbName}/#{id}"
    headers: req.headers
    json: card
  request opts, (err, resp, body) ->
    statusCode = resp.statusCode
    if statusCode isnt 201 then res.send(statusCode)
    else
      _rev = body.rev
      res.json(statusCode, {_rev, mtime})

###
  POST /cards/:id
###
app.post "/cards", (req, res) ->
  debug "PUT /cards"
  userCtx = req.userCtx   # from the app.all route
  userDbName = getUserDbName(userId: userCtx.name)
  card = req.body
  ctime = Date.now()
  mtime = ctime
  card.ctime = ctime
  card.mtime = mtime
  opts =
    method: 'POST'
    url: "#{config.dbUrl}/#{userDbName}"
    headers: req.headers
    json: card
  request opts, (err, resp, body) ->
    statusCode = resp.statusCode
    if statusCode isnt 201 then res.send(statusCode)
    else
      _rev = body.rev
      res.json(statusCode, {_rev, mtime, ctime})

###
  PUT /events/:id
###
app.put '/events/:id', (req, res) ->
  id = req.params?.id
  debug "PUT /events/#{id}"
  userCtx = req.userCtx   # from the app.all route
  userDbName = getUserDbName(userId: userCtx.name)
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
        getEventUsers({eventId: event._id}, next)   # (err, users)
    (users, next) ->
      debug 'replicate'
      src = userCtx.name
      eventId = event._id
      if not (src in users) and not (src in config.ADMINS)
        next(statusCode: 403, reason: "Not authorized to write messages to this event")
      else
        for admin in config.ADMINS
          users.push(admin)
        dsts = _.without(users, src)
        replicate({src, dsts, eventId}, next)   # (err, resp)
  ], (err, resp) ->
    if err then res.json(err.statusCode ? 500, err)
    else res.json(201, {_rev, mtime})


app.post '/messages', (req, res) ->
  debug "POST /message"
  userCtx = req.userCtx   # from the app.all route
  userDbName = getUserDbName(userId: userCtx.name)
  message = req.body
  ctime = Date.now()
  message.ctime = ctime
  _rev = null
  eventId = message.event_id

  async.waterfall [
    (next) ->
      debug 'post message'
      opts =
        method: 'POST'
        url: "#{config.dbUrl}/#{userDbName}"
        headers: req.headers
        json: message
      request(opts, next) # (err, resp, body)
    (resp, body, next) ->
      debug 'mark message read'
      statusCode = resp.statusCode
      if statusCode isnt 201 then next(statusCode: statusCode)
      else
        _rev = body.rev
        opts =
          method: 'POST'
          url: "#{config.dbUrl}/#{userDbName}"
          headers: req.headers
          json:
            type: 'read'
            message_id: message._id
            event_id: message.event_id
        request(opts, next) # (err, resp, body)
    (resp, body, next) ->
      debug 'get users'
      getEventUsers({eventId}, next)  # (err, users)
    (users, next) ->
      debug 'replicate'
      src = userCtx.name
      if not (src in users) and not (src in config.ADMINS)
        next(statusCode: 403, reason: "Not authorized to write messages to this event")
      else
        users.push(admin) for admin in config.ADMINS
        dsts = _.without(users, src)
        replicate({src, dsts, eventId}, next)   # (err, resp)
  ], (err, resp) ->
    if err then res.json(err.statusCode ? 500, err)
    else res.json(201, {_rev, ctime})


app.put '/messages/:id', (req, res) ->
  ## TODO: _allow_ change only when read => true (write 'read' doc)
  id = req.params?.id
  debug "PUT /messages/#{id}"
  userCtx = req.userCtx
  cookie = req.headers.cookie
  message = req.body
  markReadStatus message, userCtx.name, cookie, (err, _res) ->
    if err
      statusCode = err.statusCode ? err.status_code ? 500
      res.json(statusCode, err)
    else
      res.send(201)

app.get '/messages', (req, res) ->
  debug "GET /messages"
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  getMessages userCtx.name, cookie, (err, messages) ->
    if err
      statusCode = err.statusCode ? err.status_code ? 500
      res.json(statusCode, err)
    else
      res.json(200, messages)

app.get '/messages/:id', (req, res) ->
  id = req.params?.id
  debug "GET /messages/#{id}"
  userCtx =  req.userCtx
  cookie = req.headers.cookie
  getMessage id, userCtx.name, cookie, (err, message) ->
    if err
      statusCode = err.statusCode ? err.status_code ? 500
      res.json(statusCode, err)
    else
      res.json(200, message)

## TODO:
#   * cards, email_addresses, phone_numbers

###
# OLD ROUTES
###

# GET /events/members
#app.get '/events/members', (req, res) ->
#  eventId = req.query.eventId
#  debug "GET /events/members"
#  debug "   eventId: #{eventId}"
#  getUserIdFromSession headers: req.headers, (err, r) ->
#    if err
#      res.json({status: 403, reason: 'User must be logged in'}, 403)
#    else
#      userId = r.userId
#      getEventUsers {eventId}, (e, r) ->
#        # there should only be responses, no errors
#        if e
#          res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
#        else
#          if not (userId in r.users) and not (userId in config.ADMINS)
#            res.json({status: 403, reason: "Not authorized to view this event"}, 403)
#          else
#            res.json(r, 200)

###
  POST /events/message
  ReplicateEventMessage swapEventId, session
    This service triggers replications between users databases
    @todo make PUT
    @possibleName Replicant
    @param swapEventId {string} id of swap event to filter on
    @param session {cookie} authenicates user
    @method POST
    @url /events/message

    ids = GET /mapper/swapEventId
    src = getIdFromSession()
    ids.each (dst) -
    replicate src, dst, filter(swapEventId)
###
#app.post '/events/replicate', (req, res) ->
#  eventId = req.body.eventId
#  debug "POST /events/replicate"
#  debug "   eventId: #{eventId}"
#  getUserIdFromSession headers: req.headers, (err, r) ->
#    if err
#      res.json({status: 403, reason: 'User must be logged in'}, 403)
#    else
#      src = r.userId
#      getEventUsers {eventId}, (e, r) ->
#        # 404 or 500
#        if e then res.json(e, e.status)
#        else
#          if not (src in r.users) and not (src in config.ADMINS)
#            res.json({status: 403, reason: "Not authorized to write messages to this event"}, 403)
#          else
#            dsts = r.users
#            for admin in config.ADMINS
#              dsts.push(admin)
#            dsts = _.without(r.users, src)
#            replicate {src, dsts, eventId}, (e, r) ->
#              if e
#                res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
#              else
#                res.json(r, 201)

###
# END OLD ROUTES
###


# fire up HTTP server
app.listen(config.port)

# fire up server listening to send out admin actions
#adminNotifications.listen()

module.exports = app
