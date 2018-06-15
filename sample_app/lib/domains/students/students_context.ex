defmodule Domains.Students.StudentsContext do

	import Ecto.Query, warn: false

	alias Domains.Students.Commands.{
		AddStudent
	}

	alias Domains.Students.Router
	alias Domains.Students
  alias SeedsHelper

	def add_student() do
		student = %AddStudent{
			:students_uuid => "6fa38edb-dcda-4eaf-bdcb-74d229c1692a"
		}

		student
			|> Router.dispatch(include_execution_result: true)
	end
end
