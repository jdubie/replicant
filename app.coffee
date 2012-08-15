express = require('express')
async = require('async')
_ = require('underscore')
debug = require('debug')('replicant:app')
request = require('request')
util = require('util')

{getUserIdFromSession, getUserCtxFromSession, hash, getUserDbName} = require('./lib/helpers')
{auth, getType, createUserDb, createUnderscoreUser, createEvent, getEventUsers, replicate} = require('./lib/replicant')
adminNotifications = require('./lib/adminNotifications')
config = require('./config')

app = express()
app.use(express.static(__dirname + '/public'))

shouldParseBody = (req) ->
  if req.url is '/user_ctx' then return true
  if req.url is '/users' and req.method is 'POST' then return true
  if req.url is '/swaps' and req.method is 'POST' then return true
  if /^\/events(\/.*)?$/.test(req.url) then return true
  if /^\/swaps\/.*$/.test(req.url) and req.method is 'PUT' then return true
  if /^\/users\/.*$/.test(req.url) and req.method is 'PUT' then return true
  return false

app.use (req, res, next) ->
  if shouldParseBody(req)
    debug 'using body parser'
    express.bodyParser()(req, res, next)
  else next()


app.all /^\/events(\/.*)?$/, (req, res, next) ->
  getUserCtxFromSession headers: req.headers, (err, _res) ->
    if err then res.send(403)
    else
      req.userCtx = _res.userCtx
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
    else res.json(201, response)       # {name, roles, id}


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
      debug err, docs
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
    debug "DELETE /#{model}/:id"
    id = req.params.id
    debug "   id = #{id}"
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
# OLD ROUTES
###

# GET /events/members
app.get '/events/members', (req, res) ->
  # TODO: do we want it as a GET?
  eventId = req.query.eventId
  debug "GET /events/members"
  debug "   eventId: #{eventId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      userId = r.userId
      getEventUsers {eventId}, (e, r) ->
        # there should only be responses, no errors
        if e
          res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
        else
          if not (userId in r.users) and not (userId in config.ADMINS)
            res.json({status: 403, reason: "Not authorized to view this event"}, 403)
          else
            res.json(r, 200)

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
app.post '/events/replicate', (req, res) ->
  eventId = req.body.eventId
  debug "POST /events/replicate"
  debug "   eventId: #{eventId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      src = r.userId
      getEventUsers {eventId}, (e, r) ->
        # 404 or 500
        if e then res.json(e, e.status)
        else
          if not (src in r.users) and not (src in config.ADMINS)
            res.json({status: 403, reason: "Not authorized to write messages to this event"}, 403)
          else
            dsts = r.users
            for admin in config.ADMINS
              dsts.push(admin)
            dsts = _.without(r.users, src)
            replicate {src, dsts, eventId}, (e, r) ->
              if e
                res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
              else
                res.json(r, 201)

###
# END OLD ROUTES
###


# fire up HTTP server
app.listen(config.port)

# fire up server listening to send out admin actions
#adminNotifications.listen()

module.exports = app
