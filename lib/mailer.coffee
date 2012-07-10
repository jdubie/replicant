debug = require('debug')('replicant:lib:mailer')
path = require('path')
_ = require('underscore')
config = require('../config')


#mailOptions =
#  from: 'jdubie <jdubie@stanford.edu>'
#  #to: 'Jack <jack@thelifeswap.com>'
#  to: 'Jack <jack.dubie@gmail.com>'
#  subject: 'New Swap Created'
#  # text:
#  # html:

module.exports.Mailer = class Mailer

  ###
    Creates a mailer with a default set of email headers

    @param templateName {string}
    @param headers {object.<string, string>} email headers
    @param data {object.<string, {string|array}> data for template
  ###
  constructor: ({@headers, @data, @templateName}) ->
    #@template = fs.readFileSync(path.join(__dirname, @templateName))

  send: ({headers, data}) ->
    _.defaults(headers, @headers)
    #html = @_getHtml(data)
    options =
      text: 'hello, world'
    _.defaults(options, headers)

    config.smtp.sendMail options, () ->

  _getHtml: (data) ->
    _.defaults(data, @data)
    return Mustache.to_html(@template, data)

