defmodule Domains.Students.StudentsSupervisor do
	use Supervisor

	alias Domains.Students.Projectors.{Students}

	def start_link do
		Supervisor.start_link(__MODULE__, [], name: __MODULE__)
	end

	def init(_) do
		Supervisor.init(
			[
				Students
			],
			strategy: :one_for_one
		)
	end
end
