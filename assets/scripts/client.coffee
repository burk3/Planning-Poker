socket = io.connect()
socket.on 'connect', ->
  console.log "connected"

socket.on 'alert', (alert) ->
  console.log "Alert received #{alert}"

socket.on "message", (msg) ->
  console.log "Got a message #{msg.message} from user #{msg.name}"

socket.on "register", (user) ->
  console.log 'register: ' + user
  $('.people').append tpl.name({name: user.name, checked: false, id: user.id})

socket.on "vote", (user) ->
  $('.icon', $('.name-'+user.id)).addClass('check')

socket.on "allUsers", (users) ->
  console.log users
  for user in users 
    console.log user
    $('.people').append tpl.name({name: user.name, checked: user.vote == true, id: user.id})

socket.on 'disconnect', ->
  console.log "disconnected"
	
window.sendMessage = (message) ->
  console.log "sending message #{message}"
  socket.emit 'message', message

window.register = (message) ->
  socket.emit 'register', message

window.vote = (message) ->
  socket.emit 'vote', message
  
#Sammy.js configuration stuff - it's like a dispatcher/router thingamabobber
app = $.sammy "#main", () ->
  @get "#!/", (context) =>
    console.log "Got main site with context #{context}"
    name = $.cookie("name")
    if not name
      app.setLocation "#!/login"
    else
      register(name)
      context.app.swap tpl.cards()
  @get "#!/login", (context) =>
    console.log "Login screen"
    context.app.swap tpl.login()
    $("#login").bind "submit", (event) ->
      nm = $("#login input").val()
      $.cookie("name", nm)
      app.setLocation "#!/"
      false
$ ->
  app.run "#!/"