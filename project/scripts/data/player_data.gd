class_name PlayerData

static var current_money: int


static func add_money(p_amount: int):
	if p_amount <= 0:
		return
	current_money += p_amount
	Signals.money_changed.emit(current_money)


# Refuses rather than going negative, so callers can price a purchase by
# trying it: a failed spend leaves the purse untouched.
static func spend_money(p_amount: int) -> bool:
	if p_amount <= 0 or current_money < p_amount:
		return p_amount <= 0
	current_money -= p_amount
	Signals.money_changed.emit(current_money)
	return true
