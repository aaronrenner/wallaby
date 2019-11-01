ExUnit.configure(exclude: [:ex_unit, :pending])
ExUnit.start()

Application.ensure_all_started(:bypass)
