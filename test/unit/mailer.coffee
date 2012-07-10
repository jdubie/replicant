should = require('should')
emailListen = require('email-listener')
{Mailer} = require('../../lib/mailer')
config  = require('../../config')

describe 'class Mailer', () ->

  to = 'testTo'
  from = 'testFrom'
  text = 'testText'
  subject = 'testSubject'

  before () ->
    emailListen.start(config.emailPort)

  after () ->
    emailListen.stop()

  it 'send simple email', (done) ->
    emailListen.on 'msg', (recipient, rawbody, parsed) ->
      #console.error recipient, rawbody, parsed
      parsed.should.have.property('subject', subject)
      done()
    headers = {to,from,text,subject}
    m = new Mailer({headers})
    m.send({})
