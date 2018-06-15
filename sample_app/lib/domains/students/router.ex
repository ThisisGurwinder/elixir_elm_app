defmodule Domains.Students.Router do
	use Commanded.Commands.Router
	alias Domains.Students.Aggregates.Students
	alias Domains.Students.Commands.{
		AddStudent
	}

	alias Domains.Aggregates.{Student}
	alias Common.Support.Middleware.Validate

	dispatch(
		[AddStudent],
		to: Students,
		identity: :students_uuid
	)
end
