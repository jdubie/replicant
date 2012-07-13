should = require('should')
ms = require('smtp-tester')
{Mailer} = require('../../lib/mailer')
config  = require('../../config')

describe 'class Mailer', () ->

  mailserver = null

  to = 'test@thelifeswap.com'
  from = 'test@thelifeswap.com'
  subject = 'testSubject'

  before () ->
    mailserver = ms.init(config.testEmailPort)

  after () ->
    mailserver.stop()

  it 'should send empty email', (done) ->
    to = 'simple@thelifeswap.com'
    headers = {to,from,subject}
    mailer = new Mailer({headers})
    mailer.send({})

    handler = (addr, id, email) ->
      mailserver.unbind(handler)
      done()
    mailserver.bind(to, handler)

  it 'should send an email with an html template', (done) ->
    to = 'htmlTemplate@thelifeswap.com'
    data = src: 'http://placehold.it/10x10'
    headers = {to,from,subject}

    mailer = new Mailer({headers, templateName: 'testTemplate'})
    mailer.send({data})

    handler = (addr, id, email) ->
      email.should.have.property('body', '<html><img src="http://placehold.it/10x10"></img></html>')
      mailserver.unbind(handler)
      done()
    mailserver.bind(to, handler)
