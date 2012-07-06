express = require('express')
{createUser} = require('./lib/replicant')
{getUserIdFromSession} = require('./lib/replicant')

app = express.createServer()

app.post '/user', (req, res) ->
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err then res.send('User must be logged in', 403)
    else
      userId = r.userId
      createUser {userId}, (e,r) ->
        if e then res.send("Internal Server Error: #{e}", 500)
        else res.end(JSON.stringify(r))

app.post '/swapEvent', (req, res) ->
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err then res.send('User must be logged in', 403)
    else
      userId = r.userId
      create {userId}, (e,r) ->
        if e then res.send("Internal Server Error: #{e}", 500)
        else res.end(JSON.stringify(r))


#app.put '/replicate', (req, res) -> # should be put, looking at you IE...
###
app.post '/replicate', (req, res) ->
  getUserIdFromSession headers: req.headers, (err, r) ->
    if err then res.send('User must be logged in', 403)
    else
      userId = r.userId
      signup {userId}, (e,r) ->
        if e then res.send("Internal Server Error: #{e}", 500)
        else res.end(JSON.stringify(r))
###

# fire that baby up
app.listen(3000)

module.exports = app
