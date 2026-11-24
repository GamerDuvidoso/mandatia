extends SceneTree

const Election := preload("res://scripts/sim/election.gd")

var failures: Array[String] = []
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	var seats := Election.allocate_dhondt({"A": 44.0, "B": 36.0, "C": 20.0}, 11)
	var total := 0
	for value in seats.values():
		total += int(value)
	_check(total == 11, "D'Hondt deveria distribuir exatamente 11 cadeiras")
	_check(int(seats.get("A", 0)) >= int(seats.get("B", 0)), "A deveria não ter menos cadeiras que B")
	_check(int(seats.get("B", 0)) >= int(seats.get("C", 0)), "B deveria não ter menos cadeiras que C")
	_check(Election.majority_of(513) == 257, "maioria de 513 deveria ser 257")
	_check(Election.is_parliamentary({"head_of_government": {"name": "PM"}}), "chefe de governo deveria identificar parlamentarismo")
	_check(not Election.is_parliamentary({"head_of_government": null}), "ausência de chefe de governo deveria identificar presidencialismo")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var runoff := Election.presidential_2d({"A": 43.0, "B": 35.0, "C": 22.0}, {"A": Vector2(-0.7, -0.4), "B": Vector2(0.7, 0.5), "C": Vector2(0.0, 0.0)}, rng)
	_check(bool(runoff.get("second_round", false)), "nenhuma maioria inicial deveria abrir segundo turno")
	_check((runoff.get("round2", []) as Array).size() == 2, "segundo turno deveria conter dois finalistas")
	_check(str(runoff.get("winner", "")) in ["A", "B"], "vencedor deveria ser um dos finalistas")

	var direct_rng := RandomNumberGenerator.new()
	direct_rng.seed = 7
	var direct := Election.presidential_2d({"A": 60.0, "B": 25.0, "C": 15.0}, {"A": Vector2(-0.7, -0.4), "B": Vector2(0.7, 0.5), "C": Vector2(0.0, 0.0)}, direct_rng)
	_check(not bool(direct.get("second_round", true)), "maioria inicial deveria evitar segundo turno")
	_check(str(direct.get("winner", "")) == "A", "A deveria vencer com maioria inicial")

	if failures.is_empty():
		print("ELECTION_SMOKE_PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("ELECTION_SMOKE: " + failure)
		print("ELECTION_SMOKE_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
