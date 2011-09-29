#Module Dependencies
express = require 'express'
app = module.exports = express.createServer()
io = require('socket.io').listen app
redis = require('redis')
client = redis.createClient()

#Configuration
app.set 'views', (__dirname + '/views')
app.set 'view engine', 'jade'
app.use express.bodyParser()
app.use express.methodOverride()
app.use app.router
app.use require('connect-assets')()
app.use require('jade-client-connect')("#{__dirname}/views")
app.use express.static(__dirname + '/public')
  
app.configure 'development', ->
  app.use express.errorHandler {dumpExceptions: true, showStack: true}

app.configure 'production', ->
  app.use express.errorHandler()

#Routes to respond to
app.get '/', (req, res) ->
  res.render('index', {title: 'Planning Poker' })
  
app.get '/results', (req, res) ->
  res.contentType 'application/json'
  findUsers (users) ->
    res.send JSON.stringify calculateResults(users)

findUsers = (callback) ->
  client.smembers "users", (err, users) ->
    allUsers = []
    index = 0
    for user in users 
      client.hgetall user, (err, u) ->
        index++
        allUsers.push u
        if index == (users.length)
          callback?(allUsers)
  return null
   
resetUsers = (callback) ->
  client.smembers "users", (err, users) ->
    index = 0
    for user in users 
      client.hmset "#{user}", "name", name, "vote", 0, (err, result) ->
        index++
        if index == (users.length)
          callback?(allUsers)   
          
findUser = (id, callback) ->
  client.hgetall "user:#{id}", (err, result) ->
    callback(result)
  
areUsersFinished = (users) ->
  for user in users
    if user.vote <= 0
      return false
  return true

calculateResults = (users) ->  
  votes = []
  for user in users when user.vote >0 
    vote = (v for v in votes when user.vote == v.vote)
    if(vote.length > 0)
      vote[0].count+=1
      vote[0].users.push user
    else
      votes.push {vote: user.vote, count: 1, users: [user]}
  return votes  
  
io.sockets.on 'connection', (socket) ->
  socket.on 'message', (msg) ->
    socket.get 'name', (err, name) ->
      if !err
        socket.broadcast.emit "message", { name: "#{name}", message: "#{msg}"}
      else
        socket.emit "alert", "You are not registered."
        
  socket.on 'join', (id) ->
    findUsers (users) ->
      findUser id, (user) ->
        socket.emit "allUsers", users
        socket.emit "registered", id
        socket.broadcast.emit "register", user 
    
  socket.on 'register', (name) ->
    client.incr "id", (err, id) ->
      socket.set 'id', id, ->
        user = {id: id, name: name, vote: 0}
        client.sadd "users", "user:#{id}", (err, addResult) ->
          client.hmset "user:#{id}", "name", name, "vote", 0, (err, result) ->
            findUsers (users) ->
              socket.emit "allUsers", users
              socket.emit "registered", id
              socket.broadcast.emit "register", user
      
  socket.on 'vote', (vote) ->
    socket.get 'id', (err, id) ->
      if !err   
        client.hmset "user:#{id}", "vote", vote, (err, result) ->
          findUser id, (user) ->
            if user
              socket.broadcast.emit "vote", user
              socket.emit "vote", user
              findUsers (users) ->
                console.log "all users: #{users}"
                console.log "user: #{user.name}" for user in users
                if(areUsersFinished(users))
                  console.log "users are finished"
                  socket.emit "results"
                  socket.broadcast.emit "results"
      else
        socket.emit "alert", "You are not registered"
        
  socket.on 'reset', (reset) ->
    resetUsers (users) ->
      socket.broadcast.emit "reset", []
      socket.emit "reset", []
    
  socket.on 'disconnect', -> 
    socket.get 'id', (err,id) ->
      findUser id, (user) ->
        socket.broadcast.emit "remove", [user]
    
app.listen process.env.PORT || 3000
console.log "Server listening on port %d in %s mode", app.address().port, app.settings.env
