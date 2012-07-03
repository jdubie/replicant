express = require('express')
{signup} = require('./lib/replicant')
{getUserIdFromSession} = require('./lib/replicant')

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

app.post '/signup', (req, res) ->
  cookie = req.headers.cookie
  getUserIdFromSession {cookie}, (err, {userId}) ->
    if err then throw new Forbidden('User must be logged in')
    else
      signup {userId}, (e,r) ->
        if e then throw new InternalServerError(e.toString())
        else res.end(r)

app.post '/swapEvent', (req, res) ->
  #res.send app._controllers.swapEvent()

# fire that baby up
app.listen(3000)
