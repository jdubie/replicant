debug = require('debug')('replicant:config')
nodemailer = require('nodemailer')
url = require('url')

# Db connection
if process.env.PROD
  protocol = 'http:'
  auth = "replicant:#{process.env.REPLICANT_PWD}"
  hostname = 'localhost'
  port = 5984
else
  protocol = 'http:'
  auth = 'replicant:replicant'
  hostname = 'localhost'
  port = 5985

module.exports.dbUrl = url.format({protocol,hostname,port})
module.exports.nano = require('nano')(url.format({protocol,hostname,port,auth}))


# Admins
if process.env.PROD
  ADMINS = ['shawntuteja', 'jdubie', 'mike', 'bastiaan', 'aotimme']
else
  ADMINS = ['tester']

module.exports.ADMINS = ADMINS


# SMTP transport
testEmailPort = 8000

if process.env.PROD
  smtpOptions =
    service: 'Gmail'
    auth:
      user: process.env.GMAIL_USER
      pass: process.env.GMAIL_PWD
else
  smtpOptions = # testing
    host: 'localhost'
    port: testEmailPort

module.exports.smtp = nodemailer.createTransport('SMTP', smtpOptions)
module.exports.testEmailPort = testEmailPort
