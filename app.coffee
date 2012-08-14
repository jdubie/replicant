express = require('express')
async = require('async')
_ = require('underscore')
debug = require('debug')('replicant:app')
request = require('request')
util = require('util')

{getUserIdFromSession, hash, getUserDbName} = require('./lib/helpers')
{auth, getUsers, getSwaps, createUserDb, createUnderscoreUser, createEvent, getEventUsers, replicate} = require('./lib/replicant')
adminNotifications = require('./lib/adminNotifications')
config = require('./config')

app = express()
app.use(express.static(__dirname + '/public'))
app.use (req, res, next) ->
  if req.url is '/user_ctx' or (req.url is '/users' and req.method is 'POST')
    express.bodyParser()(req, res, next)
  else
    next()

###
  POST /events
  CreateEvent
    This service creates a swapEventId and initializes involed users 
    @param swapId {string} swap for which swapEvent is being created
    @param session {cookie} authenicates user
    @method POST

    hosts = GET /lifeswap/swapId
    guest = getIdFromSession()
    swapEventId = POST /mapper {guest,hosts}
    return swapEventId
###
app.post  '/events', (req, res) ->
  swapId = req.body.swapId
  debug "POST /events"
  debug "   swapId: #{swapId}"
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err
      res.json({status: 403, reason: 'User must be logged in'}, 403)
    else
      userId = r.userId
      createEvent {swapId, userId}, (e, r) ->
        if e then res.json({status: 500, reason: "Internal Server Error: #{e}"}, 500)
        else
          res.json(r, 201)


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
  Users
###

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
  GET /users
###
app.get '/users', (req, res) ->
  debug "GET /users"
  getUsers (err, users) ->
    debug err, users
    res.json(200, users)
    res.end()

###
  GET /users/:id
###
app.get '/users/:id', (req, res) ->
  debug "GET /users/:id"
  debug "   id = #{req.params.id}"
  request("#{config.dbUrl}/lifeswap/#{req.params.id}").pipe(res)

###
  PUT /users/:id
###
app.put '/users/:id', (req, res) ->
  debug "PUT /users/:id"
  id = req.params.id
  debug "   id = #{id}"

  endpoint = request.put("#{config.dbUrl}/lifeswap/#{id}")
  req.pipe(endpoint)
  endpoint.pipe(res)

###
  DELETE /users/:id
###
app.delete '/users/:id', (req, res) ->
  res.send(403)

###
  Swaps
###

###
  GET /swaps
###
app.get '/swaps', (req, res) ->
  debug "GET /swaps"
  getSwaps (err, swaps) ->
    debug err, swaps
    res.json(200, swaps)

###
  GET /swaps/:id
###
app.get '/swaps/:id', (req, res) ->
  debug "GET /swaps/:id"
  id = req.params.id
  debug "   id = #{id}"
  request("#{config.dbUrl}/lifeswap/#{id}").pipe(res)


###
  POST /swaps
###
app.post '/swaps', (req, res) ->
  debug 'POST /swaps'
  endpoint = request.post("#{config.dbUrl}/lifeswap")
  req.pipe(endpoint)
  endpoint.pipe(res)

###
  PUT /swaps/:id
###
app.put '/swaps/:id', (req, res) ->
  debug "PUT /swaps/:id"
  id = req.params.id
  debug "   id = #{id}"
  endpoint = request.put("#{config.dbUrl}/lifeswap/#{id}")
  req.pipe(endpoint)
  endpoint.pipe(res)



# fire up HTTP server
app.listen(config.port)

# fire up server listening to send out admin actions
adminNotifications.listen()

module.exports = app
