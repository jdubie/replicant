module.exports =
  # public
  user          : require './user'
  swap          : require './swap'
  review        : require './review'
  like          : require './like'
  request       : require './request'
  entity        : require './entity'
  shortlink     : require './shortlink'
  application   : require './application'
  company_request: require './company_request'
  endorsement   : require './endorsement'
  # private
  email_address : require './email_address'
  phone_number  : require './phone_number'
  card          : require './card'
  payment       : require './payment'
  refer_email   : require './refer_email'
  event         : require './event'
  message       : require './message'

  ## others (but not necessary b/c only written by server):
  # read
  # notification
