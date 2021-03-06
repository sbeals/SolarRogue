extends Node

export(String, "", "HUD", "WelcomeScreen", "ConverterV2") var debug_menu = "" setget set_debug_menu, get_debug_menu

export(NodePath) var animator = null
export(NodePath) var fx_viewport = "../../Camera-GUI/ViewportContainer/Viewport"
export(NodePath) var fx_viewport_container = "../../Camera-GUI/ViewportContainer"

var _gui_list := {}
var _stack := []
var _animator : AnimationPlayer = null

onready var _fx_viewport : Viewport = get_node(fx_viewport)
onready var _fx_viewport_container : ViewportContainer = get_node(fx_viewport_container)
var _animated_gui = null
var _is_animated_push := true

func set_debug_menu(newval):
	if OS.is_debug_build():
		return
	if not newval in _gui_list:
		return
	var gui_obj = _gui_list[newval]
	if not debug_menu.empty():
		var fx_root = _gui_list[debug_menu].GetVFXRoot()
		var old_parent = _fx_viewport.get_parent()
		old_parent.remove_child(_fx_viewport)
		fx_root.get_parent().remove_child(fx_root)
		old_parent.add_child(fx_root)
		_fx_viewport_container.add_child(_fx_viewport)
	
	if not newval.empty():
		var fx_root : Node = gui_obj.GetVFXRoot()
		var fx_parent : Node = fx_root.get_parent()
		fx_parent.remove_child(fx_root)
		if _fx_viewport.get_parent() != null:
			_fx_viewport.get_parent().remove_child(_fx_viewport)
		fx_parent.add_child(_fx_viewport)
		_fx_viewport.add_child(fx_root)
		
	debug_menu = newval
	
func get_debug_menu():
	return debug_menu

func _ready():
	if animator != null:
		_animator = get_node(animator)
	BehaviorEvents.connect("OnGUILoaded", self, "OnGUILoaded_Callback")
	BehaviorEvents.connect("OnPushGUI", self, "OnPushGUI_Callback")
	BehaviorEvents.connect("OnPopGUI", self, "OnPopGUI_Callback")
	BehaviorEvents.connect("OnPlayerCreated", self, "OnPlayerCreated_Callback")
	BehaviorEvents.connect("OnShowGUI", self, "OnShowGUI_Callback")
	BehaviorEvents.connect("OnHideGUI", self, "OnHideGUI_Callback")
	

func OnShowGUI_Callback(name, init_param, transition=""):
	_gui_list[name].visible = true
	_gui_list[name].Init(init_param)
	
	_start_transition(_gui_list[name], transition)
	
func OnHideGUI_Callback(name):
	if name in _gui_list:
		_gui_list[name].visible = false
		
func _input(event):
	if _animator != null and _animator.is_playing():
		# prevent player from spamming buttons while doing transitions
		get_tree().set_input_as_handled()

func OnPlayerCreated_Callback(player):
	BehaviorEvents.disconnect("OnPlayerCreated", self, "OnPlayerCreated_Callback")
	# push default UI (might be some main menu or splash screen one day)
	BehaviorEvents.call_deferred("emit_signal", "OnPushGUI", "HUD", null)
	var cur_save = get_node("../LocalSave").get_latest_save()
	if cur_save == null or cur_save.empty():
		var player_name = player.get_attrib("player_name")
		BehaviorEvents.call_deferred("emit_signal", "OnPushGUI", "WelcomeScreen", {"player_name":player_name}, "slow_popin")
	else: # Middle of the game, tuto can start now. Start of game we wait till welcome screen is gone
		Globals.TutorialRef.emit_signal("StartTuto")
	
	BehaviorEvents.call_deferred("emit_signal", "OnLevelReady")

func OnGUILoaded_Callback(name, obj):
	# prevent adding duplicate that we create temporary for vfx
	if name in _gui_list:
		return
		
	_gui_list[name] = obj
	obj.visible = false
	
func _start_transition(gui_obj, transition_name):
	if _animator != null and not _animator.is_playing() and (gui_obj.Transition != false or not transition_name.empty()):
		if transition_name.empty():
			transition_name = "popin"
		var fx_root : Node = gui_obj.GetVFXRoot()
		var fx_parent : Node = fx_root.get_parent()
		fx_parent.remove_child(fx_root)
		if _fx_viewport.get_parent() != null:
			_fx_viewport.get_parent().remove_child(_fx_viewport)
		fx_parent.add_child(_fx_viewport)
		_fx_viewport.add_child(fx_root)
		
		#print("play %s %s" % [transition_name, name])
		_animated_gui = gui_obj
		_is_animated_push = true
		_animator.play(transition_name)
		_animator.connect("animation_finished", self, "animation_finished_Callback", [gui_obj, true])
	
func _cancel_animation():
	if _animator != null and _animator.is_playing():
		_animator.stop()
		animation_finished_Callback("", _animated_gui, _is_animated_push)
	
func OnPushGUI_Callback(name, init_param, transition_name=""):
	#TODO: make sure Layout is not already in stack
	#print("Push " + name)
	_cancel_animation()
		
	_start_transition(_gui_list[name], transition_name)
		
	_update_shortcut(_gui_list[name])
	_gui_list[name].Init(init_param)
	if _stack.size() > 0:
		_gui_list[_stack[-1]].call_deferred("OnFocusLost")
	_stack.push_back(name)
	BehaviorEvents.emit_signal("OnGUIChanged", _stack[-1])
		
	#print("visible true " + name)
	_gui_list[name].visible = true
	
func OnPopGUI_Callback():
	#print("Pop " + _stack[-1])
	var gui_name = _stack[-1]
	_stack.pop_back()
	if _stack.size() > 0:
		BehaviorEvents.emit_signal("OnGUIChanged", _stack[-1])
		_gui_list[_stack[-1]].call_deferred("OnFocusGained")
	
	_cancel_animation()
	if _animator != null and not _animator.is_playing() and _gui_list[gui_name].Transition != false:
		var fx_root : Node = _gui_list[gui_name].GetVFXRoot()
		var fx_parent : Node = fx_root.get_parent()
		fx_parent.remove_child(fx_root)
		if _fx_viewport.get_parent() != null:
			_fx_viewport.get_parent().remove_child(_fx_viewport)
		fx_parent.add_child(_fx_viewport)
		_fx_viewport.add_child(fx_root)
		
		#print ("play popout " + gui_name)
		_animated_gui = _gui_list[gui_name]
		_is_animated_push = false
		_animator.play_backwards("popin")
		_animator.connect("animation_finished", self, "animation_finished_Callback", [_gui_list[gui_name], false])
	else:
		#print ("visible false " + gui_name)
		_gui_list[gui_name].visible = false
		
		
func _update_shortcut(node):
	for child in node.get_children():
		if child.has_method("RegisterShortcut"):
			child.RegisterShortcut()
		if child.get_child_count() > 0:
			_update_shortcut(child)

func animation_finished_Callback(anim_name, obj, vis):
	#print("animation finished " + obj.name)
	obj.visible = vis
	_fx_viewport_container.material.set_shader_param("alpha", 0.0);
	
	var fx_root = obj.GetVFXRoot()
	var old_parent = _fx_viewport.get_parent()
	old_parent.remove_child(_fx_viewport)
	fx_root.get_parent().remove_child(fx_root)
	old_parent.add_child(fx_root)
	_fx_viewport_container.add_child(_fx_viewport)

	_animator.disconnect("animation_finished", self, "animation_finished_Callback")
