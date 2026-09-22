class_name GasPumpData
extends Resource
# The pump's tank and its two prices; the margin between them is the business.

@export var name: String = "Pump"
@export var tank_size: float = 2000.0  # liters the pump itself holds
@export var wholesale_price: int = 2  # per liter, paid to the truck
@export var pump_price: int = 5  # per liter, charged to customers
@export var flow_rate: float = 12.0  # liters per second at the nozzle

# Runtime state. Vehicle does the same with current_fuel and duplicates its
# data at _ready, so two pumps sharing a .tres never share a tank.
var current_stock: float
var selling: bool = true
