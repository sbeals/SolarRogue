extends "res://scripts/GUI/GUILayoutBase.gd"

onready var _my_ship_list : MyItemList = get_node("HBoxContainer/MyShip/MyItemList")
onready var _other_ship_list : MyItemList = get_node("HBoxContainer/OtherShip/MyItemList")
var _obj : Attributes = null

var _buy_btn : ButtonBase = null
var _sale_btn : ButtonBase = null
var _desc_btn : ButtonBase = null
var _close_btn : ButtonBase = null
var _cancel_btn : ButtonBase = null
var _info_card : Control = null
var _icon : TextureRect = null
var _item_name : RichTextLabel = null
var _item_price : RichTextLabel = null
var _energy_status : RichTextLabel = null

var _transfered_cargo : Dictionary = {}
var _transfered_ship : Attributes = null
var _transfered_to : Attributes = null

var _lobj : Attributes = null
var _robj : Attributes = null

func _ready():
	_buy_btn = get_node("HBoxContainer/Control/base/Info/Control/Buy")
	_sale_btn = get_node("HBoxContainer/Control/base/Info/Control/Sell")
	_desc_btn = get_node("HBoxContainer/Control/base/IconContainer/Desc")
	_info_card = get_node("HBoxContainer/Control/base")
	_icon = get_node("HBoxContainer/Control/base/IconContainer/Icon")
	_item_name = get_node("HBoxContainer/Control/base/Info/ItemName")
	_item_price = get_node("HBoxContainer/Control/base/Info/Price")
	_energy_status = get_node("HBoxContainer/Control/Control/EnergyStatus")
	
	_sale_btn.connect("pressed", self, "Sale_Callback")
	_buy_btn.connect("pressed", self, "Buy_Callback")
	_desc_btn.connect("pressed", self, "Desc_Callback")
	
	_close_btn = get_node("HBoxContainer/Control/Control/Close")
	_close_btn.connect("pressed", self, "Ok_Callback")
	_cancel_btn = get_node("HBoxContainer/Control/Control/Cancel")
	_cancel_btn.connect("pressed", self, "Cancel_Callback")
	
	_my_ship_list.connect("OnSelectionChanged", self, "OnSelectionChanged_Callback")
	_my_ship_list.connect("OnDragDropCompleted", self, "OnDragDropCompleted_Callback")
	_other_ship_list.connect("OnSelectionChanged", self, "OnSelectionChanged_Callback")
	_other_ship_list.connect("OnDragDropCompleted", self, "OnDragDropCompleted_Callback")

func HowManyDiag_Callback(num):
	_transfered_cargo.count = num
	BehaviorEvents.emit_signal("OnRemoveItem", _transfered_ship, _transfered_cargo.src, _transfered_cargo.count)
	for i in range(_transfered_cargo.count):
		BehaviorEvents.emit_signal("OnAddItem", _transfered_to, _transfered_cargo.src)
	
	BehaviorEvents.emit_signal("OnMoveCargo", _transfered_ship, _transfered_to)
	# Update inventory lists
	ReInit()


func Cancel_Callback():
	ReInit()
	
func Ok_Callback():
	BehaviorEvents.emit_signal("OnPopGUI")
	_close_btn.Disabled = true
	
	# reset content or we might end up with dangling references
	_my_ship_list.Content = []
	_other_ship_list.Content = []
	
	
func Sale_Callback():
	var selected_item = null
	var selected_ship = null
	
	var cur_sel = _get_selected_item()
	selected_item = cur_sel[0]
	selected_ship = cur_sel[1]
	
	var price : int = GetPrice(selected_item, true)
	if "key" in selected_item and "idx" in selected_item:
		BehaviorEvents.emit_signal("OnRemoveMount", _lobj, selected_item.key, selected_item.idx)
	BehaviorEvents.emit_signal("OnRemoveItem", _lobj, selected_item.src)
	BehaviorEvents.emit_signal("OnAddItem", _robj, selected_item.src)
	BehaviorEvents.emit_signal("OnUseEnergy", _lobj, -price)
	BehaviorEvents.emit_signal("OnLogLine", "Sold %s for %d energy", [Globals.mytr(selected_item["name_id"]), price])
	
	ReInit()
	
