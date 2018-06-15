defmodule Domains.Students.Events.StudentsAdded do
	@derive [Poison.Encoder]

	defstruct [
		:students_uuid
	]
end
