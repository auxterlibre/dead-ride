class_name MoneyInfoUI
extends Label
# The purse, under the clock. Every till credits and debits through
# PlayerData, so its one signal is the whole update path.


func _ready():
	Signals.money_changed.connect(update_total)
	update_total(PlayerData.current_money)


func update_total(p_total: int):
	text = "$%d" % p_total
