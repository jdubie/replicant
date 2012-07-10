user = 'hedwig'
if process.env.PROD then pwd = process.env.HEDWIG_PWD
else pwd = 'hedwig'
credentials = {user,pwd}
nano = require('nano')("http://#{credentials.user}:#{credentials.pwd}@localhost:5984")
db = nano.db.use('lifeswap')

describe 'adminNotifications', () ->