func Buy_Callback():
	var selected_item = null
	var selected_ship = null
	
	var cur_sel = _get_selected_item()
	selected_item = cur_sel[0]
	selected_ship = cur_sel[1]
	
	var price : int = GetPrice(selected_item, false)
	#if "key" in selected_item and "idx" in selected_item:
	#	BehaviorEvents.emit_signal("OnRemoveMount", _lobj, selected_item.key, selected_item.idx)
	BehaviorEvents.emit_signal("OnRemoveItem", _robj, selected_item.src)
	BehaviorEvents.emit_signal("OnAddItem", _lobj, selected_item.src)
	BehaviorEvents.emit_signal("OnUseEnergy", _lobj, price)
	BehaviorEvents.emit_signal("OnLogLine", "Bought %s for %d energy", [Globals.mytr(selected_item["name_id"]), price])
	
	ReInit()
	
func Desc_Callback():
	var selected_item = null
	var selected_ship = null
	var to_ship = null
	var from_list = null
	var to_list = null
	
	var left = _my_ship_list.Content
	
	var scanner_level := 0
	var scanner_data = Globals.LevelLoaderRef.LoadJSONArray(_lobj.get_attrib("mounts.scanner"))
	if scanner_data != null and scanner_data.size() > 0:
		scanner_level = Globals.get_data(scanner_data[0], "scanning.level")
	
	var right = _other_ship_list.Content
	
	for item in left:
		if item.selected == true:
			selected_item = item
			selected_ship = _lobj
			to_ship = _robj
			from_list = _my_ship_list
			to_list = _other_ship_list
			break
	
	#TODO: That looks weird in this method?
	if selected_item == null:
		for item in right:
			if item.selected == true and "src" in item and item.src != "":
				selected_item = item
				selected_ship = _robj
				to_ship = _lobj
				from_list = _other_ship_list
				to_list = _my_ship_list
				break
	
	if selected_item == null:
		return
	
	var data = null
	if "src" in selected_item and selected_item.src != null and selected_item.src != "":
		data = Globals.LevelLoaderRef.LoadJSON(selected_item.src)
	
	BehaviorEvents.emit_signal("OnPushGUI", "Description", {"json":data, "scanner_level":scanner_level})
	

func Init(init_param):
	var obj1 = init_param["object1"]
	var obj2 = init_param["object2"]
	
	_lobj = obj1
	_robj = obj2
	
	ReInit()
	
func ReInit():
	_close_btn.Disabled = false
	_lobj.init_cargo()
	_lobj.init_mounts()
	_robj.init_cargo()
	_robj.init_mounts()
	
	get_node("HBoxContainer/OtherShip").title = Globals.mytr(_robj.get_attrib("name_id"))
	get_node("HBoxContainer/MyShip").title = Globals.mytr(_lobj.get_attrib("player_name", _lobj.get_attrib("name_id")))
	
	var cargo1 = _lobj.get_attrib("cargo.content")
	var mounts1 = _lobj.get_attrib("mounts")
	var cargo2 = _robj.get_attrib("cargo.content")
	var mounts2 = _robj.get_attrib("mounts")
	
	#_normal_btns.visible = true
	#_question_btns.visible = false
	
	GenerateContent(_my_ship_list, mounts1, cargo1, false)
	GenerateContent(_other_ship_list, mounts2, cargo2, true)
	
	var current_load = _lobj.get_attrib("cargo.volume_used")
	var cargo_space = _lobj.get_attrib("cargo.capacity")
	
	var cargo_color = "lime"
	var cargo_str = ""
	if current_load > cargo_space:
		cargo_color="red"
	elif current_load > cargo_space * 0.9:
		cargo_color="yellow"
		
	get_node("HBoxContainer/MyShip/CargoLabel").bbcode_text = "[right]([color=%s]%.f / %.f[/color])[/right]" % [cargo_color, current_load, cargo_space]
	
	#current_load = _robj.get_attrib("cargo.volume_used")
	#cargo_space = _robj.get_attrib("cargo.capacity")
	
	#cargo_color = "lime"
	#cargo_str = ""
	#if current_load > cargo_space:
	#	cargo_color="red"
	#elif current_load > cargo_space * 0.9:
	#	cargo_color="yellow"
		
	#get_node("HBoxContainer/OtherShip/CargoLabel").bbcode_text = "[right]([color=%s]%.f / %.f[/color])[/right]" % [cargo_color, current_load, cargo_space]
	
	# Init all the buttons to Enable/Disabled state
	OnSelectionChanged_Callback()
	
func sort_categories(var a, var b):
	return a > b
	
