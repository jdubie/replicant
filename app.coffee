express = require('express')

config  = require('config')
h       = require('lib/helpers')
routes  = require('lib/routes')

app = express()
app.use(express.static(__dirname + '/public'))
app.use(express.cookieParser('test_secret'))
if process.env.ENV is 'PROD'
  RedisStore = require('connect-redis')(express)
  redisOpts =
    port: process.env.REDIS_PORT
    pass: process.env.REDIS_PASSWORD
  app.use(express.session(store: new RedisStore(redisOpts)))
else
  app.use(express.session())

## user_ctx
# Login
app.post('/user_ctx'  , express.bodyParser(), routes.login)
# Logout
app.delete('/user_ctx', routes.logout)
# Get user session
app.get('/user_ctx'   , routes.session)
# Change password
app.put('/user_ctx'   , express.bodyParser(), routes.password)

## users
# create a user (and sign up)
app.get('/users', routes.allPublic)
app.get('/users/:id', routes.onePublic)
app.post('/users', express.bodyParser(), routes.createUser)
app.put('/users/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/users/:id', h.getUserCtx, routes.deleteUser)

## swaps
app.get('/swaps', routes.allPublic)
app.get('/swaps/:id', routes.onePublic)
app.post('/swaps', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/swaps/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/swaps/:id' , routes.forbidden)

## reviews
app.get('/reviews', routes.allPublic)
app.get('/reviews/:id', routes.onePublic)
app.post('/reviews', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/reviews/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/reviews/:id', routes.forbidden)

## likes
app.get('/likes', routes.allPublic)
app.get('/likes/:id', routes.onePublic)
app.post('/likes', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/likes/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/likes/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.deletePublic)

## endorsements
app.get '/endorsements',          # GET /endorsements
  routes.allPublic
app.get '/endorsements/:id',      # GET /endorsements/:id
  routes.onePublic
app.post '/endorsements',         # POST /endorsements
  express.bodyParser(),
  h.getUserCtx,
  h.validate,
  routes.postPublic
app.put '/endorsements/:id',      # PUT /endorsements/:id
  express.bodyParser(),
  h.getUserCtx,
  h.validate,
  routes.putPublic
app.delete '/endorsements/:id',   # DELETE /endorsements/:id
  express.bodyParser(),
  h.getUserCtx,
  h.validate,
  routes.deletePublic

## requests
app.get('/requests', routes.allPublic)
app.get('/requests/:id', routes.onePublic)
app.post('/requests', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/requests/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/requests/:id', routes.forbidden)

## company_requests
app.get '/company_requests',          # GET /company_requests
  routes.allPublic
app.get '/company_requests/:id',      # GET /company_requests/:id
  routes.onePublic
app.post '/company_requests',         # POST /company_requests
  express.bodyParser(),
  h.getUserCtx,
  h.validate,
  routes.postPublic
app.put '/company_requests/:id',      # PUT /company_requests/:id
  express.bodyParser(),
  h.getUserCtx,
  h.validate,
  routes.putPublic
app.delete '/company_requests/:id',   # DELETE /company_requests/:id
  routes.forbidden

## entities
app.get('/entities' , routes.allPublic)
app.get('/entities/:id', routes.onePublic)
app.post('/entities', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/entities/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/entities/:id', routes.forbidden)

## events
app.get('/events', h.getUserCtx, routes.getEvents)
app.get('/events/:id', h.getUserCtx, routes.getEvent)
app.post('/events', express.bodyParser(), h.getUserCtx, h.validate, routes.createEvent)
app.put('/events/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putEvent)
app.delete('/events/:id', routes.forbidden)

## cards
app.get('/cards', h.getUserCtx, routes.allPrivate)
app.get('/cards/:id', h.getUserCtx, routes.onePrivate)
app.post('/cards', express.bodyParser(), h.getUserCtx, h.validate, routes.postPrivate)
app.put('/cards/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPrivate)
app.delete('/cards/:id', h.getUserCtx, h.validate, routes.deletePrivate)

## payments
app.get('/payments', h.getUserCtx, routes.allPrivate)
app.get('/payments/:id', h.getUserCtx, routes.onePrivate)
app.post('/payments', express.bodyParser(), h.getUserCtx, h.validate, routes.postPrivate)
app.put('/payments/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPrivate)
app.delete('/payments/:id', routes.forbidden)

## email_addresses
app.get('/email_addresses', h.getUserCtx, routes.allPrivate)
app.get('/email_addresses/:id', h.getUserCtx, routes.onePrivate)
app.post('/email_addresses', express.bodyParser(), h.getUserCtx, h.validate, routes.postPrivate)
app.put('/email_addresses/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPrivate)
app.delete('/email_addresses/:id', h.getUserCtx, h.validate, routes.deletePrivate)

## phone_numbers
app.get('/phone_numbers', h.getUserCtx, routes.allPrivate)
app.get('/phone_numbers/:id', h.getUserCtx, routes.onePrivate)
app.post('/phone_numbers', express.bodyParser(), h.getUserCtx, h.validate, routes.postPrivate)
app.put('/phone_numbers/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPrivate)
app.delete('/phone_numbers/:id', h.getUserCtx, h.validate, routes.deletePrivate)

## messages
app.get('/messages', h.getUserCtx, routes.getMessages)
app.get('/messages/:id', h.getUserCtx, routes.getMessage)
app.post('/messages', express.bodyParser(), h.getUserCtx, h.validate, routes.sendMessage)
app.put('/messages/:id', express.bodyParser(), h.getUserCtx, routes.changeReadStatus)
app.delete('/messages/:id', routes.forbidden)

## refer_emails
app.post('/refer_emails', express.bodyParser(), h.getUserCtx, h.validate, routes.postPrivate)
app.put('/refer_emails/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPrivate)

## notifications
app.get('/notifications', h.getUserCtx, routes.getMessages)
app.get('/notifications/:id', h.getUserCtx, routes.getMessage)
app.put('/notifications/:id', express.bodyParser(), h.getUserCtx, routes.changeReadStatus)

## shortlinks
app.get('/shortlinks', routes.allPublic)
app.get('/shortlinks/:id', routes.onePublic)
app.post('/shortlinks', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/shortlinks/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/shortlinks/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.deletePublic)


## applications
app.get('/applications', routes.allPublic)
app.get('/applications/:id', routes.onePublic)
app.post('/applications', express.bodyParser(), h.getUserCtx, h.validate, routes.postPublic)
app.put('/applications/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.putPublic)
app.delete('/applications/:id', express.bodyParser(), h.getUserCtx, h.validate, routes.deletePublic)

## other endpoints

## zipcodes
app.get('/zipcodes/:id', routes.zipcode)

## recruiting
app.get '/they-took-our-jobs', (req, res) ->
  res.end('am9icyticm9ncmFtbWVyQHRoZWxpZmVzd2FwLmNvbQ')

## catch-all for shortlinks
app.get('*', routes.shortlink)

# fire up HTTP server
app.listen(config.port)

module.exports = app
