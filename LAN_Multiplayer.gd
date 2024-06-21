extends Node2D
# game_script///
# read only///
# change carefully///

signal found_server(ip,port,roominfo)
signal update_server(ip,port,roominfo)
signal join_game(ip)

var room_name:String
var roominfo = {"room_name":"room_name","room_ip":"room_ip","player_count":0}
var max_players = 12
var server:ENetMultiplayerPeer
var client:ENetMultiplayerPeer
var broadcaster: PacketPeerUDP
var listener: PacketPeerUDP
#adresses/ports
var local_adress:String
var server_ip:String
var client_ip: String
var broadcast_adress = "255.255.255.255"
var server_port = 55555
var broadcast_port = 55556
var listen_port = 55557
#roomdata for client
var Name:String
var Ip:String
var connection = false

func decide_room_name():
	if $"looby/main/ColorRect/manual/room_name".text == "":
		room_name = Global.user
	else:
		room_name = $"looby/main/ColorRect/manual/room_name".text

func get_local_adress():
	if OS.get_name() == "Windows":
		local_adress = IP.get_local_addresses()[3]
	elif OS.get_name() == "Android":
		local_adress = IP.get_local_addresses()[0]
	else:
		local_adress = IP.get_local_addresses()[3]
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168") and not ip.ends_with(".1"):
			local_adress = ip

func hostgame():
	decide_room_name()
	server = ENetMultiplayerPeer.new()
	var error = server.create_server(server_port,max_players)
	if error != OK:
		print("cannot host: ", error)
	else:
		multiplayer.set_multiplayer_peer(server)
		print(room_name," created server with server port: ",server_port)
#	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	$looby.hide()
	$room.set_visible(true)
	setup_broadcaster(room_name+"'s game")
	send_player_information(Global.user, multiplayer.get_unique_id())

func joinroom(ip):
	client = ENetMultiplayerPeer.new()
	var error = client.create_client(ip,server_port)
#	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	if error != OK:
		print("cannot join: ", error)
	else:
		multiplayer.set_multiplayer_peer(client)
		print(room_name," joined server having ip: ",client_ip)
	$looby.hide()
	$room.set_visible(true)

@rpc("any_peer")
func send_player_information(name, id):
	if !Global.players.has(id):
		Global.players[id] = {
			"name": name,
			"id": id,
			"xp": 0
		}
	if multiplayer.is_server():
		for i in Global.players:
			send_player_information.rpc(Global.players[i].name,i)

func _on_broadcast_timer_timeout():
	print("broadcasting game!!")
	roominfo.player_count = Global.players.size() 
	var data = JSON.stringify(roominfo)
	var packet = data.to_ascii_buffer()
	broadcaster.put_packet(packet)

func setup_broadcaster(room_name):
	roominfo.room_name = room_name
	roominfo.player_count = Global.players.size()
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address(broadcast_adress, listen_port)
	var ok = broadcaster.bind(broadcast_port)
	if ok == OK:
		print("bound to broadcast port: ", str(broadcast_port), " successful!!")
	else:
		print("failed to bind broadcast port!")
	$room/broadcast_timer.start()

func setup_listener():
	listener = PacketPeerUDP.new()
	var ok = listener.bind(listen_port)
	if ok == OK:
		$listening.text = "bound to listne port: true"
		print("bound to listner port: ", str(listen_port), " successful!!")
	else:
		$listening.text = "bound to listne port: false"
		print("failed to bind listner port!")

func join_by_ip(name,ip):
	Name = name
	Ip = ip
	join_game.emit(ip)

func setup_room():
	$room/Control/players/general/num_players.text = str("Players: ",Global.players.size())
	if multiplayer.is_server():
		$room/Control/room_name.text = str(room_name,"'s room")
		$room/Control/room_ip.text = str("Room IP: ",local_adress)
	else:
		if connection == true:
			$room/Control/room_name.text = Name
			$room/Control/room_ip.text = str("Room IP: ",Ip)
			$room/Control/players/general/num_players.text = str("Players: ",Global.players.size())


func cleanup():
	Global.players.clear()
	if server!=null:
		server = null
	if client!=null:
		client = null
	listener.close()
	$room/broadcast_timer.stop()
	if broadcaster != null:
		broadcaster.close()

func peer_connected(id):
	print("player connected: ",id)

func peer_disconnected(id):
	print("player disconnected: ",id)
	
func connected_to_server():
	connection = true
	print("connected to server!!")
	send_player_information.rpc_id(1, Global.user, multiplayer.get_unique_id())
	
func connection_failed():
	print("coudnt connect!")

func server_disconnected():
	connection = false

func _ready():
	$room.hide()
	get_local_adress()
	setup_listener()
	$looby/main/username.text = str(" Username: ",Global.user)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_disconnected)
	join_game.connect(joinroom)

func _on_host_pressed():
	hostgame()
	
func _on_join_pressed():
	joinroom(client_ip)
	
func _on_exit_button_down():
	get_tree().change_scene_to_file("res://scens/ui/menu.tscn")

func _on_room_exit_button_down():
	get_tree().change_scene_to_file("res://scens/ui/menu.tscn")

func _process(delta):
	client_ip = $looby/main/ColorRect/manual/client_ip.text
	if client_ip == "":
		$looby/main/ColorRect/manual/join.set_disabled(true)
	else:
		$looby/main/ColorRect/manual/join.set_disabled(false)
	setup_room()
	if listener.get_available_packet_count() > 0:
		var Server_ip = listener.get_packet_ip()
		var Server_port = listener.get_packet_port()
		var Byts = listener.get_packet()
		var Data = Byts.get_string_from_ascii()
		var Roominfo = JSON.parse_string(Data)
		print("server ip: ", Server_ip," server port: ",Server_port," room info: ",Roominfo)
		for i in $looby/main/server_browser/server_list.get_children():
			if i.name == Roominfo.room_name:
				update_server.emit(Server_ip,Server_port,Roominfo)
				i.get_node("ip").text = Server_ip
				i.get_node("playercount").text = str(Roominfo.player_count)
				return
		var currentinfo = preload("res://scens/multiplayer/server_info.scn").instantiate()
		currentinfo.name = Roominfo.room_name
		currentinfo.get_node("name").text = Roominfo.room_name
		currentinfo.get_node("ip").text = Server_ip
		currentinfo.get_node("playercount").text = str(Roominfo.player_count)
		$looby/main/server_browser/server_list.add_child(currentinfo)
		currentinfo.join_game.connect(join_by_ip)
		found_server.emit(server_ip,server_port,Roominfo)

func _exit_tree():
	cleanup()
