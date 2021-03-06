tool
extends Control

export(bool) var editor_trigger_signal = true setget set_signal

export(bool) var dialog_ok = false setget set_dialog_ok
export(bool) var dialog_cancel = false setget set_dialog_cancel
export(String) var title = "" setget set_title
export(String) var bottom_title = "" setget set_bottom_title
export(String) var content = "" setget set_content
export(String, "═", "─", "━", " ") var border_style = "=" setget set_style

signal OnOkPressed()
signal OnCancelPressed()

var _base = null
var _dirty := false

func set_signal(newval):
	editor_trigger_signal = false
	if Engine.is_editor_hint():
		init()
		if _base:
			_base.init()

func set_dialog_ok(val):
	dialog_ok = val
	if _base:
		_base.dialog_ok = dialog_ok
		
func set_dialog_cancel(val):
	dialog_cancel = val
	if _base:
		_base.dialog_cancel = dialog_cancel
		
func set_bottom_title(val):
	if bottom_title == val:
		return
	bottom_title = val
	if _base:
		_base.bottom_title = bottom_title
		
func set_title(val, translate=true):
	if title == val:
		return
	title = val
	if _base:
		_base.set_title(title, translate)
	
func set_content(val):
	content = val
	if _base:
		get_node("base/Content").bbcode_text = val
	
func set_style(val):
	border_style = val
	if _base:
		_base.border_style = border_style

func init():
	if not has_node("base"):
		return
		
	_base = get_node("base")
	if _base.is_connected("OnUpdateLayout", self, "update"):
		_base.disconnect("OnUpdateLayout", self, "update")
	_base.connect("OnUpdateLayout", self, "update")
	_base.title = title
	_base.bottom_title = bottom_title
	_base.dialog_ok = dialog_ok
	_base.dialog_cancel = dialog_cancel
	_base.border_style = border_style
	

func _ready():
	init()
	
func update():
	if not _dirty:
		_dirty = true
		call_deferred("do_update")
	
func do_update():
	var content_node = get_node("base/Content")
	if _base.title.empty():
		content_node.margin_top = 13
	else:
		content_node.margin_top = 54
	content_node.bbcode_text = content
	_dirty = false

