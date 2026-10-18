import json, pathlib, subprocess, sys, tempfile

SCRIPT = pathlib.Path(__file__).resolve().parent / "check-locales.py"


def run(ref, other):
    d = pathlib.Path(tempfile.mkdtemp())
    for code, data in (("pt-BR", ref), ("en", other)):
        (d / code).mkdir()
        (d / code / "strings.json").write_text(json.dumps(data))
    return subprocess.run([sys.executable, str(SCRIPT), str(d)], capture_output=True, text=True)


def test_passes_when_keys_match():
    assert run({"a": {"b": "x %d"}}, {"a": {"b": "y %d"}}).returncode == 0


def test_fails_on_missing_key():
    r = run({"a": {"b": "x", "c": "z"}}, {"a": {"b": "y"}})
    assert r.returncode == 1 and "en: falta a.c" in r.stdout


def test_fails_on_placeholder_mismatch():
    r = run({"a": "x %d"}, {"a": "y"})
    assert r.returncode == 1 and "en: placeholders diferentes em a" in r.stdout


def test_fails_on_leftover_portuguese_marker():
    r = run({"a": "Questões"}, {"a": "Questões"})
    assert r.returncode == 1 and "en: igual ao pt-BR em a" in r.stdout


def test_identical_value_without_portuguese_marker_passes():
    assert run({"a": "TestBase 🎉 %d", "b": "2026"}, {"a": "TestBase 🎉 %d", "b": "2026"}).returncode == 0


def test_lists_may_differ_in_length():
    ref = {"reviews": [{"name": "Ana", "text": "Ótimo"}, {"name": "Bia", "text": "Bom"}], "names": ["A", "B", "C"]}
    other = {"reviews": [{"name": "Ann", "text": "Great"}], "names": ["X"]}
    r = run(ref, other)
    assert r.returncode == 0, r.stdout


def test_fails_on_missing_list():
    r = run({"a": "x", "names": ["A"]}, {"a": "y"})
    assert r.returncode == 1 and "en: falta names" in r.stdout


def test_fails_on_empty_list():
    r = run({"names": ["A"]}, {"names": []})
    assert r.returncode == 1 and "en: lista vazia em names" in r.stdout


def test_fails_when_list_is_not_a_list():
    r = run({"names": ["A"]}, {"names": "A"})
    assert r.returncode == 1 and "en: esperava lista em names" in r.stdout


def run_strict(ref, other, ref_ach, other_ach, code="en"):
    d = pathlib.Path(tempfile.mkdtemp())
    for c, data, ach in (("pt-BR", ref, ref_ach), (code, other, other_ach)):
        (d / c).mkdir()
        (d / c / "strings.json").write_text(json.dumps(data))
        if ach is not None:
            (d / c / "achievements.json").write_text(json.dumps(ach))
    return subprocess.run([sys.executable, str(SCRIPT), str(d)], capture_output=True, text=True)


ACH_PT = {"first-quiz": {"title": "Primeiros Passos", "detail": "Termine seu primeiro quiz"}}
ACH_EN = {"first-quiz": {"title": "First Steps", "detail": "Finish your first quiz"}}


def test_widget_text_identical_to_pt_fails_even_without_marker():
    r = run_strict({"widget": {"readiness": "Pronto"}}, {"widget": {"readiness": "Pronto"}}, ACH_PT, ACH_EN)
    assert r.returncode == 1 and "texto pt-BR em widget.readiness" in r.stdout


def test_achievement_left_in_portuguese_fails():
    r = run_strict({"a": "x"}, {"a": "y"}, ACH_PT, ACH_PT)
    assert r.returncode == 1 and "achievements.first-quiz.title" in r.stdout


def test_missing_achievements_file_fails():
    r = run_strict({"a": "x"}, {"a": "y"}, ACH_PT, None)
    assert r.returncode == 1 and "en: falta achievements.json" in r.stdout


def test_translated_widget_and_achievements_pass():
    r = run_strict({"widget": {"readiness": "Pronto"}}, {"widget": {"readiness": "Ready"}}, ACH_PT, ACH_EN)
    assert r.returncode == 0, r.stdout


