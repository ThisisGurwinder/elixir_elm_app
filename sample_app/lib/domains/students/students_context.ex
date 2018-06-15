defmodule Domains.Students.StudentsContext do

	import Ecto.Query, warn: false

	alias Domains.Students.Commands.{
		AddStudent
	}

	alias Domains.Students.Router
	alias Domains.Students
  alias SeedsHelper

	def add_student() do
		student = %Domains.Students.Students{
			:age => 19,
			:classification => "student",
			:name => "Tom",
			:subject => "CS"
		}
		|> Map.from_struct

		IO.inspect "GOT THE STUDENT MAP"
		IO.inspect student

		struct(AddStudent, student)
			|> Router.dispatch()
	end
end
