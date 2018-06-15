defmodule Domains.Students.Commands.AddStudent do
	defstruct [
		:students_uuid
	]

	use Vex.Struct

	# validates(:students_uuid, uuid: true)
end
