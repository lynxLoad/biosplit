class_name ActionContext
extends RefCounted

## Монотонный счётчик, инвалидирующий любые «протухшие» async-действия.
var id: int = 0


func begin() -> int:
	id += 1
	return id


func is_current(other_id: int) -> bool:
	return id == other_id