func GenerateContent(list_node, mounts, cargo, skip_mount : bool):
	var mount_content := []
	if skip_mount == false:
		var keys = mounts.keys()
		keys.sort_custom(self, "sort_categories")
		for key in keys:
			mount_content.push_back({"key":key, "name_id":key, "equipped":false, "header":true})
			var items : Array = mounts[key]
			var index = 0
			for src in items:
				if src != null and src != "":
					var item = Globals.LevelLoaderRef.LoadJSON(src)
					mount_content.push_back({"src":mounts[key][index], "key":key, "idx":index, "name_id":item.name_id, "equipped":false, "header":false, "icon":item.icon})
				else:
					mount_content.push_back({"src":"", "key":key, "idx":index, "name_id":"Empty", "equipped":false, "header":false})
				index += 1
		mount_content.push_back({"src":"", "name_id":"Cargo Contents", "equipped":false, "header":true})
	else:
		mount_content.push_back({"src":"", "name_id":"For sale, good deals!", "equipped":false, "header":true})
	for row in cargo:
		var data = Globals.LevelLoaderRef.LoadJSON(row.src)
		var counting = ""
		if row.count > 1:
			counting = str(row.count) + "x "
		if typeof(data.icon) == TYPE_ARRAY:
			data.icon = data.icon[0]
		mount_content.push_back({"src":row.src, "count":row.count, "display_name_id": counting + Globals.mytr(data.name_id), "name_id": counting + Globals.mytr(data.name_id), "equipped":false, "header":false, "icon":data.icon})

	list_node.Content = mount_content

func OnSelectionChanged_Callback():
	UpdateVisibility()
	#if _normal_btns.visible == true:
	#	UpdateNormalVisibility()
	#else:
	#	DoMounting()

func UpdateVisibility():
	var selected_item = null
	var selected_ship = null
	
	var cur_sel = _get_selected_item()
	selected_item = cur_sel[0]
	selected_ship = cur_sel[1]
	
	if selected_item == null or selected_item.src.empty() == true:
		_info_card.visible = false
		return
	
	var data = null
	if "src" in selected_item and selected_item.src != null and selected_item.src != "":
		_info_card.visible = true
		data = Globals.LevelLoaderRef.LoadJSON(selected_item.src)
		
		var selling = selected_ship == _lobj
		_buy_btn.visible = not selling
		_sale_btn.visible = selling
		
		_cancel_btn.visible = false
		
		if "texture_cache" in selected_item:
			_icon.texture = selected_item.texture_cache
			
		var unit_price : int = GetPrice(data, selling)
		if selling == true:
			_info_card.title = "Selling"
			_item_price.bbcode_text = "[center][color=lime]%d Energy[/color][/center]" % unit_price
		else:
			_info_card.title = "Buying"
			_item_price.bbcode_text = "[center][color=red]%d Energy[/color][/center]" % unit_price
		_item_name.bbcode_text = "[center]%s[/center]" % Globals.mytr(selected_item["name_id"])
		
		var cur_energy = _lobj.get_attrib("converter.stored_energy")
		var energy_color = "lime"
		if cur_energy < 5001:
			energy_color = "yellow"
		if cur_energy < 1001:
			energy_color = "red"
			
		var energy_str : String = "[center]Available Energy.. [color=%s]%.f[/color][/center]" % [energy_color, cur_energy]
		_energy_status.bbcode_text = energy_str
		
func GetPrice(data : Dictionary, selling : bool) -> int:
	var clean_name : String = Globals.clean_path(data.src)
	var known_prices : Dictionary = _lobj.get_attrib("prices", {})
	var price_data := {}
	if known_prices.has(clean_name):
		price_data = known_prices[clean_name]
	else:
		var sale_range : Array = Globals.get_data(data, "recyclable.player_sale_range", [0,0])
		var buy_range : Array = Globals.get_data(data, "recyclable.player_buy_range", [0,0])
		var sale_real : int = _rand_round(sale_range[0], sale_range[1])
		var buy_real : int = _rand_round(buy_range[0], buy_range[1])
		price_data = {"sale":sale_real, "buy":buy_real}
		known_prices[clean_name] = price_data
		_lobj.set_attrib("prices", known_prices)
		
	if selling == true:
		return price_data["sale"]
	else:
		return price_data["buy"]

func _rand_round(min_val : int, max_val : int) -> int:
	var res = MersenneTwister.rand((max_val - min_val)) + min_val
	var step := 5.0
	var rounded : int = (int((res / step + 0.5))) * step;
	return rounded

func _get_selected_item():
	var selected_item = null
	var selected_ship = null
	
	var left = _my_ship_list.Content
	var right = _other_ship_list.Content
	
	for item in left:
		if item.selected == true:
			selected_item = item
			selected_ship = _lobj
			break
	
	if selected_item == null:
		for item in right:
			if item.selected == true and "src" in item and item.src != "":
				selected_item = item
				selected_ship = _robj
				break
	
	if selected_item == null:
		return [null, null]
	else:
		return [selected_item, selected_ship]
