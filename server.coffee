express = require('express')
s = express.createServer()
s.listen 4444, () ->
  s.close()
