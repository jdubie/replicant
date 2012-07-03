express = require('express')
request = require('request')
controllers = require('./lib/replicant')

class Forbidden
  constructor: (@msg) ->
    @name = 'Forbidden'
    @status = 403
    Error.call(@, @msg)

class InternalServerError
  constructor: (@msg) ->
    @name = 'Internal Server Error'
    @status = 500
    Error.call(@, @msg)

module.exports = app = express.createServer()

app._controllers = controllers

getUserIdFromSession = ({cookie}, callback) ->
  opts =
    method: 'get'
    url: 'http://lifeswaptest:5985/_session'
    headers: cookie: cookie
  request opts, (err, res, body) ->
    userId = JSON.parse(body)?.userCtx?.name
    if userId? then callback(null, {userId})
    else callback(true) # will trigger 403

app.post '/signup', (req, res) ->
  cookie = req.headers.cookie
  getUserIdFromSession {cookie}, (err, {userId}) ->
    if err then throw new Forbidden('User must be logged in')
    else
      app._controllers.signup {userId}, (e,r) ->
        if e then throw new InternalServerError(e.toString())
        else res.end(r)

app.post '/swapEvent', (req, res) ->
  #res.send app._controllers.swapEvent()

# fire that baby up
app.listen(3000)

###
  For testing purposes only
###
app.setController = ({controller}, callback) ->
  app._controllers[controller] = callback
