extends SceneTree

const Budget := preload("res://scripts/sim/budget_system.gd")
const Projects := preload("res://scripts/sim/public_project_system.gd")
const Debt := preload("res://scripts/sim/debt_system.gd")

var checks := 0
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _fixture(funding: String) -> Dictionary:
	var st := {
		"date_year": 2027, "date_month": 1, "gdp": 100.0, "government": true,
		"approval": 50.0, "credibility": 50.0, "treasury": 10000.0,
		"projects": [], "project_opex": {}, "project_history": [],
		"ministry_admin": {}, "services": {}, "region_support": [], "social_groups": {},
	}
	Budget.init_state(st)
	Debt.init_state(st)
	Projects.init_state(st)
	st["treasury"] = 10000.0
	var allocations: Dictionary = st.budget.approved_allocations
	for key in allocations.keys():
		allocations[key] = 0.0
	allocations["infraestrutura"] = 3.0
	st.budget.allocations = allocations.duplicate(true)
	st.budget.approved_allocations = allocations.duplicate(true)
	st.projects.append({
		"id": "P-%s" % funding, "key": "ferrovia", "label": "Projeto contábil",
		"category": "infraestrutura", "ministry": "infraestrutura", "service": "",
		"region": 0, "status": "obras", "stage_index": 3, "funding": funding,
		"capex": 120.0, "cost_total": 120.0, "cost_spent": 0.0,
		"months_total": 12, "months_left": 12.0, "months_paused": 0,
		"progress": 0.0, "op_cost": 0.0, "service_gain": 0.0, "jobs": 0,
		"beneficiaries": 0, "group": "", "risk": 0.0, "overrun": 0.0,
		"feasibility": 100.0, "proposed_month": 0, "started_month": 1,
		"completed_month": 0, "evaluated": false, "evaluation": {}, "history": [],
	})
	return st

func _run_case(funding: String) -> void:
	var st := _fixture(funding)
	var budget_result := Budget.monthly(st)
	var treasury_after_budget := float(st.treasury)
	var book_before := (st.debt_book as Array).size()
	var project_result := Projects.monthly(st)
	var payment := float(project_result.get("capital", 0.0))
	var treasury_after_project := float(st.treasury)
	var book_after := (st.debt_book as Array).size()
	var project_debt := float(st.get("project_debt", 0.0))
	var executed_infra := float(st.budget.executed.get("infraestrutura", 0.0))
	_check(payment > 0.0, "%s deveria gerar capital mensal" % funding)
	_check(executed_infra > 0.0 and float(budget_result.get("total", 0.0)) > 0.0, "%s deveria registrar execução orçamentária" % funding)
	if funding == "tesouro":
		_check(book_after == book_before, "tesouro não deveria emitir tranche")
		_check(absf(project_debt) < 0.001, "tesouro não deveria acumular project_debt")
		_check(absf(treasury_after_project - treasury_after_budget) < 0.001, "tesouro não deveria debitar capital duas vezes")
	else:
		_check(book_after == book_before + 1, "%s deveria criar uma tranche real" % funding)
		_check(absf(project_debt - payment) < 0.001, "%s deveria rastrear o capital financiado" % funding)
		_check(absf(treasury_after_project - treasury_after_budget - payment) < 0.001, "%s deveria creditar o caixa pelo financiamento" % funding)
		_check(str((st.debt_book as Array)[-1].get("source", "")) == "projeto:%s" % funding, "%s deveria identificar a origem da tranche" % funding)

func _initialize() -> void:
	_run_case("tesouro")
	_run_case("titulos")
	_run_case("externo")
	if failures.is_empty():
		print("PROJECT_ACCOUNTING_SMOKE_PASS checks=%d" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("PROJECT_ACCOUNTING_SMOKE_FAIL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
