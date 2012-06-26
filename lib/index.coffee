debug = require('debug')('lifeswap:hedwig:index')
nodemailer = require('nodemailer')

debug 'creating database connection'
user = 'hedwig'
if process.env.PROD
  pwd = process.env.HEDWIG_PWD
else
  pwd = 'hedwig'
credentials = {user,pwd}
nano = require('nano')("http://#{credentials.user}:#{credentials.pwd}@localhost:5984")
db = nano.db.use('lifeswap')
debug 'connected to database'

debug 'creating smtp server connection'
smtpTransport = nodemailer.createTransport "SMTP",
  service: 'Gmail'
  auth:
    user: process.env.GMAIL_USER
    pass: process.env.GMAIL_PWD
debug 'connected to smtp server'

mailOptions =
  from: "Notifications <notifications@thelifeswap.com>"
  to: "Jack <jack@thelifeswap.com>"
  subject: "New Swap Created"
  # text:
  # html:


feed = db.follow(since: 'now')
feed.on 'change', (change) ->
  debug change.id

  # set email info
  mailOptions.text = "Approve/Deny new Swap here: http://lifeswap.co/admin/swaps/#{change.id}"

  debug "sending email with for swap with id: #{change.id}"
  smtpTransport.sendMail mailOptions, (err,res) ->
    if err
      debug "ERROR: #{JSON.stringify(err)}"
    else
      debug "mail successfully sent: #{JSON.stringify(res)}"


feed.follow()
debug 'starting hedwig'

# shut down SMTP connection
process.on 'SIGINT', () ->
  debug 'shutting down SMTP connection'
  smtpTransport.close()
  process.exit()