def test_pack_mode_flags_portuguese_achievements_in_en_pack():
    d = pathlib.Path(tempfile.mkdtemp())
    for c, ach in (("pt-BR", ACH_PT), ("en", ACH_EN)):
        (d / c).mkdir()
        (d / c / "strings.json").write_text(json.dumps({"widget": {"readiness": "x"}}))
        (d / c / "achievements.json").write_text(json.dumps(ach))
    pack = d / "pack"
    pack.mkdir()
    (pack / "pack.json").write_text(json.dumps({"language": "en", "achievements": [
        {"id": "first-quiz", "title": "Primeiros Passos", "detail": "Termine seu primeiro quiz"}]}))
    (pack / "strings.json").write_text(json.dumps({"widget": {"readiness": "Ready"}}))
    r = subprocess.run([sys.executable, str(SCRIPT), "--pack", str(pack), str(d)], capture_output=True, text=True)
    assert r.returncode == 1 and "pack(en)" in r.stdout and "first-quiz.title" in r.stdout


def test_portuguese_signal_anywhere_in_strings_fails():
    r = run_strict({"a": {"b": "x"}}, {"a": {"b": "Close the quiz agora"}}, ACH_PT, ACH_EN)
    assert r.returncode == 1 and "português em strings.json:a.b" in r.stdout


def test_portuguese_signal_respects_minimal_allowlist():
    r = run_strict({"a": "x"}, {"a": "Continuar esta semana"}, ACH_PT, ACH_EN, code="es-MX")
    assert r.returncode == 0, r.stdout


def test_pack_mode_flags_portuguese_in_pack_text():
    d = pathlib.Path(tempfile.mkdtemp())
    for c, ach in (("pt-BR", ACH_PT), ("en", ACH_EN)):
        (d / c).mkdir()
        (d / c / "strings.json").write_text(json.dumps({"widget": {"readiness": "x"}}))
        (d / c / "achievements.json").write_text(json.dumps(ach))
    pack = d / "pack"
    pack.mkdir()
    (pack / "pack.json").write_text(json.dumps({"language": "en", "tagline": "Passe na prova", "achievements": []}))
    (pack / "strings.json").write_text(json.dumps({"widget": {"readiness": "Ready"}}))
    r = subprocess.run([sys.executable, str(SCRIPT), "--pack", str(pack), str(d)], capture_output=True, text=True)
    assert r.returncode == 1 and "pack.json:tagline" in r.stdout


def test_english_left_in_pt_br_achievements_fails():
    ach = {"first-quiz": {"title": "Primeiros Passos", "detail": "Complete 10 quizzes"}}
    r = run_strict({"a": "x"}, {"a": "y"}, ach, ACH_EN)
    assert r.returncode == 1 and "pt-BR: inglês em achievements.json:first-quiz.detail" in r.stdout


def test_pt_br_with_quiz_loanword_passes():
    r = run_strict({"a": "Termine seu primeiro quiz"}, {"a": "Finish your first quiz"}, ACH_PT, ACH_EN)
    assert r.returncode == 0, r.stdout


def test_pack_mode_flags_english_in_pt_pack():
    d = pathlib.Path(tempfile.mkdtemp())
    for c, ach in (("pt-BR", ACH_PT), ("en", ACH_EN)):
        (d / c).mkdir()
        (d / c / "strings.json").write_text(json.dumps({"widget": {"readiness": "x"}}))
        (d / c / "achievements.json").write_text(json.dumps(ach))
    pack = d / "pack"
    pack.mkdir()
    (pack / "pack.json").write_text(json.dumps({"language": "pt-BR", "achievements": [
        {"id": "first-quiz", "title": "Primeiros Passos", "detail": "Unlock your streak"}]}))
    (pack / "strings.json").write_text(json.dumps({"widget": {"readiness": "Pronto"}}))
    r = subprocess.run([sys.executable, str(SCRIPT), "--pack", str(pack), str(d)], capture_output=True, text=True)
    assert r.returncode == 1 and "inglês em pack.json" in r.stdout
